"""
reward.py

This module handles the extraction and organization of blockchain reward operations
from the Steem blockchain. It transforms raw reward-related blocks into structured,
typed dictionaries for database insertion.

Core responsibilities:
- Parsing and recording author rewards for original content
- Aggregating curation rewards across multiple curators per post
- Tracking beneficiary rewards distributed to third-party accounts
- Calculating total post payout value (used for post valuation analytics once a post is known to have paid out)
- Ensuring all involved accounts are checked and tracked via `AccountChecker`

Key Classes and TypedDicts:
- `AuthorRewardData`: Represents a single author reward record
- `CurationRewardData` / `CurationRewardsData`: Represents curator rewards for a post
- `CurationRewards`: A class for accumulating and structuring curation rewards over time
- `PostValueData`: Captures the total monetary value received by a post
- `BeneficiaryRewardData`: Records third-party beneficiary rewards assigned to a post

Main Functions:
- `handle_author_reward`: Extracts and stores author reward data
- `handle_curation_reward`: Tracks multi-voter curation rewards and post payout values
- `handle_beneficiary_reward`: Extracts beneficiary reward info from comment benefactor events

This module is typically used in a Steem data ingestion pipeline or analytics platform
to track how rewards are distributed among authors, curators, and beneficiaries.
It integrates with the `AccountChecker` utility to ensure all users involved in reward
transactions are properly logged and monitored for insertion.
"""

# Imports
from typing import Dict, List, TypedDict, Any
from datetime import datetime, timezone
from steem import Steem
from steemstream.account import AccountChecker

# Typed Dictionaries
class AuthorRewardData(TypedDict):
    """
        Represents a record of an author reward from the Steem blockchain.

        Fields:
            author (str):
                The username of the post author .

            permlink (str):
                The permanent link (permlink) of the post.

            reward_time (datetime):
                The UTC timestamp when the author reward was distributed.

            vests (int):
                The number of vesting shares awarded to the author.
        """
    author: str
    permlink: str
    reward_time: datetime
    vests: int

class CurationRewardData(TypedDict):
    curator: str
    vests: int

class CurationRewardsData(TypedDict):
    """
    Represents a record of a curation reward from the Steem blockchain.

    Fields:
        author (str):
            The username of the post author whose content was curated.

        permlink (str):
            The permanent link (permlink) of the post that was curated.

        curator (str):
            The username of the account that cast the vote and received the curation reward.

        reward_time (datetime):
            The UTC timestamp when the curation reward was distributed.

        vests (int):
            The number of vesting shares awarded to the curator.
    """
    author: str
    permlink: str
    reward_time: datetime
    rewards: CurationRewardData

class PostValueData(TypedDict):
    """
    Represents a record of the total value of a post which is retrieved when the post pays out.

    Fields:
        author (str):
            The username of the post author
        permlink (str):
            The permanent link (permlink) of the post
        total_value (float):
            The total value that the post received at payout (in USD)
    """
    author: str
    permlink: str
    total_value: float

class BeneficiaryRewardData(TypedDict):
    """
        Represents a beneficiary reward from the Steem Blockchain.
        Fields:
            beneficiary (str):
                The username of the account that received the beneficiary reward
            vests (int):
                The number of vesting shares awarded to the beneficiary.
    """
    beneficiary:str
    vests:int

class BeneficiaryRewardsData(TypedDict):
    """
        Represents a record of a beneficiary reward from the Steem blockchain.
        Fields:
            author (str):
                The username of the post author whose content was curated.

            permlink (str):
                The permanent link (permlink) of the post that was curated.
            reward_time (datetime):
                The UTC timestamp when the curation reward was distributed.
            rewards (BeneficiaryRewardData):
                The collection of rewards.
        """
    author: str
    permlink: str
    reward_time: datetime
    rewards:BeneficiaryRewardData

# Handler Functions and Helper Classes
def handle_author_reward(block:Dict[str, Any], date:datetime, checker:AccountChecker, author_rewards:List[AuthorRewardData]) -> None:
    """
    Processes an `author_reward` block and extracts relevant reward data.

    This function extracts information about a post author receiving a reward,
    including the author's name, permlink of the post, reward time, and the amount
    of vesting tokens earned.
    :param block: A Steem blockchain operation of type `author_reward`. It must include
            the keys `'author'`, `'permlink'`, and `'vesting_payout'`.
    :param date: The UTC timestamp when the reward was recorded on the blockchain.
    :param checker: An instance of the Account Checker class for checking accounts
    :param author_rewards: A list to which parsed author reward entries will be appended.
    :return: None

    Example:
        >>> handle_author_reward(block, date, s, [], acc_in_db, [])
        None
    """
    author = block['author']
    checker.check(author)
    permlink = block['permlink']
    vests = int(float(block['vesting_payout'].replace(' VESTS', '')))
    author_rewards.append({'author': author, 'permlink':permlink, 'reward_time':date, 'vests':vests})

class CurationRewards():
    """
    Tracks and accumulates curation rewards for a specific post on the Steem blockchain.

    This class is used to collect individual curation reward entries related to a particular post
    (identified by author and permlink) and determine when to finalize the collection of those rewards.
    """
    def __init__(self, author, permlink, reward_time):
        """
        Initializes a new CurationRewards instance.

        :param author: The author of the post receiving curation rewards.
        :param permlink: The permanent link (permlink) of the post.
        :param reward_time: The UTC timestamp when the first reward for this post was seen.

        Example:
        >>> crs = CurationRewards('cmp2020', 'my-first-post', datetime.now())
        """
        self.author = author
        self.permlink = permlink
        self.reward_time = reward_time
        self.rewards = []
    def add_reward(self, block:Dict[str, Any], checker:AccountChecker) -> None:
        """
        Adds a curation reward entry to the list of rewards for this post.

        :param block: The blockchain operation containing keys 'curator' and 'reward'.
        :param checker: An instance of AccountChecker used to ensure the curator's account is recorded.

        Example:
        >>> crs.add_reward({'curator':cmp2020, 'reward':'2000 VESTS'}, checker)
        """
        curator = block['curator']
        checker.check(curator)
        vests = int(float(block['reward'].replace(' VESTS', '')))
        self.rewards.append({'curator':curator, 'vests':vests})
    def check_new_post(self, n_author:str, n_permlink:str) -> None:
        """
        Checks whether the given author and permlink match this instance's tracked post.
        If not, returns a dictionary with the collected reward data.

        :param n_author: The author name to compare.
        :param n_permlink: The permlink to compare.
        :return: Boolean representing whether the post is new or the same

        Example:
        >>> example_date = datetime.now()
        >>> crs = CurationRewards('cmp2020', 'my-first-post', example_date)
        >>> crs.check(n_author='remlaps', n_permlink='my_second_post')
        False

        """
        if n_author == self.author and n_permlink == self.permlink:
            return False
        else:
            return True
    def get_data(self) -> CurationRewardsData:
        """
        Returns the data for a post's curation rewards.
        {'author':'cmp2020', 'permlink':'my-first-post'
        :return: Dictionary of data for all of the post's curation rewards.

        >>>crs = CurationRewards('cmp2020', 'my-first-post', datetime.now())
        >>>crs.add_reward({'curator':'cmp2020', 'reward':'2000 VESTS'})
        >>>crs.get_data()
        {
            'author':'cmp2020',
            'permlink':'my-first-post',
            'reward_time':datetime.datetime(2024, 4, 28, 0, 0, 3, tzinfo=datetime.timezone.utc),
            'rewards': [
                {'curator':'cmp2020', 'vests':2000}
            ]
        }
        """
        return {
                'author': self.author,
                'permlink': self.permlink,
                'reward_time': self.reward_time,
                'rewards': self.rewards
            }

def handle_curation_reward(block:Dict[str, Any], date:datetime, s:Steem, checker:AccountChecker, crs:CurationRewards, post_values:List[PostValueData],
                           curation_rewards:List[CurationRewardData]) -> CurationRewards:
    """
    Processes a `curation_reward` block, extracting reward data and (if needed) post value,
    while ensuring involved accounts are tracked.

    This function checks whether the post corresponding to the curation reward is new.
    If it is, the function fetches the post's total payout value and appends it to `post_values`.
    It also adds a record to the `curation_rewards` list and ensures that both the author
    and the curator are checked for account inclusion.

    :param block: A blockchain operation of type `curation_reward` containing keys such as
            'comment_author', 'comment_permlink', 'curator', and 'reward'.
    :param date: The UTC timestamp of when the reward was processed.
    :param s: An instance of the Steem API client used for fetching post content.
    :param checker: An instance of the Account Checker class for checking accounts
    :param crs: The class for storing curation rewards data
    :param post_values: A list to which new post payout value data will be appended.
    :param curation_rewards: A list to which parsed curation reward entries will be appended.
    :return: The current post identifier ('author/permlink'), which can be used to update `prev_post`.

     Example:
        >>> crs = handle_curation_reward(block, datetime.now(), s, acc_list, acc_in_db, crs, post_values, curation_rewards)
    """
    author = block['comment_author']
    checker.check(author)
    permlink = block['comment_permlink']

    if crs.check_new_post(author, permlink):
        crs_data = crs.get_data()
        if crs_data['author'] != None:
            curation_rewards.append(crs_data)
            content = s.get_content(author, permlink)
            total_value = round(float(content['curator_payout_value'].replace(' SBD', '')), 2) * 2
            post_values.append({'author': author, 'permlink': permlink, 'total_value': total_value})
        crs = CurationRewards(author, permlink, date)

    crs.add_reward(block, checker)
    return crs

class BeneficiaryRewards():
    """
    Tracks and accumulates beneficiary rewards for a specific post on the Steem blockchain.

    This class is used to collect individual beneficiary reward entries related to a particular post
    (identified by author and permlink) and determine when to finalize the collection of those rewards.
    """
    def __init__(self, author:str, permlink:str, reward_time:datetime) -> None:
        """
        Initializes a new BeneficiaryRewards instance.

        :param author: The author of the post assigning beneficiary rewards.
        :param permlink: The permanent link (permlink) of the post.
        :param reward_time: The UTC timestamp when the rewards paid out.

        Example:
        >>> brs = BeneficiaryRewards('future.witness', 'daily-report', datetime.now())
        """
        self.author = author
        self.permlink = permlink
        self.reward_time = reward_time
        self.rewards = []
    def add_reward(self, block:Dict[str, Any], checker:AccountChecker) -> None:
        """
        Adds a beneficiary reward entry to the list of rewards for this post.

        :param block: The blockchain operation containing keys 'benefactor' and 'vesting_payout'.
        :param checker: An instance of AccountChecker used to ensure the beneficiary account is recorded.

        Example:
        >>> brs.add_reward({'benefactor': 'steem.dao', 'vesting_payout': '2000 VESTS'}, checker)
        """
        beneficiary = block['benefactor']
        checker.check(beneficiary)
        data = {
            'beneficiary':beneficiary,
            'vests': int(float(block['vesting_payout'].replace(' VESTS', '')))
        }
        self.rewards.append(data)
    def check_new_post(self, author:str, permlink:str) -> bool:
        """
        Checks whether the given author and permlink match this instance's tracked post.

        :param author: The author name to compare.
        :param permlink: The permlink to compare.
        :return: True if this is a new post (not matching the currently tracked post); False otherwise.

        Example:
        >>> brs = BeneficiaryRewards('alice', 'post-1', datetime.now())
        >>> brs.check_new_post('bob', 'post-2')
        True
        """
        if self.author == author and self.permlink == permlink:
            return False
        else:
            return True
    def get_data(self) -> BeneficiaryRewardsData:
        """
        Returns the data for the current post's beneficiary rewards in structured form.

        :return: A dictionary containing the author, permlink, reward time, and reward list.

        Example:
        >>> brs = BeneficiaryRewards('alice', 'post-1', datetime.now())
        >>> brs.add_reward({'benefactor': 'bob', 'vesting_payout': '1234 VESTS'}, checker)
        >>> brs.get_data()
        {
            'author': 'alice',
            'permlink': 'post-1',
            'reward_time': datetime.datetime(...),
            'rewards': [{'beneficiary': 'bob', 'vests': 1234}]
        }
        """
        return {
            'author':self.author,
            'permlink':self.permlink,
            'reward_time':self.reward_time,
            'rewards':self.rewards
        }

def handle_beneficiary_reward(block:Dict[str, Any], date:datetime, checker:AccountChecker, brs:BeneficiaryRewards,
                              beneficiary_rewards:List[BeneficiaryRewardData]) -> None:
    """
    Processes a `comment_benefactor_reward` block, extracting reward data while ensuring involved accounts are tracked.
    :param block: A blockchain operation of type `comment_benefactor_reward`.
    :param date: The UTC timestamp of when the reward was processed.
    :param checker: An instance of the Account Checker class for checking accounts
    :param brs: An instance of the BeneficiaryRewards class for tracking a post's beneficiary rewards.
    :param beneficiary_rewards: A list to which parsed beneficiary reward entries will be appended.
    :return: None

    Example:
        >>> handle_beneficiary_reward(block, date, s, [], acc_in_db, [])
        None
    """
    author = block['author']
    checker.check(author)
    permlink = block['permlink']
    if brs.check_new_post(author, permlink):
        brs_data = brs.get_data()
        if brs_data['author'] != None:
            beneficiary_rewards.append(brs_data)
        brs = BeneficiaryRewards(author, permlink, date)
    brs.add_reward(block, checker)
    return brs