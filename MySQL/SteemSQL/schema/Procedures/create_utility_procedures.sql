USE SteemSQL;

-- Procedure: get_missing_price_dates
-- Purpose: Identifies all unique post dates from the `author_rewards`, `curation_rewards`, and `beneficiary_rewards` tables that do not yet have
--          corresponding entries in the `steem_price_history` table.

DELIMITER $$

DROP PROCEDURE IF EXISTS get_missing_price_dates $$
CREATE PROCEDURE get_missing_price_dates()
BEGIN
    SELECT DISTINCT missing_dates.reward_date
    FROM (
        SELECT DISTINCT DATE(reward_time) AS reward_date FROM curation_rewards
        UNION
        SELECT DISTINCT DATE(reward_time) AS reward_date FROM author_rewards
        UNION
        SELECT DISTINCT DATE(reward_time) AS reward_date FROM beneficiary_rewards
    ) AS missing_dates
    LEFT JOIN steem_price_history sph
        ON missing_dates.reward_date = sph.date
    WHERE sph.date IS NULL
    ORDER BY missing_dates.reward_date;
END $$
DELIMITER ;

-- Procedure: get_steem_price_on_date
-- Purpose: Retrieves the closing STEEM price for a specific historical date.

DELIMITER $$
DROP PROCEDURE IF EXISTS get_steem_price_on_date;
CREATE PROCEDURE get_steem_price_on_date(IN reward_date DATE, OUT steem_price DECIMAL(10,4))
BEGIN
    SELECT close INTO steem_price
    FROM steem_price_history
    WHERE date = reward_date
    LIMIT 1;
END $$
DELIMITER ;

-- Procedure: get_steem_prices
-- Purpose: Returns all historical STEEM price records in the `steem_price_history` table.

DELIMITER $$

DROP PROCEDURE IF EXISTS get_steem_prices;
CREATE PROCEDURE get_steem_prices()
BEGIN
SELECT * FROM steem_price_history;
END $$

DELIMITER ;

-- Procedure: calculate_efficiency_stats
-- Purpose: Computes summary statistics (count, min, max, average, median) for a voter's curation efficiency
--          within a given number of days before a specified point in time.

DELIMITER $$ 
DROP PROCEDURE IF EXISTS calculate_efficiency_stats;
CREATE PROCEDURE calculate_efficiency_stats(
    IN in_voter VARCHAR(16),
    IN in_time DATETIME,
    IN in_days INT,
	
    OUT out_total_rewards INT,
    OUT out_min_efficiency INT,
    OUT out_max_efficiency INT,
    OUT out_avg_efficiency INT,
    OUT out_med_efficiency INT
)
BEGIN
    DECLARE mid_offset INT DEFAULT 0;

    -- Total rewards
    SELECT COUNT(*) INTO out_total_rewards
    FROM temp_voter_three_month_history
    WHERE reward_time BETWEEN in_time - INTERVAL in_days DAY AND in_time;

    IF out_total_rewards > 0 THEN
        -- Min efficiency
        SELECT MIN(efficiency)
        INTO out_min_efficiency
        FROM temp_voter_three_month_history
        WHERE reward_time BETWEEN in_time - INTERVAL in_days DAY AND in_time;

        -- Max efficiency
        SELECT MAX(efficiency)
        INTO out_max_efficiency
        FROM temp_voter_three_month_history
        WHERE reward_time BETWEEN in_time - INTERVAL in_days DAY AND in_time;

        -- Avg efficiency
        SELECT FLOOR(AVG(efficiency))
        INTO out_avg_efficiency
        FROM temp_voter_three_month_history
        WHERE reward_time BETWEEN in_time - INTERVAL in_days DAY AND in_time;

        -- Compute median
        SELECT FLOOR(out_total_rewards / 2) INTO mid_offset;

        SELECT efficiency
        INTO out_med_efficiency
        FROM (
            SELECT efficiency
            FROM temp_voter_three_month_history
			WHERE reward_time BETWEEN in_time - INTERVAL in_days DAY AND in_time
            ORDER BY efficiency
            LIMIT 1 OFFSET mid_offset
        ) AS sub;
    ELSE
        -- If no rewards found, set everything to NULL or zero
        SET out_min_efficiency = 0;
        SET out_max_efficiency = 0;
        SET out_avg_efficiency = 0;
        SET out_med_efficiency = 0;
    END IF;
END $$

DELIMITER ;

-- Procedure: populate_voter_curation_history
-- Purpose: For each entry in `pending_vote_history`, populates `voter_curation_history` with stats over multiple day windows.
-- Behavior:
-- - Uses the associated post's `curation_rewards` data to summarize efficiency.
-- - Deletes from `pending_vote_history` after processing.

DELIMITER $$

DROP PROCEDURE IF EXISTS populate_voter_curation_history $$
CREATE PROCEDURE populate_voter_curation_history()
BEGIN
    DECLARE done INT DEFAULT 0;
    DECLARE v_author VARCHAR(16);
    DECLARE v_permlink VARCHAR(256);
    DECLARE v_voter VARCHAR(16);
    DECLARE p_time DATETIME;
    DECLARE last_time DATETIME;

    DECLARE tf_days INT;
    DECLARE tf_total INT;
    DECLARE tf_min INT;
    DECLARE tf_max INT;
    DECLARE tf_avg INT;
    DECLARE tf_med INT;
    
    DECLARE v_offset BIGINT;

    DECLARE missing_votes CURSOR FOR
        SELECT author, permlink, voter, created FROM temp_votes_to_process;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    -- Step 2: Build vote list
    DROP TEMPORARY TABLE IF EXISTS temp_votes_to_process;
    CREATE TEMPORARY TABLE temp_votes_to_process (
        author VARCHAR(16),
        permlink VARCHAR(256),
        voter VARCHAR(16),
        created DATETIME,
        UNIQUE(author, permlink, voter)
    );

    INSERT IGNORE INTO temp_votes_to_process (author, permlink, voter, created)
    SELECT DISTINCT pvh.author, pvh.permlink, pvh.voter, p.created
    FROM pending_vote_history pvh
    JOIN posts p ON pvh.author = p.author AND p.permlink = pvh.permlink
    WHERE NOT EXISTS (
        SELECT 1 FROM voter_curation_history vch
        WHERE vch.author = pvh.author AND vch.permlink = pvh.permlink AND vch.voter = pvh.voter
    );

    -- Step 3: Prepare temp output
    DROP TEMPORARY TABLE IF EXISTS temp_voter_curation_history;
    CREATE TEMPORARY TABLE temp_voter_curation_history (
        author VARCHAR(16),
        permlink VARCHAR(256),
        voter VARCHAR(16),
        days TINYINT,
        total_rewards INT,
        min_efficiency INT,
        max_efficiency INT,
        avg_efficiency INT,
        med_efficiency INT,
        UNIQUE(author, permlink, voter, days)
    );
    
    DROP TEMPORARY TABLE IF EXISTS temp_votes_to_delete;
	CREATE TEMPORARY TABLE temp_votes_to_delete (
		author VARCHAR(16),
		permlink VARCHAR(256),
		voter VARCHAR(16),
		PRIMARY KEY (author, permlink, voter)
	);

    -- Step 4: Process
    OPEN missing_votes;
    read_loop: LOOP
        FETCH missing_votes INTO v_author, v_permlink, v_voter, p_time;
        IF done THEN
            LEAVE read_loop;
        END IF;

        DROP TEMPORARY TABLE IF EXISTS temp_voter_three_month_history;
        CREATE TEMPORARY TABLE temp_voter_three_month_history (
            reward_time DATETIME,
            efficiency INT
        );

        INSERT INTO temp_voter_three_month_history (reward_time, efficiency)
        SELECT reward_time, efficiency
        FROM curation_rewards
        WHERE curator = v_voter
          AND reward_time BETWEEN p_time - INTERVAL 90 DAY AND p_time;

        -- Loop through all tf_days
        SET tf_days = 7;
        tf_loop: WHILE tf_days <= 90 DO
            CALL calculate_efficiency_stats(
                v_voter, p_time, tf_days,
                tf_total, tf_min, tf_max, tf_avg, tf_med
            );

            IF tf_total > 0 THEN
                INSERT IGNORE INTO temp_voter_curation_history (
                    author, permlink, voter, days,
                    total_rewards, min_efficiency, max_efficiency,
                    avg_efficiency, med_efficiency
                ) VALUES (
                    v_author, v_permlink, v_voter, tf_days,
                    tf_total, tf_min, tf_max, tf_avg, tf_med
                );
            END IF;

            CASE tf_days
                WHEN 7 THEN SET tf_days = 14;
                WHEN 14 THEN SET tf_days = 21;
                WHEN 21 THEN SET tf_days = 28;
                WHEN 28 THEN SET tf_days = 60;
                WHEN 60 THEN SET tf_days = 90;
                ELSE LEAVE tf_loop;
            END CASE;
        END WHILE tf_loop;

        DROP TEMPORARY TABLE IF EXISTS temp_voter_three_month_history;
        INSERT IGNORE INTO temp_votes_to_delete (author, permlink, voter)
		VALUES (v_author, v_permlink, v_voter);

    END LOOP;
    CLOSE missing_votes;

    -- Step 5: Commit results
    INSERT INTO voter_curation_history (
        author, permlink, voter, days,
        total_rewards, min_efficiency, max_efficiency,
        avg_efficiency, med_efficiency
    )
    SELECT tvch.author, tvch.permlink, tvch.voter, tvch.days,
           tvch.total_rewards, tvch.min_efficiency, tvch.max_efficiency,
           tvch.avg_efficiency, tvch.med_efficiency
    FROM temp_voter_curation_history tvch
    LEFT JOIN voter_curation_history vch
		ON tvch.author = vch.author
        AND tvch.permlink = vch.permlink
        AND tvch.voter = vch.permlink
        AND tvch.days = vch.days
	WHERE vch.days IS NULL;

    -- Cleanup
    DROP TEMPORARY TABLE IF EXISTS temp_votes_to_process;
    DROP TEMPORARY TABLE IF EXISTS temp_voter_curation_history;
    
    DELETE pvh
	FROM pending_vote_history pvh
	JOIN temp_votes_to_delete t
	  ON pvh.author = t.author AND pvh.permlink = t.permlink AND pvh.voter = t.voter;
      
	DROP TEMPORARY TABLE IF EXISTS temp_votes_to_delete;


END $$
DELIMITER ;
