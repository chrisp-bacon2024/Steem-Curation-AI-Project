"""
social.py

This module handles the extraction and structuring of social interaction data from the Steem blockchain.
It processes votes and resteems (reblogs), transforming raw blockchain operations into structured records
that are suitable for database insertion.

Core responsibilities:
- Track user voting behavior including weight and rshares contributed to posts
- Extract resteem (reblog) actions from custom JSON operations
- Measure follower counts for resteemers at the time of interaction
- Ensure all accounts involved are tracked for insertion using the AccountChecker

Key Classes:
- `VoteData`: Represents a structured vote record including voter identity, post reference, and vote impact
- `ResteemData`: Captures reblog (resteem) metadata including follower counts and post references

Main Functions:
- `handle_vote`: Processes a vote operation and appends the corresponding structured vote data
- `parse_resteem`: Interprets a custom JSON block to extract reblog (resteem) details, if applicable
- `handle_resteem`: Manages resteem tracking, invokes parsing logic, and appends structured data

This module is part of the Steem data ingestion pipeline, focused on capturing engagement signals
that reflect user influence, reach, and reward distribution dynamics.
"""


from typing import Dict, List, TypedDict, Any, Optional
from datetime import datetime
from steem import Steem
from steemstream.account import AccountChecker, get_account_followers
import json

# TypedDict Definitions
class VoteData(TypedDict):
    """
    Represents a vote cast on a post or comment in the Steem blockchain.

    This structure includes information about the vote target, the voter,
    and the associated vote weight and reward share metrics.

    Fields:
        author (str):
            The username of the author of the post or comment that was voted on.

        permlink (str):
            The permanent link (permlink) of the post or comment that received the vote.

        voter (str):
            The username of the account that cast the vote.

        time (datetime):
            The UTC timestamp when the vote occurred.

        weight (int):
            The vote's weight percentage, scaled from -100 to +100.

        rshares (int):
            The raw reward shares (rshares) assigned to the vote, used in Steem's payout system.
    """
    author: str
    permlink: str
    voter: str
    time: datetime
    weight: int
    rshares: int

class ResteemData(TypedDict):
    """
    Represents data extracted from a Steem 'reblog' (resteem) operation.

    Fields:
        author (str):
            The original author of the post being reblogged.
        permlink (str):
            The permanent link (permlink) of the original post.
        resteemed_by (str):
            The username of the account that performed the resteem.
        followers (int):
            The number of followers the reblogging account had at the time of the resteem.
    """
    author: str
    permlink: str
    resteemed_by: str
    followers: int

# Vote handling Function
def handle_vote(block:Dict[str, Any], date:datetime, s:Steem, checker:AccountChecker, votes:List[VoteData]) -> None:
    """
    Processes a `vote` operation from the Steem blockchain and appends structured vote data.

    This function:
        - Ensures the voter account is tracked.
        - Extracts vote weight and finds the corresponding rshares value from the post's active votes.
        - Appends a structured vote record to the `votes` list.
    :param block: A Steem blockchain operation of type `vote` containing keys like 'author', 'permlink', 'voter', and 'weight'.
    :param date: The UTC timestamp when the vote block was processed.
    :param s: An instance of the Steem API client used to fetch active vote data from the target post.
    :param checker: An instance of `AccountChecker` used to track and avoid duplicate account inserts.
    :param votes: A list to which the structured vote data will be appended.
    :return: None

    Example:
        >>> handle_vote(block, datetime.utcnow(), s, account_checker, votes)
    """
    author = block['author']
    permlink = block['permlink']
    voter = block['voter']
    checker.check(voter)
    weight = block['weight'] // 100

    rshares = next(
        (vote['rshares'] for vote in s.get_content(author, permlink)['active_votes'] if vote['voter'] == voter),
        0
    )

    votes.append({'author':author,
                  'permlink':permlink,
                  'voter':voter,
                  'time':date,
                  'weight':weight,
                  'rshares':rshares})

# Resteem Handling Functions
def parse_resteem(block:Dict[str, Any]) -> Optional[ResteemData]:
    """
    Parses a `custom_json` block to extract resteem (reblog) information.

    This function identifies resteems by checking if the block is of type `custom_json`
    with `id == 'follow'`, and if its JSON content starts with `'reblog'`. It then extracts
    the account and permlink of the reblogged post and computes the number of followers
    the reblogger had at that time.
    :param block: A blockchain operation block containing keys such as 'type', 'id', 'json', and 'timestamp'.
    :return: A dictionary with the reblog info or None. Returns `None` if the block is not a resteem event.

    Example:
        >>> result = parse_resteem(block)
        >>> if result:
        ...     print(result['reblogged_by'], result['followers'])
    """
    if block['type'] == 'custom_json' and block['id'] == 'follow':
        json_data = json.loads(block['json'])
        if isinstance(json_data, list) and json_data[0] == 'reblog':
            reblog_info = json_data[1]
            if 'account' in reblog_info.keys() and 'author' in reblog_info.keys() and 'permlink' in reblog_info.keys():
                followers = get_account_followers(reblog_info['account'],
                                                  datetime.strftime(block['timestamp'], '%Y-%m-%dT%H:%M:%S'))
                return {
                    'author': reblog_info['author'],
                    'permlink': reblog_info['permlink'],
                    'resteemed_by': reblog_info['account'],
                    'followers':followers
                }

def handle_resteem(block:Dict[str, Any], date:datetime, checker:AccountChecker, resteems:List[ResteemData]) -> None:
    """
    Processes a `custom_json` blockchain operation and appends resteem (reblog) data if applicable.

    This function checks whether the given block represents a `reblog` action (resteem) by using
    `parse_resteem()`. If valid, it ensures the resteemer's account is tracked, attaches a timestamp,
    and appends the structured resteem record to the provided list.
    :param block: A blockchain operation of type `custom_json` that may represent a resteem action.
    :param date: The UTC timestamp when the resteem block was processed.
    :param checker: An instance of `AccountChecker` used to track and avoid duplicate account inserts.
    :param resteems: A list to which the parsed resteem data will be appended, if applicable.
    :return: None

    Example:
        >>> handle_resteem(block, datetime.utcnow(), account_checker, resteems)
    """
    resteem_data = parse_resteem(block)
    if resteem_data:
        resteemer = resteem_data['resteemed_by']
        checker.check(resteemer)
        resteem_data['time'] = date
        resteems.append(resteem_data)