# Module Docstring
"""
markdown_analysis.py

This module provides functionality to extract basic textual and structural
statistics from markdown-formatted text. It is designed to support preprocessing
of user-generated content such as blog posts or social media articles, especially
for language and content analysis pipelines.

Core Features:
- Converts markdown to HTML to access visual structure and embedded media.
- Extracts plain text and structural elements using BeautifulSoup.
- Counts:
    - Words using NLTK tokenization
    - Sentences using NLTK's sentence tokenizer
    - Paragraphs based on double newlines
    - Images via both markdown syntax and HTML <img> tags

Main Function:
- `analyze_body`: Accepts markdown text and returns a dictionary containing
  word count, sentence count, paragraph count, and image count.

This module is useful for text analytics workflows, such as processing Steem
blockchain post bodies or other markdown-based content sources.
"""

# === Imports ===
import re # Standard Library
import warnings

import markdown # Third-party packages
from bs4 import BeautifulSoup
from bs4 import MarkupResemblesLocatorWarning
from nltk.tokenize import sent_tokenize, word_tokenize

from typing import TypedDict # Type hints

# === Configure Warnings ===
warnings.filterwarnings("ignore", category=MarkupResemblesLocatorWarning)

# === TypedDict ===
class BodyData(TypedDict):
    """
    Represents basic structural and linguistic statistics extracted from
    a markdown-formatted text body.

    This structure is typically returned by the `analyze_body` function,
    and is designed to support downstream processing for content analytics,
    including language modeling, readability scoring, and engagement metrics.

    Fields:
        word_count (int):
            The total number of words detected in the visible text content.
            Words are tokenized using NLTK's `word_tokenize`.

        sentence_count (int):
            The total number of sentences in the content, identified using
            NLTK's `sent_tokenize`.

        paragraph_count (int):
            The number of paragraphs, based on groups of text separated
            by two or more newline characters.

        img_count (int):
            The number of images in the body, detected via both markdown
            syntax (`![alt](url)`) and HTML `<img>` tags after markdown
            conversion.
        """
    word_count:int
    sentence_count:int
    paragraph_count:int
    img_count:int

# === Body Function ===
def analyze_body(text:str) -> BodyData:
    """
    Analyzes a markdown-formatted text body and returns basic textual statistics.

    This function:
        1. Converts the input markdown to HTML.
        2. Counts the number of images using both markdown syntax and HTML img tags.
        3. Extracts visible text content and calculates:
            - Word count
            - Sentence count
            - Paragraph count (split on two or more newlines)
    :param text: The body text of a post in markdown format.
    :return: A dictionary containing word count, sentence count, paragraph count, and image count

    Example:
        >>> analyze_body("Hello world!\\n\\nThis is a test.\\n\\n![img](url)")
        (6, 2, 2, 1)
    """
    # Step 1: Convert Markdown to HTML
    html = markdown.markdown(text)

    # Step 2: Count images
    markdown_img_count = len(re.findall(r'!\[.*?\]\(.*?\)', text))
    soup = BeautifulSoup(html, 'html.parser')
    html_img_count = len(soup.find_all('img'))
    img_count = markdown_img_count + html_img_count

    # Step 3: Extract visible text
    plain_text = soup.get_text(separator='\n').strip()

    # Step 4: Paragraphs
    # Normalize line breaks and split on two or more newlines
    raw_paragraphs = re.split(r'\n\s*\n', plain_text)
    paragraph_count = sum(1 for p in raw_paragraphs if p.strip())

    # Step 5: Sentences (using NLTK sentence tokenizer)
    sentence_count = len(sent_tokenize(plain_text))

    # Step 6: Words
    word_count = len(word_tokenize(plain_text))

    return {'word_count':word_count, 'sentence_count':sentence_count, 'paragraph_count':paragraph_count, 'img_count':img_count}