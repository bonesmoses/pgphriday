CREATE TABLE blog_articles (
  article_id    BIGINT PRIMARY KEY NOT NULL GENERATED ALWAYS AS IDENTITY,
  author        TEXT,
  title         TEXT,
  content       TEXT,
  publish_date  DATE,
  last_updated  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE blog_article_chunks (
  chunk_id      BIGINT PRIMARY KEY NOT NULL GENERATED ALWAYS AS IDENTITY,
  article_id    BIGINT NOT NULL REFERENCES blog_articles,
  chunk         TEXT,
  last_updated  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE EXTENSION vectorize CASCADE;
