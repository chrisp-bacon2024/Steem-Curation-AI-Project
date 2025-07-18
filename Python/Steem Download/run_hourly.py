import time
from SteemSQL.connection import SteemSQL, get_user_pass

def run_hourly_curation_history(config_path: str):
    """
    Connects to the SteemSQL database and runs the `populate_voter_curation_history`
    stored procedure every hour.
    """
    user, password = get_user_pass(config_path)
    db = SteemSQL(user, password, 'SteemSQL')
    db.connect()

    print("Starting hourly voter curation history updates...")

    while True:
        try:
            print("\nRunning populate_voter_curation_history()...")
            with db.connection.cursor() as cursor:
                cursor.callproc("populate_voter_curation_history")
                db.connection.commit()
                print("Procedure completed successfully.")
                to_run = ['author', 'curation', 'beneficiary']
                for name in to_run:
                    print(f'update_value_and_steem_for_{name}_rewards')
                    cursor.callproc(f'update_value_and_steem_for_{name}_rewards')

        except Exception as e:
            print(f"Error running procedure: {e}")

        print("Sleeping for 5 min...")
        time.sleep(60 * 5)  # Sleep for 5 min

if __name__ == '__main__':
    run_hourly_curation_history("D:\\Steem Curation AI Project\\config.ini")