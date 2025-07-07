from datetime import datetime, timezone, timedelta


def get_block_timestamp(s, block_num):
    """Returns the timestamp of a block as a UTC datetime object."""
    block = s.get_block(block_num)
    if block is None:
        return None
    return datetime.strptime(block['timestamp'], "%Y-%m-%dT%H:%M:%S").replace(tzinfo=timezone.utc)


def find_first_block_on_date(date_obj, s, blockchain):
    """
    Finds the first block on a given UTC date.

    Parameters:
    - date_obj: a datetime.date object
    - s: a Steem instance
    - blockchain: a Blockchain instance

    Returns:
    - block number of the first block on the given date (UTC), or None if not found
    """
    # Define target date range in UTC
    target_start = datetime.combine(date_obj, datetime.min.time()).replace(tzinfo=timezone.utc)
    target_end = target_start + timedelta(days=1)

    # Define search space
    low = 1
    high = blockchain.get_current_block_num()
    result = None

    while low <= high:
        mid = (low + high) // 2
        mid_timestamp = get_block_timestamp(s, mid)

        if mid_timestamp is None:
            high = mid - 1
            continue

        if mid_timestamp < target_start:
            low = mid + 1
        elif mid_timestamp >= target_end:
            high = mid - 1
        else:
            # Found a block on the target date — search left for earlier match
            result = mid
            high = mid - 1

    return result