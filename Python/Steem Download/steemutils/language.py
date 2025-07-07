# Module Docstring
"""
language.py

This module provides utilities for language detection, sentence segmentation,
and spellchecking within text or HTML content. It is designed to support multilingual
text processing in contexts such as blockchain post analysis, content moderation,
or metadata extraction.

Core Capabilities:
- Detecting the most probable language of a text segment using `langdetect`
- Splitting paragraphs into individual sentences using punctuation rules
- Counting spelling errors using `pyenchant` dictionaries
- Parsing HTML content into language-specific sentence groups and assessing spelling accuracy

Key Functions:
- `detect_language`: Detects the dominant language of a text block.
- `split_sentences`: Splits raw text into sentences based on punctuation.
- `count_spelling_errors`: Counts total and incorrect words for a given language.
- `process_html_by_language`: Segments HTML content into paragraphs, detects languages,
   and aggregates spelling statistics by language.

This module is useful for natural language processing of posts on the Steem blockchain.
"""

# Imports
import re # Standard Library

import enchant # Third-party packages
from bs4 import BeautifulSoup
from langdetect import detect_langs

from typing import List, Dict, TypedDict # Type hints

# TypedDicts
class SpellcheckResult(TypedDict):
    words: int
    errors: int

class LanguageEntry(TypedDict):
    paragraphs: int
    sentences: List[str]
    words: int
    errors: int

# === Utility Functions ===
def detect_language(text:str, min_word_count:int=3) -> str | None:
    """
    Detects the most probable language of the given text using the langdetect library.
    :param text: The input text whose language is to be detected
    :param min_word_count:
    :return: Two-letter ISO language code if a language is detected with > 50% confidence, otherwise None.

    Examples
    --------
    >>> detect_language("Bonjour, comment allez-vous?")
    'fr'
    >>> detect_language("hijojjbkukg hbjbjh hnjnh")
    None
    """
    words = re.findall(r"\b\w+\b", text)
    if len(words) < min_word_count:
        return None # Too short to reliably detect

    try:
        results = detect_langs(text)
        if results[0].prob > 0.50:
            return results[0].lang
        else:
            return None
    except Exception:
        return None

def split_sentences(text:str) -> [str]:
    """
    Splits a block of text into individual sentences using basic punctuation.
    :param text: The full paragraph or text block.
    :return: List of sentences

     Examples
    --------
    >>> split_sentences("Hello world! How are you? I'm fine.")
    ['Hello world!', 'How are you?', "I'm fine."]
    """
    return re.split(r'(?<=[.?!।])\s+', text.strip())

# === Spellchecking ===
def count_spelling_errors(sentences:List[str], language_code:str) -> SpellcheckResult:
    """
    Counts total words and misspelled words in a list of sentences.
    :param sentences: List of sentences to check
    :param language_code: pyenchant language code (e.g., 'en_US', 'fr_FR').
    :return: A dictionary with the total words and number of mispelled words
    {
        'words': total word count,
        'errors': number of misspelled words
    }
    """
    dictionary = True
    if not enchant.dict_exists(language_code):
        dictionary = False

    if dictionary:
        d = enchant.Dict(language_code)
    total_words = 0
    error_count = 0

    for sentence in sentences:
        # Tokenize based on whitespace
        words = sentence.strip().split()
        # Clean basic punctuation
        words = [w.strip(".,!?\"“”‘’():;[]{}") for w in words if w]
        total_words += len(words)
        if dictionary:
            error_count += sum(1 for word in words if word and not d.check(word))
        else:
            error_count = -1

    return {'words': total_words, 'errors': error_count}

# === Main Entry Point ===
def process_html_by_language(html:str) -> Dict[str, LanguageEntry]:
    """
    Processes an HTML document, detects dominant language per paragraph,
    and evaluates spelling errors in each group of language-identified sentences.
    :param html: HTML content as a string
    :return: A dictionary where keys are language codes (e.g., 'en_US') and values
             are dictionaries containing paragraph count, list of sentences,
             total word count, and spelling error count.

    Example
    -------
    >>> html = "<p>Hello world. This is English.</p>\n<p>Bonjour tout le monde.</p>"
    >>> process_html_by_language(html)
    {
        'en_US': {
            'paragraphs': 1,
            'sentences': ['Hello world.', 'This is English.'],
            'words': 5,
            'errors': 0
        },
        'fr_FR': {
            'paragraphs': 1,
            'sentences': ['Bonjour tout le monde.'],
            'words': 4,
            'errors': 0
        }
    }
    """
    soup = BeautifulSoup(html, 'html.parser')

    # Extract full text content
    full_text = soup.get_text(separator="\n").strip()

    # Split paragraphs by two or more line breaks
    raw_paragraphs = re.split(r'\n\s*\n', full_text)
    data = {}

    for paragraph_text in raw_paragraphs:
        if not paragraph_text.strip():
            continue

        sentences = split_sentences(paragraph_text)
        lang_counts = {}
        sentence_langs = []

        for sentence in sentences:
            lang_code = detect_language(sentence)
            if lang_code:
                lang_counts[lang_code] = lang_counts.get(lang_code, 0) + 1
                sentence_langs.append((sentence, lang_code))

        if not lang_counts:
            continue  # Skip if no valid language found

        # Pick dominant language in paragraph
        dominant_lang = max(lang_counts.items(), key=lambda x: x[1])[0]

        if dominant_lang not in data:
            data[dominant_lang] = {'paragraphs': 0, 'sentences': []}

        data[dominant_lang]['paragraphs'] += 1
        for sentence, lang in sentence_langs:
            if lang == dominant_lang:
                data[dominant_lang]['sentences'].append(sentence)

    # Spellcheck each language group
    for lang_code, entry in data.items():
        counts = count_spelling_errors(entry['sentences'], lang_code)
        entry.update(counts)

    return data