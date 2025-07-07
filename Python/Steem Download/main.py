from steemstream.stream_blocks import stream_data
from steemutils.block_lookup import find_first_block_on_date
from datetime import datetime, timedelta, timezone
from steem import Steem
from steem.blockchain import Blockchain
from steembase.exceptions import RPCError
from time import sleep

if __name__ == '__main__':
    s = Steem()
    blck = Blockchain()
    #target_date = datetime.now(timezone.utc) - timedelta(days=409)
    #block_num = find_first_block_on_date(target_date, s, blck)
    with open(r"data\most_recent_block_inserted", "r") as f:
        first_line = f.readline()
        block_num = int(first_line.strip())
    trying = True
    attempts = 0
    while trying:
        try:
            stream_data(block_num, s, blck, records_to_insert=1000)
            if attempts > 0:
                attempts = 0
        except RPCError:
            if attempts > 100:
                raise RPCError('RPC Error occured more than 100 times!')
                trying = False
            else:
                with open(r"data\most_recent_block", "r") as f:
                    first_line = f.readline()
                    block_num = int(first_line.strip())
                attempts += 1
                sleep(1)
                trying = True