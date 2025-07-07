USE SteemSQL;

-- Procedure: insert_accounts
-- Purpose: Inserts new accounts into the `accounts` table from a JSON array.
-- Skips duplicate usernames that already exist.

DELIMITER $$

DROP PROCEDURE IF EXISTS insert_accounts;
CREATE PROCEDURE insert_accounts(
	IN account_data JSON
)
BEGIN
	DECLARE total INT DEFAULT 0;
    DECLARE i INT DEFAULT 0;
    
    DROP TEMPORARY TABLE IF EXISTS temp_accounts;
    CREATE TEMPORARY TABLE temp_accounts(
		username VARCHAR(16) NOT NULL PRIMARY KEY,
        date_created DATETIME NOT NULL
    );
    
    SET total = JSON_LENGTH(account_data);
    
    WHILE i < total DO
		INSERT INTO temp_accounts(username, date_created)
        VALUES (
			JSON_UNQUOTE(JSON_EXTRACT(account_data, CONCAT('$[', i, '].username'))),
            JSON_UNQUOTE(JSON_EXTRACT(account_data, CONCAT('$[', i, '].date_created')))
        );
        SET i = i + 1;
	END WHILE;
    
    INSERT INTO accounts(username, date_created)
    SELECT tmp.username, tmp.date_created
    FROM temp_accounts tmp
    LEFT JOIN accounts acc ON tmp.username = acc.username
    WHERE acc.username IS NULL;
    
	DROP TEMPORARY TABLE temp_accounts;
END $$

DELIMITER ;

-- Procedure: insert_steem_price_history
-- Purpose: Inserts historical STEEM price data from a JSON array.
-- Ensures no duplicate dates are inserted.

DELIMITER $$

DROP PROCEDURE IF EXISTS insert_steem_price_history $$
CREATE PROCEDURE insert_steem_price_history(IN price_json JSON)
BEGIN
    DECLARE v_date DATE;
    DECLARE v_open DECIMAL(10,4);
    DECLARE v_high DECIMAL(10,4);
    DECLARE v_low DECIMAL(10,4);
    DECLARE v_close DECIMAL(10,4);
    DECLARE v_volume BIGINT;

    -- Extract fields from JSON
    SET v_date   = JSON_UNQUOTE(JSON_EXTRACT(price_json, '$.date'));
    SET v_open   = JSON_EXTRACT(price_json, '$.open');
    SET v_high   = JSON_EXTRACT(price_json, '$.high');
    SET v_low    = JSON_EXTRACT(price_json, '$.low');
    SET v_close  = JSON_EXTRACT(price_json, '$.close');
    SET v_volume = JSON_EXTRACT(price_json, '$.volume');

    -- Insert or update the table
    INSERT INTO steem_price_history (date, open, high, low, close, volume)
    VALUES (v_date, v_open, v_high, v_low, v_close, v_volume)
    ON DUPLICATE KEY UPDATE
        open = VALUES(open),
        high = VALUES(high),
        low = VALUES(low),
        close = VALUES(close),
        volume = VALUES(volume);
END$$
DELIMITER ;