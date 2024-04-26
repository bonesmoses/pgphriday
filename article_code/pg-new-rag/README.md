# Brand New RAG

This is a follow-up to [our earlier project](../rag-app/) to build a RAG app. This time, we're leveraging the power of `pg_vectorize`.

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

## Setup

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

## Usage

Start by executing the `import.py` command to categorize and insert the corpus into your RAG-enabled database.

Once the text is loaded, there isn't much else to it. Just execute the `question-rag.py` application with a quoted question to feed the LLM results based on your question and have it process the results further.

Like this:

```bash
python3 question-rag.py "Is it possible to use Postgres as middleware?"
```

Viola!
