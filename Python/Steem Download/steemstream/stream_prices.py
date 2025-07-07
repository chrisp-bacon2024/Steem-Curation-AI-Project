# === Module Documentation ===
"""
stream_prices.py

This module handles the retrieval and insertion of daily STEEM price data into the database
for use in valuation and payout analytics. It integrates with the Yahoo Finance API and the
SteemSQL database interface to fetch any missing historical price data and insert it into
the `steem_price_history` table.

Core Responsibilities:
- Retrieve missing STEEM price dates from the database
- Wait until data is available (12:30 AM UTC the following day) before attempting retrieval
- Download OHLCV data from Yahoo Finance
- Insert each day's price data into the database via a stored procedure
- Stream periodically to keep price history current

Key Functions:
- `get_missing_prices`: Collects and inserts price data for any missing reward dates
- `stream_prices`: Continuously checks for and fills in missing STEEM price data on a timed loop

This module is typically used in conjunction with a reward tracking pipeline that relies on
STEEM-to-USD conversions to calculate the Steem and USD value of different types of rewards on the
Steem blockchain.
"""

# === Imports ===
from datetime import datetime, timedelta, time # Standard Library
from zoneinfo import ZoneInfo
import time as t

import pandas as pd # Third-party packages
import yfinance as yf

from SteemSQL.connection import SteemSQL, get_user_pass # Local application


# === Function Definitions ===
def get_missing_prices(ssql: SteemSQL) -> None:
    """
    Fetches missing STEEM price data and inserts it into the database.

    This function retrieves a list of dates for which price data is missing from the
    `steem_price_history` table. For each date, it checks whether it is past 12:30 AM UTC
    on the following day (when full day price data is available). If not, it waits until
    that time.

    Once the date is eligible, the function uses Yahoo Finance (`yfinance`) to retrieve the
    OHLCV data for "STEEM-USD" and inserts it into the database using the
    `insert_steem_price_history` stored procedure.

    :param ssql: A connected SteemSQL database client instance.
    :return: None

    Example:
        >>> ssql = SteemSQL(user, password, 'SteemSQL')
        >>> ssql.connect()
        >>> get_missing_prices(ssql)
    """
    missing_dates = ssql.get('get_missing_price_dates')
    price_data = []
    missing_dates['reward_date'] = pd.to_datetime(missing_dates['reward_date'])
    for reward_date in missing_dates['reward_date']:
        reward_date = reward_date.date()
        deadline = datetime.combine(reward_date + timedelta(days=1), time(0, 30), tzinfo=ZoneInfo("UTC"))
        now = datetime.now(ZoneInfo('UTC'))
        if now < deadline:
            sleep_seconds = (deadline - now).total_seconds()
            print(f"Waiting {int(sleep_seconds)} seconds until {deadline} to fetch price for {reward_date}")
            t.sleep(sleep_seconds)
        start_str = reward_date.strftime('%Y-%m-%d')
        end_str = (reward_date + timedelta(days=1)).strftime('%Y-%m-%d')
        data = yf.download("STEEM-USD", start=start_str, end=end_str, interval='1d')

        if not data.empty:
            row = data.iloc[0]
            price_json = {
                'date': str(reward_date),
                'open': round(float(row['Open'].iloc[0]), 4),
                'high': round(float(row['High'].iloc[0]), 4),
                'low': round(float(row['Low'].iloc[0]), 4),
                'close': round(float(row['Close'].iloc[0]), 4),
                'volume': int(row['Volume'].iloc[0])
            }
            success = ssql.insert("insert_steem_price_history", price_json)
            if success:
                print(f"Inserted price data for {reward_date}")
            else:
                print(f"Failed to insert price data for {reward_date}")
                print(price_json)
        else:
            print(f"No data found for {reward_date}")


def stream_prices(time_to_wait: int = 30) -> None:
    """
    Starts a continuous loop that regularly checks and inserts missing STEEM price data.

    This function creates a connection to the database and enters a loop that repeatedly
    calls `get_missing_prices` every `time_to_wait` minutes. If a failure occurs during
    the fetch or insert process, it retries up to 100 times, waiting 10 seconds between
    attempts.

    Example:
        >>> stream_prices(time_to_wait=15)


    :param time_to_wait: Number of minutes to wait between updates. Defaults to 30 minutes.
    :return: None
    """
    streaming = True
    user, password = get_user_pass(r"D:\Python\Steem Download\config\database_config.ini")
    ssql = SteemSQL(user, password, 'SteemSQL')
    ssql.connect()
    while streaming:
        attempts = 0
        attempting = True
        while attempting:
            try:
                get_missing_prices(ssql)
                attempting = False
            except Exception as e:
                if attempts > 100:
                    attempting = False
                    streaming = False
                    raise (f'Attempted more than 100 times. Error: {e}')
                else:
                    print(f'Error: {e}\n Sleeping for 10 seconds')
                    attempts += 1
                    t.sleep(10)
        print(f'Sleeping for {time_to_wait} minutes')
        t.sleep(time_to_wait * 60)

# === Script Entry Point ===
if __name__ == "__main__":
    stream_prices()
