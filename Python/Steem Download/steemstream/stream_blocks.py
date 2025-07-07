from SteemSQL.connection import SteemSQL, get_user_pass
from steem import Steem
from steem.blockchain import Blockchain
from steemstream.account import AccountChecker
from datetime import timezone
import steemstream.process.post as pp
import steemstream.process.social as ps
import steemstream.process.reward as pr
from steembase.exceptions import RPCError
from time import sleep



def insert_data(data_to_insert:dict[str, list], db:SteemSQL, most_recent_block:int, length_to_insert:int=100) -> bool:
    """
    Inserts streaming data into the database based on a specified structure and threshold.

    This function checks whether the total amount of data across all categories reaches
    the specified threshold (`length_to_insert`). If it does, it inserts each list into
    the database using its corresponding stored procedure.

    The insertion order matters and should follow this structure:

    1. Accounts
    2. Posts
    3. Post Beneficiaries
    4. Post Bodies
    5. Body Languages
    6. Body Tags
    7. Post Comments
    8. Post Resteems
    9. Post Values
    10. Votes
    11. Author Rewards
    12. Curation Rewards
    13. Beneficiary rewards

    Special Case:
        - The `post_values` key uses the procedure `update_post_values` instead of `insert_post_values`.

    :param data_to_insert: A dictionary mapping category names (table/procedure identifiers) to lists of JSON-serializable data.
    :param db: A database wrapper instance with a `.insert_multiple()` method to perform batch inserts.
    :param most_recent_block: The block number for the most recently inserted block to ensure the program starts at the right place if it crashes.
    :param length_to_insert: The total number of items across all categories required to trigger insertion. Defaults to 100.
    :return: `True` if data was inserted into the database; `False` otherwise.

    Example:
        >>> data = {
        ...     'accounts': [{'username': 'alice', 'date_created': '2024-01-01T00:00:00'}],
        ...     'posts': [{'author': 'alice', 'permlink': 'my-first-post', 'created': '2024-01-02T12:00:00',
        ...                'category': 'life', 'total_value': 0.00}],
        ...     'beneficiaries': [], 'bodies': [], 'languages': [], 'tags': [],
        ...     'comments': [], 'resteems': [],
        ...     'post_values': [{'author': 'alice', 'permlink': 'my-first-post', 'total_value': 3.50}],
        ...     'votes': [], 'author_rewards': [], 'curation_rewards': [], 'beneficiary_rewards': []
        ... }
        >>> db = SteemSQL('user', 'pass', 'SteemSQL')
        >>> db.connect()
        >>> insert_data(data, db, recent_block_num=54321000, length_to_insert=1)
        True
    """
    total_length = sum(len(v) for v in data_to_insert.values())
    if total_length >= length_to_insert:
        for i, (key, data) in enumerate(data_to_insert.items()):
            if key == 'post_values':
                procedure = f'update_pending_post_percentiles_values'
            else:
                procedure = f'insert_{key}'
            db.insert_multiple(procedure=procedure, to_insert = data)
        with open(r"data\most_recent_block_inserted", "w+") as f:
            f.write(str(most_recent_block))
        with open(r"data\highest_block_inserted", "r+") as f:
            first_line = f.readline()
            highest_block_num = int(first_line.strip())
            if most_recent_block > highest_block_num:
                f.seek(0)
                f.write(str(most_recent_block))
        return True
    return False

def stream_data(start_block:int, s:Steem, blockchain:Blockchain, records_to_insert:int=1000):
    """
    Streams Steem blockchain operations starting from a given block and collects structured data for insertion.

    This function monitors blockchain activity in real-time (or from a starting block) and extracts
    relevant operations including posts, votes, rewards, resteems, and metadata. It aggregates these
    into categorized lists and periodically prepares them for database insertion.
    :param start_block:
    :param s:
    :param blockchain:
    :param records_to_insert:
    :return:
    """
    user, password = get_user_pass(r"D:\Steem Curation AI Project\config.ini")
    ssql = SteemSQL(user, password, 'SteemSQL')
    ssql.connect()
    accounts_in_db = ssql.get('get_account_usernames')
    filter_by = ['account_create', 'account_create_with_delegation', 'comment', 'comment_options', 'vote', 'author_reward',
                 'curation_reward', 'custom_json', 'comment_benefactor_reward']

    accounts = []
    checker = AccountChecker(s, accounts, accounts_in_db)
    posts = []
    beneficiaries = []
    bodies = []
    body_languages = []
    body_tags = []
    post_values = []
    comments = []
    resteems = []
    votes = []
    author_rewards = []
    crs = pr.CurationRewards(None, None, None)
    curation_rewards = []
    brs = pr.BeneficiaryRewards(None, None, None)
    beneficiary_rewards = []
    inserts = 0

    for block in blockchain.stream(start_block=start_block, filter_by=filter_by):
        with open(r"data\most_recent_block", "w+") as f:
            f.write(str(block['block_num']))
        data_to_insert = {'accounts':accounts, 'posts':posts, 'beneficiaries':beneficiaries, 'bodies':bodies,
                          'languages':body_languages, 'tags':body_tags, 'comments':comments, 'resteems':resteems,
                          'post_values':post_values, 'votes':votes, 'author_rewards':author_rewards,
                          'curation_rewards':curation_rewards, 'beneficiary_rewards':beneficiary_rewards}

        inserted = insert_data(data_to_insert, ssql, block['block_num'], length_to_insert=records_to_insert)
        if inserted:
            inserts += 1
            accounts = []
            posts = []
            beneficiaries = []
            bodies = []
            body_languages = []
            body_tags = []
            post_values = []
            comments = []
            resteems = []
            votes = []
            author_rewards = []
            curation_rewards = []
            beneficiary_rewards = []

            accounts_in_db = ssql.get('get_account_usernames')
            checker.update(accounts, accounts_in_db)

        b_type = block['type']
        date = block['timestamp'].replace(tzinfo=timezone.utc)

        summary = ', '.join(f"{k}:{len(v)}" for k, v in data_to_insert.items())
        print(f"\r{date} | {summary} | Inserts:{inserts}", end="", flush=True)

        attempts = 0
        trying = True
        block_check = int(block['block_num']) < 84763551
        while trying:
            try:
                if block_check:
                    if b_type == 'vote':
                        ps.handle_vote(block, date, s, checker, votes)
                    elif b_type == 'curation_reward':
                        crs = pr.handle_curation_reward(block, date, s, checker, crs, post_values, curation_rewards)
                    elif b_type == 'comment_benefactor_reward':
                        brs = pr.handle_beneficiary_reward(block, date, checker, brs, beneficiary_rewards)
                else:
                    if b_type == 'comment':
                        if block['parent_author'] == '':
                            pp.handle_post(block, date, s, checker, posts, bodies, body_languages, body_tags)
                        else:
                            pp.handle_comment(block, date, s, checker, comments)
                    elif b_type == 'comment_options':
                        pp.handle_beneficiary(block, checker, beneficiaries)
                    elif b_type == 'custom_json':
                        ps.handle_resteem(block, date, checker, resteems)
                    elif b_type == 'vote':
                        ps.handle_vote(block, date, s, checker, votes)
                    elif b_type == 'author_reward':
                        pr.handle_author_reward(block, date, checker, author_rewards)
                    elif b_type == 'curation_reward':
                        crs = pr.handle_curation_reward(block, date, s, checker, crs, post_values, curation_rewards)
                    elif b_type == 'comment_benefactor_reward':
                        brs = pr.handle_beneficiary_reward(block, date, checker, brs, beneficiary_rewards)
                trying = False
            except RPCError:
                attempts += 1
                if attempts > 100:
                    raise RPCError('RPC Error received more than 100 times!')
                sleep(1)