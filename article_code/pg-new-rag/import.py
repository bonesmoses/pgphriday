"""
Simple utility to import a bunch of Hugo Markdown files into our RAG app

Script expects both the blog_articles and blog_article_embeddings tables as
described in the README. Hugo Markdown files should be located in a corpus
directory colocated with the script.

Make sure to change the settings in config.py!
"""

import rag
import config
import psycopg2

from glob import glob

import_path = './corpus'

conn = psycopg2.connect(
  host = config.pg_host,
  port = config.pg_port, 
  user = config.pg_user,
  password = config.pg_pass,
  database = config.pg_db
)

cursor = conn.cursor()
chunker = rag.Splitter()

"""
The bulk of the work being done here is simply to pull all of the Hugo front-
matter fields and content out of each Markdown file. Then we can proceed to
insert relevant fields into the article table and embedding table.
"""

for blog in glob(import_path + '/*.md'):
  article = rag.parse_hugo(blog)
  print("Importing " + article['title'], flush=True)

  cursor.execute(
    """INSERT INTO blog_articles (author, title, content, publish_date)
       VALUES (%s, %s, %s, %s) RETURNING article_id""",
    (article['author'], article['title'], article['content'], article['date'])
  )

  article_id = cursor.fetchone()[0]

  # We can split the content into numerous context-relevant chunks and insert
  # each chunk as a separate embedding. This should improve our results by
  # injecting specificity to each vector that would be missing in the whole
  # article.

  chunks = chunker.chunk_content(article['content'])

  for i in range(len(chunks)):
    cursor.execute(
      """INSERT INTO blog_article_chunks (article_id, chunk)
         VALUES (%s, %s)""",
      (article_id, chunks[i])
    )

  conn.commit()
