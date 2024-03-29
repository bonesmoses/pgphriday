# Dirty Postgres RAG

This is just a silly experiment in creating a _very_ quick-and-dirty RAG app using Postgres and pgvector. Please don't use this anywhere if you value your time.

## Prerequisites

This demo depends on several python3 libraries. The best way to get all of them is to use `pip`:

```bash
pip3 install psycopg2 pgvector 
pip3 install langchain langchain-text-splitters 
pip3 install transformers sentence-transformers
pip3 install llama-cpp-python
```

> [!NOTE]
> If you want to make use of your GPU for much faster processing, the `llama-cpp-python` extension requires a different install method:
>   
> ```bash
> export CMAKE_ARGS=-DLLAMA_CUBLAS=on
> export FORCE_CMAKE=1
> pip install llama-cpp-python --force-reinstall --upgrade --no-cache-dir
> ```

The `pgvector` Postgres extension is also necessary. For this, use the Postgres [PGDG binary repository](https://www.postgresql.org/download/) and install the appropriate package for your platform. For example, a Debian variant would do something like this:

```bash
sudo apt install postgresql-16-pgvector
```

Or just use a service like [Tembo](https://tembo.io/) which will deploy a pgvector-enabled stack in a few minutes.

Finally, the LLM used for this demo is the [Dolphin-Mixtral-8X7B version 2.7 model by TheBloke](https://huggingface.co/TheBloke/dolphin-2.7-mixtral-8x7b-GGUF). Click the link to download it, or use a tool like [LM Studio](https://lmstudio.ai/). Then place the model or a symbolic link in the `models` folder. The following shell commands should also work for the medium-sized medium-lossiness quant.

```bash
wget https://huggingface.co/TheBloke/dolphin-2.7-mixtral-8x7b-GGUF/resolve/main/dolphin-2.7-mixtral-8x7b.Q4_K_M.gguf?download=true
mv dolphin-2.7-mixtral-8x7b.Q4_K_M.gguf models
```

Feel free to try another model, but note that you'll need to modify the prompt template in `question-rag.py` to embed the proper prompt section markers.

## Setup

Assuming you have a Postgres instance with `pgvector` installed, execute the script to install the necessary tables:

```bash
psql -f create_tables.sql -h db_host -U username dbname
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

Start by executing the `import.py` command to categorize and insert the corpus into your RAG-enabled database. This step may take a while depending on article length and capabilities of the target database instance.

Once the text is loaded, there isn't much else to it. Just execute the `question-rag.py` application with a quoted question to feed the LLM results based on your question and have it process the results further.

Like this:

```bash
python3 question-rag.py "Is it possible to use Postgres as middleware?"
```

Viola!
