from steemstream.stream_blocks import stream_data
from steemstream.stream_prices import stream_prices
from steemutils.block_lookup import find_first_block_on_date
from datetime import datetime, timedelta, timezone
from steem import Steem
from steem.blockchain import Blockchain
from steembase.exceptions import RPCError
from time import sleep

import threading

CONFIG_PATH = "D:\\Steem Curation AI Project\\config.ini"

def start_block_stream(most_recent:bool=False, nodes:list=None, config_path:str=''):
    s = Steem(nodes=nodes)
    blck = Blockchain(s)
    if most_recent:
        with open(r"data\most_recent_block_inserted", "r") as f:
            first_line = f.readline()
            block_num = int(first_line.strip())
    else:
        target_date = datetime.now(timezone.utc) - timedelta(days=409)
        block_num = find_first_block_on_date(target_date, s, blck)

    trying = True
    attempts = 0
    while trying:
        try:
            stream_data(block_num, s, blck, records_to_insert=1000, config_path=config_path)
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



if __name__ == '__main__':
    block_thread = threading.Thread(target=start_block_stream, kwargs={'most_recent':True, 'config_path':CONFIG_PATH}, name='BlockStreamThread')
    price_thread = threading.Thread(target=stream_prices, kwargs={'time_to_wait': 30, 'config_path':CONFIG_PATH})

    block_thread.start()
    price_thread.start()

    block_thread.join()
    price_thread.join()
