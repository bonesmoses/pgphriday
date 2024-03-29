"""
Really cool Postgres-driven RAG CLI App!

Make sure to change the settings in config.py!
"""

import config
import sys

if len(sys.argv) < 2:
  print("""
    Hey now! You need to ask a question first! Example:
    
    {} "Is Postgres the best database engine?"
    """.format(sys.argv[0])
  )
  sys.exit(1)

question = sys.argv[1]

"""
This system works in two distinct phases.

Phase 1 is to check the information corpus for any matching documents for our
question. We can then use these references to guide the LLM toward answering
our question more precisely.

We've built a query that uses pgvector to match 10 article paragraphs, and
then we use the top 3 of those. This means all references could be from the
same article. This is necessary because large prompts appear to cause many
models to either crash or take a long time generating a response. Feel free to
juggle some of these for more exhaustive reference injection.
"""

import rag
import psycopg2
from pgvector.psycopg2 import register_vector

query = """
  WITH matches AS (
    SELECT embedding_id, article_id
      FROM blog_article_embeddings
     ORDER BY embedding <-> %s
     LIMIT 10),
  weighted_matches AS (
    SELECT embedding_id, article_id, 
           count(*) OVER (PARTITION BY article_id) AS score
      FROM matches
     ORDER BY score DESC
     LIMIT 3)
  SELECT a.title, emb.chunk
    FROM weighted_matches wm
    JOIN blog_article_embeddings emb USING (embedding_id, article_id)
    JOIN blog_articles a USING (article_id);
"""

token_parser = rag.Tokenizer()
question_vector = token_parser.vectorize(question)[1]

conn = psycopg2.connect(
  host = config.pg_host, 
  user = config.pg_user,
  password = config.pg_pass,
  database = config.pg_db
)
register_vector(conn)

print("Checking information corpus for answers...", flush=True)

references = ''

with conn.cursor() as cursor:
  refnum = 1
  cursor.execute(query, (question_vector))
  for (title, content) in cursor:
    print("Found reference in " + title, flush=True)
    references += "Reference {} from {}\n\n{}\n\n".format(refnum, title, content)
    refnum += 1

conn.close()

"""
Phase 2 is to launch the LLM and convey the reference material to the LLM as
part of the system prompt. Then we just have to wait as it generates the
response. In this case, we've chosen the (rather large) Dolphin-Mixtral-8X7B
as it is one of the better expert-level LLMs to demonstrate.

Note:
* Reduce n_gpu_layers for low-memory GPUs.
* We've reduced the temperature to 0.3 to prevent excessive hallucinations.
* Prompt section markers differ by model, so both must be modified to work.
"""

print("Loading LLM...", flush=True)

from langchain.callbacks.manager import CallbackManager
from langchain.callbacks.streaming_stdout import StreamingStdOutCallbackHandler
from langchain_community.llms import LlamaCpp

llm = LlamaCpp(
    model_path = config.model_file,
    temperature=0.3,
    n_gpu_layers=10,
    n_batch=512,
    n_ctx=2048,
    f16_kv=True,
    callback_manager=CallbackManager([StreamingStdOutCallbackHandler()]),
    verbose=False,
)

template="""<|im_start|>system
You are a PostgreSQL database platform expert tasked with answering difficult user questions. You should defer to the following references in all respects, but are otherwise welcome to fill in gaps with your existing knowledge: 

{refs}

Produce thorough and insightful answers whenever possible, and do not answer any questions unrelated to Postgres.
<|im_end|>

<|im_start|>user
{q}
<|im_end|>

<|im_start|>assistant
"""

rag_prompt = template.format(refs = references, q = question)

print("Sending your question and references to the LLM...", flush=True)
print("Response:\n\n", flush=True)

llm.invoke(rag_prompt)
