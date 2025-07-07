import math
import requests
from steemutils.time import get_time, convert_time
from time import time
from steem import Steem
from typing import List, Dict, Any, TypedDict
from datetime import datetime, timezone
import pandas as pd

def convert_raw_reputation(raw_reputation:int | str ) -> float:
    """
    Converts a raw reputation score from the Steem blockchain into the
    human-readable format displayed on Steemit.
    :param raw_reputation: (int or str): The raw reputation value from the blockchain.
    :return: The formatted reputation score.
    """
    rep = str(raw_reputation)
    if rep == '0':
        return 25.0  # Default starting reputation
    neg = rep.startswith('-')
    rep = rep.lstrip('-')
    leading_digits = int(rep[0:4])
    log = math.log10(leading_digits)
    n = len(rep) - 1
    out = n + (log - int(log))
    if neg:
        out = -out
    out = max(out - 9, 0) * 9 + 25
    return round(out, 2)

class AccountData(TypedDict):
    username: str
    date_created: datetime

class AccountChecker:
    """
    Helper class to manage and deduplicate account lookups during blockchain streaming.
    """
    def __init__(self, steem:Steem, acc_list: List[AccountData], acc_in_db:pd.Series):
        """
        :param: steem: A Steem API client instance used to fetch account metadata.
        :param: acc_list: A list of accounts (dicts with 'username' and 'date_created') that need to be inserted into the database.
        :param: acc_in_db: A pandas Series of usernames that already exist in the database.
        """
        self.steem = steem
        self.acc_list = acc_list
        self.acc_in_db = acc_in_db
    def check(self, username:str) -> None:
        """
        Checks whether a Steem account is already known (in memory or in the database), and if not, fetches and appends it.

        This function ensures that each account encountered during block streaming is added to a list for batch insertion,
        but only if it's not already present in the in-memory list (`acc_list`) or the existing database (`acc_in_db`).

        If the account is not yet known, it uses the Steem API to retrieve the account's creation date and appends a
        dictionary with the username and date_created to `acc_list`.
        :param username: The username of the Steem account to check.
        :return: None
        """
        if username in self.acc_in_db.values or any(d['username'] == username for d in self.acc_list) or username == 'null':
            return
        account = self.steem.get_account(username)
        date_created = datetime.strptime(account['created'], '%Y-%m-%dT%H:%M:%S').replace(tzinfo=timezone.utc)
        self.acc_list.append({'username': username, 'date_created': date_created})
    def update(self, acc_list:List[AccountData], acc_in_db:pd.Series):
        """
        Update stored list and Series for account checks.
        :param acc_list: A list of accounts (dicts with 'username' and 'date_created') that need to be inserted into the database.
        :param acc_in_db: A pandas Series of usernames that already exist in the database.
        :return:
        """
        self.acc_list = acc_list
        self.acc_in_db = acc_in_db

def get_account_followers(account: str, date: str) -> int:
    """
    Estimates the number of followers an account had at a specific date.
    This function queries SteemWorld's API to:
    1. Get the current total follower count for a given account.
    2. Calculate the number of followers gained since the provided date.
    3. Subtract the newly added followers from the current total to estimate the historical follower count.
    :param account: Steem username (without the '@' symbol).
    :param date: A timestamp ('%Y-%m-%dT%H:%M:%S') string, representing the approximate time to retrieve
    follower data for.
    :return: Estimated follower count at the given date.

    Notes:
    -----
     - This method assumes that the list of followers returned by the SteemWorld API
      is ordered by follow time and that the `getFollowedHistory` API returns complete results.
    - It is an approximation and may be off if there is API truncation or delay.

    Example:
    -------
    >>> get_account_followers("ned", "2020-01-01T12:00:00")
    15000
    """
    current_followers = len(
        requests.get(f'https://sds.steemworld.org/followers_api/getFollowers/{account}').json()['result'])
    timestamp = get_time(convert_time(date))
    added_followers = len(requests.get(
        f'https://sds.steemworld.org/followers_api/getFollowedHistory/{account}/{timestamp}-{int(time())}').json()[
                              'result']['rows'])
    return current_followers - added_followers