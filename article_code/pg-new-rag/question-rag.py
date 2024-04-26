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
Unlike our previous RAG app, we only need to submit a query to Postgres. The
Postgres _is_ our RAG app, and this is a mere SQL client to provide a nice
interface.
"""

import psycopg2

query = """
SELECT vectorize.rag(                                                                
    agent_name  => 'blog_chat',        
    query       => %s,
    chat_model  => 'ollama/llama3'
) -> 'chat_response';
"""

conn = psycopg2.connect(
  host = config.pg_host, 
  user = config.pg_user,
  port = config.pg_port,
  password = config.pg_pass,
  database = config.pg_db
)

print("Sending your question and references to the LLM...", flush=True)

with conn.cursor() as cursor:
  cursor.execute(query, (question,))
  answer = cursor.fetchone()[0]

conn.close()

print("Response:\n\n", flush=True)
print(answer)
