"""
Tools for vectorizing chunked text for use in RAG apps
"""

__all__ = ['Tokenizer']

class Tokenizer:
  """
  LLM tokenizer class for handling blog articles
  
  LLMs need tokens to be vectorized for proximity matching. This is best done
  after splitting text or prompts into reasonably understandable chunks. This
  class will initialize the standardized transformer and content splitter that
  will chunk on most reasonable content delimiters. It also includes ``` as
  this is meant for parsing Markdown, and code blocks can be rather large.

  Currently we use the sentence-transformers/all-MiniLM-L6-v2 transformer. For
  a list of known transformers:

  https://huggingface.co/sentence-transformers

  Note that this transformer produces 384-dimension vectors!
  """
  model = None
  splitter = None

  def __init__(self):

    from sentence_transformers import SentenceTransformer
    from langchain_text_splitters import RecursiveCharacterTextSplitter, CharacterTextSplitter

    # If this gets changed often, it may be turned into a parameter.
    self.model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')

    # The recursive text splitter can break on multiple delimiters. This is
    # ideal, as we want to split on all of them, plus ``` for code blocks.
    self.splitter = RecursiveCharacterTextSplitter(
        separators = ["\n\n", "\n", ' ', '.', '```'],
        chunk_size = 500,
        chunk_overlap = 20,
        length_function = len,
        is_separator_regex = False
    )

  def vectorize(self, content):
    """
    Transform provided text blob into N vectors

    Will split submitted text on various content delimiters to produce semantic
    chunks. Each chunk will then be separately vectorized for better context
    matching. Will return an array of all vectors for further processing.

    :param content: String of text to vectorize.

    :return: Array of numpy vectors, one vector for each content chunk.
    """
    chunks = self.splitter.split_text(content)
    embeddings = self.model.encode(chunks)
    return chunks, embeddings
