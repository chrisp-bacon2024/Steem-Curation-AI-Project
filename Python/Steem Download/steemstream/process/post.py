# Module Documentation
"""
social.py

This module processes and extracts rich metadata from posts, comments, and post options on the Steem blockchain.
It structures unstructured blockchain data into typed records for database insertion, including reputation,
language, followers, spelling accuracy, tagging, and reward distribution.

Core responsibilities include:
- Parsing post bodies and calculating textual statistics (e.g., word count, sentence count, image count)
- Detecting the dominant language in each post and counting spelling errors by language
- Extracting tags from post metadata and category fields
- Collecting account statistics such as followers and reputation at post time
- Structuring comments and tracking their relational hierarchy
- Extracting beneficiary assignments from post options

Key Classes:
- `PostData`, `BodyData`, `LanguageData`, `TagData`: Typed dictionaries representing post metadata
- `CommentData`: Represents a hierarchical comment record
- `BeneficiaryData`: Represents a post's reward beneficiary assignment

Main Functions:
- `get_body_language_tag_data`: Gathers full post body stats, language detection results, and tags
- `handle_post`: Coordinates post parsing and metadata extraction
- `handle_comment`: Extracts structured metadata for a comment operation
- `handle_beneficiary`: Extracts beneficiary reward information from `comment_options` operations

This module is intended for use in a Steem data ingestion pipeline, where post/comment activity
is transformed into structured formats for database insertion.
"""

# Imports
from datetime import datetime, timezone # Standard Library
import json

from steem import Steem # Third-party packages

from typing import Dict, List, Tuple, TypedDict, Any # Type hints

from steemstream.account import convert_raw_reputation, get_account_followers, AccountChecker # Local application imports
from steemutils.markdown_analysis import analyze_body
from steemutils.language import process_html_by_language

# TypedDicts
class PostData(TypedDict):
    """
    Represents metadata for a post on the Steem blockchain.

    Fields:
        author (str):
            The username of the author who created the post.

        permlink (str):
            The permanent link (permlink) that uniquely identifies the post.

        created (datetime):
            The UTC timestamp representing when the post was created.

        category (str):
            The category or tag under which the post was published, often used for topic grouping or curation.
    """
    author: str
    permlink: str
    created: datetime
    category: str

class BodyData(TypedDict):
    """
    Represents metadata and textual analysis of a Steem post body.

    Fields:
        author (str):
            The username of the post author.
        permlink (str):
            The permanent link (permlink) of the post.
        created (datetime):
            The UTC timestamp of post creation.
        day (str):
            The day of the week the post was created (e.g., "Mon", "Tue").
        author_reputation (int):
            The reputation score of the author (converted to human-readable format).
        title (str):
            The title of the post.
        body (str):
            The raw markdown content of the post.
        word_count (int):
            The number of words in the post body.
        sentence_count (int):
            The number of sentences detected in the post.
        paragraph_count (int):
            The number of paragraphs in the post body.
        img_count (int):
            The number of embedded images in the post.
        followers (int):
            The number of followers the author had at the time of the post.
        """
    author: str
    permlink: str
    created: datetime
    day: str
    author_reputation: int
    title: str
    body: str
    word_count: int
    sentence_count: int
    paragraph_count: int
    img_count: int
    followers: int

class LanguageData(TypedDict):
    """
    Represents the results of language detection and spellchecking on a post's body.

    Fields:
        author (str):
            The username of the post author.
        permlink (str):
            The permlink of the post.
        created (datetime):
            The UTC timestamp of post creation.
        code (str):
            The ISO 639-1 language code detected (e.g., 'en', 'es').
        n_words (int):
            Number of words in the post body written in this language.
        n_sentences (int):
            Number of sentences identified in this language.
        n_paragraphs (int):
            Number of paragraphs written in this language.
        spelling_errors (int):
            Count of spelling errors detected in this language section.
    """
    author: str
    permlink: str
    created: datetime
    code: str
    n_words: int
    n_sentences: int
    n_paragraphs: int
    spelling_errors: int

class TagData(TypedDict):
    """
    Represents a tag assigned to a Steem post.

    Fields:
        author (str):
            The username of the post author.
        permlink (str):
            The permlink of the post.
        created (datetime):
            The UTC timestamp of post creation.
        tag (str):
            A single tag applied to the post, either from metadata or the category field.
    """
    author: str
    permlink: str
    created: datetime
    tag: str

class CommentData(TypedDict):
    """
    Represents metadata for a comment on the Steem blockchain.

    This structure captures the hierarchical relationship of a comment to its
    parent and root post, along with author reputation and timestamp data.

    Fields:
        commenter (str):
            The username of the account that authored the comment.

        permlink (str):
            The permanent link (permlink) of the comment.

        parent_author (str):
            The username of the author of the parent post or comment.

        parent_permlink (str):
            The permlink of the parent post or comment.

        root_author (str):
            The username of the author of the root (top-level) post in the thread.

        root_permlink (str):
            The permlink of the root (top-level) post in the thread.

        time (datetime):
            The UTC timestamp when the comment was created.

        commenter_reputation (int):
            The comment author's reputation, converted from raw format.
    """
    commenter: str
    permlink: str
    parent_author: str
    parent_permlink: str
    root_author: str
    root_permlink: str
    time: datetime
    commenter_reputation: int

class BeneficiaryData(TypedDict):
    """
    Represents a beneficiary assignment for a post on the Steem blockchain.

    A beneficiary is an account designated to receive a percentage of the post's rewards.

    Fields:
        author (str):
            The username of the author of the post assigning beneficiaries.

        permlink (str):
            The permanent link (permlink) of the post.

        beneficiary (str):
            The username of the beneficiary account.

        pct (int):
            The percentage of the post's rewards allocated to the beneficiary,
            expressed as an integer (e.g., 25 for 25%).
    """
    author: str
    permlink: str
    beneficiary: str
    pct: int

# Helper Function
def get_body_language_tag_data(s: Steem, author: str, permlink: str, date: datetime) -> Tuple[
    BodyData, List[LanguageData], List[TagData]]:
    """
    Extracts metadata, language analysis, and tags from a post body on the Steem blockchain.

    This function retrieves the post content, calculates writing statistics, detects languages, checks spelling errors,
    and extracts tags from the post's metadata.
    :param s: An instance of the Steem API client.
    :param author: The username of the author of the post.
    :param permlink: The permanent link to the post.
    :param date: The creation date of the post.
    :returns: A Tuple containing a dictionary of the body data, a list of language data, and a list of tag data

    Example:
        >>> s = Steem()
        >>> date = datetime.now(tz=timezone.utc)
        >>> body_data, languages, tags = get_body_language_tag_data(s, "alice", "my-first-post", date)
        >>> print(body_data['word_count'], languages[0]['code'], tags[0]['tag'])
    """
    content = s.get_content(author, permlink)
    title = content['title']
    body = content['body']
    day = date.strftime('%a')
    reputation = int(convert_raw_reputation(content['author_reputation']))
    followers = get_account_followers(author, datetime.strftime(date, '%Y-%m-%dT%H:%M:%S'))
    body_analysis_data = analyze_body(body)
    body_data = {'author': author, 'permlink': permlink, 'created': date, 'day': day, 'author_reputation': reputation,
                 'title': title, 'body': body, 'word_count': body_analysis_data['word_count'],
                 'sentence_count': body_analysis_data['sentence_count'],
                 'paragraph_count': body_analysis_data['paragraph_count'], 'img_count': body_analysis_data['img_count'],
                 'followers': followers}
    language_data = process_html_by_language(body)
    languages = []
    for lang in language_data.keys():
        n_words = language_data[lang]['words']
        n_sentences = len(language_data[lang]['sentences'])
        n_paragraphs = language_data[lang]['paragraphs']
        spelling_errors = language_data[lang]['errors']
        languages.append({'author': author, 'permlink': permlink, 'created': date, 'code': lang, 'n_words': n_words,
                          'n_sentences': n_sentences, 'n_paragraphs': n_paragraphs, 'spelling_errors': spelling_errors})
    try:
        metadata = content.get('json_metadata')
        tags_raw = json.loads(metadata) if metadata else {}
        ts = tags_raw.get('tags', [content['category']])
    except (json.JSONDecodeError, TypeError, KeyError):
        ts = [content['category']]
    tags = []
    for tag in ts:
        tag_data = {'author': author, 'permlink': permlink, 'created': date, 'tag': tag}
        tags.append(tag_data)
    return body_data, languages, tags

# Handler Functions
def handle_post(block:Dict[str, Any], date:datetime, s:Steem, checker:AccountChecker,
                posts:List[PostData], bodies:List[BodyData], languages:List[LanguageData], tags:List[TagData]) -> None:
    """
    Processes a top-level post block and extracts associated metadata, body details, languages, and tags.

    This function handles Steem blockchain operations where a user creates a new top-level post (not a comment).
    It performs the following steps:
        - Checks whether the post's author is already known or needs to be added to the pending account list.
        - Extracts and appends basic post metadata to `posts`.
        - Uses language and body analysis tools to generate:
            - Textual statistics (e.g., word count, paragraph count, image count)
            - Detected languages and spelling errors
            - Post tags from metadata or category
        - Appends the results to the `bodies`, `languages`, and `tags` lists for later insertion.
    :param block: A blockchain operation of type `comment` representing a top-level post (i.e., `parent_author` is empty).
    :param date: The UTC timestamp of the block in which the post was found.
    :param s: An instance of the Steem API client used to fetch full post content.
    :param checker: An instance of the Account Checker class for checking accounts
    :param posts:
    :param bodies:
    :param languages:
    :param tags:
    :return:
    """
    author = block['author']
    checker.check(author)
    permlink = block['permlink']
    category = block['parent_permlink']
    posts.append({'author': author, 'permlink':permlink, 'created':date, 'category':category})
    body_data, langs, tgs = get_body_language_tag_data(s, author, permlink, date)
    bodies.append(body_data)
    languages.extend(langs)
    tags.extend(tgs)

def handle_comment(block:Dict[str, Any], date:datetime, s:Steem, checker:AccountChecker,
                comments:List[CommentData]) -> None:
    """
    Processes a comment operation from the Steem blockchain and appends structured comment metadata.

    This function:
        - Ensures the commenter account is known (adds to pending list if not).
        - Retrieves the full comment content from the Steem API.
        - Extracts key relational and reputation metadata.
        - Appends a structured comment dictionary to the `comments` list.
    :param block: A blockchain operation of type `comment` representing a reply to a post or another comment.
    :param date: The UTC timestamp when the comment block was processed.
    :param s: An instance of the Steem API client used to fetch the full comment structure.
    :param checker: An instance of `AccountChecker` used to track and avoid duplicate account inserts.
    :param comments: A list to which the structured comment metadata will be appended.
    :return: None

    Example:
        >>> handle_comment(block, datetime.utcnow(), s, checker, comments)
    """
    commenter = block['author']
    checker.check(commenter)
    permlink = block['permlink']
    comment = s.get_content(commenter, permlink)
    parent_author = block['parent_author']
    parent_permlink = block['parent_permlink']
    root_author = comment['root_author']
    root_permlink = comment['root_permlink']
    reputation = int(convert_raw_reputation(comment['author_reputation']))
    comments.append({
        'commenter':commenter,
        'permlink':permlink,
        'parent_author':parent_author,
        'parent_permlink':parent_permlink,
        'root_author':root_author,
        'root_permlink':root_permlink,
        'time':date,
        'commenter_reputation':reputation
    })

def handle_beneficiary(block:Dict[str, Any], checker:AccountChecker,
                beneficiaries:List[BeneficiaryData]) -> None:
    """
    Extracts and appends beneficiary data from a `comment_options` block.

    This function parses the `extensions` field of a post's `comment_options` operation,
    identifies all designated beneficiaries, ensures their accounts are known via `AccountChecker`,
    and appends structured information to the `beneficiaries` list.
    :param block: A Steem blockchain operation of type `comment_options`, which may include beneficiary data
            in the `extensions` field.
    :param checker: An instance of `AccountChecker` used to track and avoid duplicate account inserts.
    :param beneficiaries: A list to which each parsed beneficiary record will be appended.
    :return: None

    Example:
        >>> handle_beneficiary(block, account_checker, beneficiaries)
    """
    ext = block['extensions']
    if ext:
        for ben in ext[0][1]['beneficiaries']:
            b_name = ben['account']
            checker.check(b_name)
            beneficiaries.append({
                'author':block['author'],
                'permlink':block['permlink'],
                'beneficiary':b_name,
                'pct': ben['weight'] // 100
            })