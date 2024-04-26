import yaml

__all__ = ['parse_hugo']

def parse_hugo(filename):
  """
  Parse Huge Markdown files to rip out header elements and return article body
  
  The blog is currently written using Hugo-formatted Markdown files. As such,
  we separate out the YAML frontmatter and parse all fields into a single-layer
  dictionary. We also add a 'content' entry that contains the actual article
  text. Newlines are preserved for the sake of chunking.

  :param filename: String path to Hugo file to parse

  :return: Dict with one field for each Hugo frontmatter heading, and a
    'content' entry for all non-frontmatter content.
  """
  in_header = False

  with open(filename) as blog_file:
    content = ''
    header = ''

    for line in blog_file.readlines():
      if line.strip() == '---':
        in_header = not in_header
        continue

      if in_header:
        header = header + line
      else:
        content = content + line

    headers = yaml.safe_load(header)

  return {'content': content, **headers}
