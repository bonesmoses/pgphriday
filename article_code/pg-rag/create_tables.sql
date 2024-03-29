CREATE TABLE blog_articles (
  article_id    INT PRIMARY KEY NOT NULL GENERATED ALWAYS AS IDENTITY,
  author        TEXT,
  title         TEXT,
  content       TEXT,
  publish_date  DATE
);

CREATE TABLE blog_article_embeddings (
  embedding_id  INT PRIMARY KEY NOT NULL GENERATED ALWAYS AS IDENTITY,
  article_id    INT NOT NULL REFERENCES blog_articles,
  chunk         TEXT,
  embedding     VECTOR(384)
);

CREATE INDEX idx_article_embedding
    ON blog_article_embeddings
 USING hnsw (embedding vector_l2_ops);
