from datetime import datetime

def convert_time(date:str) -> datetime:
    """
    Convert an ISO 8601 datetime string to a datetime object.
    :param date: A string in the format '%Y-%m-%dT%H:%M:%S' (e.g., '2024-01-15T13:45:00').
    :return: A datetime object representing the parsed date and time.
    """

    return datetime.strptime(date, '%Y-%m-%dT%H:%M:%S')

def convert_time_stamp(timestamp:int):
    """
    Converts a UNIX timestamp to a human-readable date string in the format 'dd-mm-yyyy'.
    :param timestamp: A UNIX timestamp (seconds since the epoch)
    :return: A string representing the date in the format 'dd-mm-yy'.
    """
    return datetime.fromtimestamp(timestamp).strftime('%d-%m-%Y')


def get_time(date):
    """
    Converts a datetime object to a UNIX timestamp (as an integer).
    :param date: A datetime object to convert.
    :return: The corresponding UNIX timestamp, rounded to the nearest second.
    """
    return int(round(date.timestamp()))