# Brand New RAG

This is a follow-up to [our earlier project](../pg-rag/) to build a RAG app. This time, we're leveraging the power of `pg_vectorize`.

## Prerequisites

This demo depends on a couple of python3 libraries. The best way to get all of them is to use `pip`:

```bash
pip3 install langchain langchain-text-splitters 
```

Once that's done, install the following according to their instructions:

* [LM Studio](https://lmstudio.ai/) - To easily browse and download LLMs.
* [Ollama](https://ollama.com/) - To run the LLMs and provide a REST API.
* [Docker](https://www.docker.com/) - Quickly set up and tear down the database and related tools.
* [pg_vectorize](https://github.com/tembo-io/pg_vectorize) - To do literally everything else.

For the later, it's also possible to just use a service like [Tembo](https://tembo.io/) which will deploy a pg_vectorize-enabled stack in a few minutes.

## Ollama Bootstrap

Ollama specifically needs a bit of TLC. Even after installation, it's not quite ready for how we plan to use it. First, override the host it binds to through `systemctl`:

```bash
sudo systemctl edit ollama
```

Then paste these contents:

```init
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
```

Restart Ollama for good measure.

```bash
sudo systemctl restart ollama
```

Then create a file named `llama3.modalfile` with the following contents:

```
FROM models/Meta-Llama-3-8B-Instruct.Q8_0.gguf
TEMPLATE """{{ if .System }}<|start_header_id|>system<|end_header_id|>

{{ .System }}<|eot_id|>{{ end }}{{ if .Prompt }}<|start_header_id|>user<|end_header_id|>

{{ .Prompt }}<|eot_id|>{{ end }}<|start_header_id|>assistant<|end_header_id|>

{{ .Response }}<|eot_id|>"""
SYSTEM """You are a PostgreSQL expert who always answers user questions with concise answers about Postgres."""
PARAMETER stop <|start_header_id|>
PARAMETER stop <|end_header_id|>
PARAMETER stop <|eot_id|>
PARAMETER num_keep 24
```

This step assumes you've placed the `Meta-Llama-3-8B-Instruct.Q8_0.gguf` file in the `models` folder.

Then load the model into Ollama:

```bash
ollama create llama3 -f llama3.modalfile
```

## Docker Compose Setup

Go to the `docker` folder and run this:

```bash
docker compose create
docker compose start
```

When you're done with this demo or want to shut the services down:

```bash
docker compose stop
```

## Postgres Setup

Assuming you have a Postgres instance with `pg_vectorize` installed, execute the script to install the necessary tables:

```bash
psql -f create_schema.sql -h db_host -U username dbname
```

Then edit the `config.py` file to change the global settings used by the two provided utilities.

Place some Hugo Markdown files in the `./corpus` folder for processing. If you don't have any, download or generate a few. Any text file should work, so long as it has the following in the YAML header block:

```yaml
---
author: Some Person
date: 2024-03-29 16:00:49+00:00
title: This really cool article I wrote!
---
```

The loader isn't all that complicated, and should be fairly easy to modify to load other types of files.

## Initialization

Start by executing the `import.py` command to categorize and insert the corpus into your RAG-enabled database. Then get Postgres ready to use the external sentence transformer service and Ollama. If you followed the blog post, these would be the settings:

```sql
ALTER SYSTEM SET vectorize.embedding_service_url TO 'http://rag-vector-serve:3000/v1/embeddings';
ALTER SYSTEM set vectorize.ollama_service_url TO 'http://host.docker.internal:11434';
SELECT pg_reload_conf();
```

Then follow up by initializing the RAG system itself:

```sql
SELECT vectorize.init_rag(
    agent_name          => 'blog_chat',
    table_name          => 'blog_article_chunks',
    "column"            => 'chunk',
    unique_record_id    => 'chunk_id',
    transformer         => 'sentence-transformers/all-MiniLM-L12-v2',
    schedule            => 'realtime'
);
```

Once the background task finishes creating the embeddings, it should be possible to query the stack.

## Usage

Once everything is loaded, there isn't much else to it. Just execute the `question-rag.py` application with a quoted question to feed the LLM results based on your question and have it process the results further.

Like this:

```bash
python3 question-rag.py "Is it possible to use Postgres as middleware?"
```

Viola!
