import mysql.connector
from mysql.connector import Error
import json
import configparser
import pandas as pd

class SteemSQL():
    def __init__(self, user, password, database, host='localhost'):
        """Initialize the database connection."""
        self.host = host
        self.user = user
        self.password = password
        self.database = database
        self.connection = None

    def connect(self):
        """Establish database connection."""
        try:
            self.connection = mysql.connector.connect(
                host=self.host,
                user=self.user,
                password=self.password,
                database=self.database,
                auth_plugin="caching_sha2_password"
            )
            if self.connection.is_connected():
                print("Connected to database")
        except Error as e:
            print(f"Error connecting to database: {e}")
            self.connection = None

    def close(self):
        """Close the database connection."""
        if self.connection and self.connection.is_connected():
            self.connection.close()
            print("Database connection closed.")

    def insert(self, procedure, to_insert):
        if not self.connection:
            print("No database connection.")
            return False

        try:

            # Convert the list of dictionaries to a JSON string
            json_payload = json.dumps(to_insert, default=str)  # Convert datetime to string if needed

            with self.connection.cursor() as cursor:
                cursor.callproc(f"{procedure}", [json_payload])
                self.connection.commit()
                print(f"Inserted successfully using {procedure}.")
                return True
        except Error as e:
            print(f"Error inserting using {procedure}: {e}")
            return False



    def insert_multiple(self, procedure, to_insert):
        """
        Inserts multiple bodies into the database using the stored procedure insert_bodies.
        :param posts: List of dictionaries containing post data.
        """
        if not self.connection:
            print("No database connection.")
            return False

        try:
            # Convert the list of dictionaries to a JSON string
            body_json = json.dumps(to_insert, default=str)  # Convert datetime to string if needed

            with self.connection.cursor() as cursor:
                cursor.callproc(f"{procedure}", (body_json,))
                self.connection.commit()
                return True
        except Error as e:
            print('')
            print(f"Error inserting using {procedure}: {e}")
            return False

    def get(self, proc_name, params=None, fetch_all=True):
        if not self.connection:
            print("No database connection.")
            return None

        with self.connection.cursor() as cursor:
            cursor.callproc(proc_name, params or [])

            frames = []
            for result in cursor.stored_results():
                data = result.fetchall()
                columns = result.column_names

                if fetch_all:
                    frame = pd.DataFrame(data, columns=columns)
                    frames.append(frame)
                else:
                    if data:
                        frame = pd.DataFrame([data[0]], columns=columns)
                        frames.append(frame)

            if frames:
                # If multiple result sets, concatenate them
                return pd.concat(frames, ignore_index=True)
            else:
                return pd.DataFrame()  # Return empty DataFrame if no results

# Read the config file

def get_user_pass(path):
    config = configparser.ConfigParser()
    config.read(path)
    username = config['credentials']['username']
    password = config['credentials']['password']
    return username, password

