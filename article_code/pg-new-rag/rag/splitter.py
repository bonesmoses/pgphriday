"""
Tools for producing chunked text for more focused use in RAG apps
"""

__all__ = ['Splitter']

class Splitter:
  """
  Text-splitting class for handling blog articles

  LLMs need tokens to be vectorized for proximity matching. This is best done
  after splitting text or prompts into reasonably understandable chunks. This
  class will initialize a content splitter that will chunk on most reasonable
  content delimiters. It also includes ``` as this is meant for parsing
  Markdown, and code blocks can be rather large.
  """
  splitter = None

  def __init__(self):

    from langchain_text_splitters import RecursiveCharacterTextSplitter

    # The recursive text splitter can break on multiple delimiters. This is
    # ideal, as we want to split on all of them, plus ``` for code blocks.
    self.splitter = RecursiveCharacterTextSplitter(
        separators = ["\n\n", "\n", ' ', '.', '```'],
        chunk_size = 500,
        chunk_overlap = 20,
        length_function = len,
        is_separator_regex = False
    )

  def chunk_content(self, content):
    """
    Transform provided text blob into N chunks

    Will split submitted text on various content delimiters to produce semantic
    chunks. Will return an array of all chunks for further processing.

    :param content: String of text to split into chunk.

    :return: Array of content chunks.
    """
    chunks = self.splitter.split_text(content)
    return chunks
