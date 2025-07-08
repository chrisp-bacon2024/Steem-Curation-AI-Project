-- Procedure: insert_author_rewards
-- Purpose: Inserts author reward records for posts.
-- Notes:
-- - Avoids duplicates using a temporary table.
-- - Initial value and steem are left NULL (to be updated later).

DELIMITER $$

DROP PROCEDURE IF EXISTS insert_author_rewards $$
CREATE PROCEDURE insert_author_rewards(IN rewards_json JSON)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE total_entries INT;

    -- Variables for each author reward
    DECLARE v_author VARCHAR(16);
    DECLARE v_permlink VARCHAR(256);
    DECLARE v_reward_time DATETIME;
    DECLARE v_vests BIGINT UNSIGNED;

    -- Create a temporary table for batch insert
    DROP TEMPORARY TABLE IF EXISTS temp_author_rewards;
    CREATE TEMPORARY TABLE temp_author_rewards (
        author VARCHAR(16) NOT NULL,
        permlink VARCHAR(256) NOT NULL,
        reward_time DATETIME NOT NULL,
        vests BIGINT UNSIGNED NOT NULL,
        
        UNIQUE KEY uniq_comment (author, permlink, reward_time)
    );

    SET total_entries = JSON_LENGTH(rewards_json);

    WHILE i < total_entries DO
        -- Extract the reward details from JSON input
        SET v_author = JSON_UNQUOTE(JSON_EXTRACT(rewards_json, CONCAT('$[', i, '].author')));
        SET v_permlink = JSON_UNQUOTE(JSON_EXTRACT(rewards_json, CONCAT('$[', i, '].permlink')));
        SET v_reward_time = JSON_UNQUOTE(JSON_EXTRACT(rewards_json, CONCAT('$[', i, '].reward_time')));
        SET v_vests = JSON_UNQUOTE(JSON_EXTRACT(rewards_json, CONCAT('$[', i, '].vests')));

        -- Add to temp table
        INSERT IGNORE INTO temp_author_rewards (author, permlink, reward_time, vests)
        VALUES (v_author, v_permlink, v_reward_time, v_vests);

        SET i = i + 1;
    END WHILE;

    -- Final insert: only where a post exists and no existing reward
    INSERT INTO author_rewards (author, permlink, reward_time, vests)
    SELECT tar.author, tar.permlink, tar.reward_time, tar.vests
    FROM temp_author_rewards tar
    JOIN posts p ON p.author = tar.author AND p.permlink = tar.permlink
    LEFT JOIN author_rewards ar 
        ON ar.author = tar.author AND ar.permlink = tar.permlink
    WHERE ar.author IS NULL;

    -- Clean up
    DROP TEMPORARY TABLE temp_author_rewards;

    -- Update rewards with value + steem
    CALL update_value_and_steem_for_author_rewards();
END $$
DELIMITER ;

-- Procedure: insert_curation_rewards
-- Purpose: Inserts curation rewards (for curators who voted on a post).
-- Notes:
-- - Requires matching vote (vote_time used).
-- - value and steem fields are left NULL until updated later.

DELIMITER $$

DROP PROCEDURE IF EXISTS insert_curation_rewards $$
CREATE PROCEDURE insert_curation_rewards(IN rewards_json JSON)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE j INT DEFAULT 0;
    DECLARE total_posts INT;
    DECLARE total_rewards INT;

    -- Post variables
    DECLARE v_author VARCHAR(16);
    DECLARE v_permlink VARCHAR(256);
    DECLARE v_total_value DECIMAL(7,2);
    DECLARE v_reward_time DATETIME;
    DECLARE v_total_vests BIGINT;
    DECLARE v_total_rshares BIGINT;

    -- Reward variables
    DECLARE v_curator VARCHAR(16);
    DECLARE v_vests BIGINT;
    DECLARE v_vote_time DATETIME;
    DECLARE v_rshares BIGINT;
    DECLARE v_efficiency DECIMAL(10,4);
    DECLARE post_exists BOOLEAN;

    -- Create temporary table for batch insert
    DROP TEMPORARY TABLE IF EXISTS temp_curation_rewards;
    CREATE TEMPORARY TABLE temp_curation_rewards (
        author VARCHAR(16) NOT NULL,
        permlink VARCHAR(256) NOT NULL,
        curator VARCHAR(16) NOT NULL,
        reward_time DATETIME NOT NULL,
        vote_time DATETIME NOT NULL,
        vests BIGINT NOT NULL,
        efficiency DECIMAL(10,4) NOT NULL,
        
        UNIQUE KEY uniq_comment (author, permlink, curator)
    );

    SET total_posts = JSON_LENGTH(rewards_json);

    WHILE i < total_posts DO
        SET j = 0;
        SET v_author = JSON_UNQUOTE(JSON_EXTRACT(rewards_json, CONCAT('$[', i, '].author')));
        SET v_permlink = JSON_UNQUOTE(JSON_EXTRACT(rewards_json, CONCAT('$[', i, '].permlink')));
        SET v_reward_time = JSON_UNQUOTE(JSON_EXTRACT(rewards_json, CONCAT('$[', i, '].reward_time')));

        -- Check if the post exists
        SELECT COUNT(*) > 0 INTO post_exists
        FROM posts WHERE author = v_author AND permlink = v_permlink;

        IF post_exists THEN
            -- Get total value of post
            SELECT total_value INTO v_total_value
            FROM posts
            WHERE author = v_author AND permlink = v_permlink;

            -- Compute total vests
            CALL get_total_vests_for_post_using_cr(
                JSON_EXTRACT(rewards_json, CONCAT('$[', i, '].rewards')), 
                v_total_vests
            );

            -- Compute total rshares
            CALL get_total_rshares_for_post(v_author, v_permlink, v_total_rshares);

            -- Number of rewards for this post
            SET total_rewards = JSON_LENGTH(JSON_EXTRACT(rewards_json, CONCAT('$[', i, '].rewards')));

            WHILE j < total_rewards DO
                SET v_curator = JSON_UNQUOTE(JSON_EXTRACT(rewards_json, CONCAT('$[', i, '].rewards[', j, '].curator')));
                SET v_vests = JSON_UNQUOTE(JSON_EXTRACT(rewards_json, CONCAT('$[', i, '].rewards[', j, '].vests')));

                -- Try to find the latest valid vote
                CALL get_latest_vote_for_curator(v_author, v_permlink, v_curator, v_vote_time, v_rshares);

                -- Only process if valid vote exists and rshares > 0
                IF v_rshares > 0 THEN
                    -- Calculate efficiency
                    CALL calculate_efficiency(v_vests, v_total_vests, v_rshares, v_total_rshares, v_efficiency);

                    -- Insert into temp table
                    INSERT IGNORE INTO temp_curation_rewards (
                        author, permlink, curator, reward_time, vote_time,
                        vests, efficiency
                    )
                    VALUES (
                        v_author, v_permlink, v_curator, v_reward_time, v_vote_time,
                        v_vests, v_efficiency
                    );
                END IF;

                SET j = j + 1;
            END WHILE;
        END IF;

        SET i = i + 1;
    END WHILE;

    -- Final insert only if corresponding vote and post exist, and not already inserted
    INSERT INTO curation_rewards (
        author, permlink, curator, reward_time, vote_time,
        vests, efficiency
    )
    SELECT t.*
    FROM temp_curation_rewards t
    JOIN votes v ON v.author = t.author AND v.permlink = t.permlink AND v.voter = t.curator AND v.time = t.vote_time
    JOIN posts p ON p.author = t.author AND p.permlink = t.permlink
    LEFT JOIN curation_rewards cr ON cr.author = t.author AND cr.permlink = t.permlink AND cr.curator = t.curator
    WHERE cr.author IS NULL;

    DROP TEMPORARY TABLE temp_curation_rewards;
    
    CALL update_value_and_steem_for_curation_rewards();
END $$
DELIMITER ;

-- Procedure: insert_beneficiary_rewards
-- Purpose: Inserts rewards paid to post beneficiaries.
-- Notes:
-- - value and steem fields are calculated later.
-- - Only inserts if beneficiary exists in `beneficiaries` table.

DELIMITER $$

DROP PROCEDURE IF EXISTS insert_beneficiary_rewards $$
CREATE PROCEDURE insert_beneficiary_rewards(IN rewards_json JSON)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE j INT DEFAULT 0;
    DECLARE total_posts INT;
    DECLARE total_rewards INT;

    -- Post variables
    DECLARE v_author VARCHAR(16);
    DECLARE v_permlink VARCHAR(256);
    DECLARE v_reward_time DATETIME;

    -- Reward variables
    DECLARE v_beneficiary VARCHAR(16);
    DECLARE v_vests BIGINT;

    -- Create temporary table
    DROP TEMPORARY TABLE IF EXISTS temp_beneficiary_rewards;
    CREATE TEMPORARY TABLE temp_beneficiary_rewards (
        author VARCHAR(16) NOT NULL,
        permlink VARCHAR(256) NOT NULL,
        beneficiary VARCHAR(16) NOT NULL,
        reward_time DATETIME NOT NULL,
        vests BIGINT NOT NULL,
        
        UNIQUE KEY uniq_beneficiary (author, permlink, beneficiary)
    );

    SET total_posts = JSON_LENGTH(rewards_json);

    WHILE i < total_posts DO
        SET j = 0;
        SET v_author = JSON_UNQUOTE(JSON_EXTRACT(rewards_json, CONCAT('$[', i, '].author')));
        SET v_permlink = JSON_UNQUOTE(JSON_EXTRACT(rewards_json, CONCAT('$[', i, '].permlink')));
        SET v_reward_time = JSON_UNQUOTE(JSON_EXTRACT(rewards_json, CONCAT('$[', i, '].reward_time')));

        SET total_rewards = JSON_LENGTH(JSON_EXTRACT(rewards_json, CONCAT('$[', i, '].rewards')));

        WHILE j < total_rewards DO
            SET v_beneficiary = JSON_UNQUOTE(JSON_EXTRACT(rewards_json, CONCAT('$[', i, '].rewards[', j, '].beneficiary')));
            SET v_vests = JSON_UNQUOTE(JSON_EXTRACT(rewards_json, CONCAT('$[', i, '].rewards[', j, '].vests')));

            -- Add all rows for validation via JOIN
            INSERT IGNORE INTO temp_beneficiary_rewards (
                author, permlink, beneficiary, reward_time, vests
            ) VALUES (
                v_author, v_permlink, v_beneficiary, v_reward_time, v_vests
            );

            SET j = j + 1;
        END WHILE;

        SET i = i + 1;
    END WHILE;

    -- Final insert with JOIN-based validation:
    INSERT INTO beneficiary_rewards (author, permlink, beneficiary, reward_time, vests)
    SELECT t.author, t.permlink, t.beneficiary, t.reward_time, t.vests
    FROM temp_beneficiary_rewards t
    JOIN posts p ON p.author = t.author AND p.permlink = t.permlink
    JOIN accounts a ON a.username = t.beneficiary
    JOIN beneficiaries b ON b.author = t.author AND b.permlink = t.permlink AND b.beneficiary = t.beneficiary
    LEFT JOIN beneficiary_rewards br ON br.author = t.author AND br.permlink = t.permlink AND br.beneficiary = t.beneficiary
    WHERE br.author IS NULL;

    DROP TEMPORARY TABLE temp_beneficiary_rewards;

    -- Recalculate value and steem
    CALL update_value_and_steem_for_beneficiary_rewards();
END $$
DELIMITER ;

-- Procedure: insert_pending_post_percentiles_values
-- Purpose: Inserts post total values into pending table for percentile calculation (once a full day has been inserted)

DELIMITER $$

DROP PROCEDURE IF EXISTS insert_pending_post_percentiles_values;
CREATE PROCEDURE insert_pending_post_percentiles_values(IN updates_json JSON)
BEGIN
	DECLARE i INT DEFAULT 0;
    DECLARE total_entries INT;
    
    -- Temporary vars
    DECLARE v_author VARCHAR(16);
    DECLARE v_permlink VARCHAR(256);
    DECLARE v_total_value DECIMAL(10,2);
    DECLARE v_created DATETIME;
    
    -- Get number of entries
    SET total_entries = JSON_LENGTH(updates_json);
    
    DROP TEMPORARY TABLE IF EXISTS temp_pending_post_percentiles;
    CREATE TEMPORARY TABLE temp_pending_post_percentiles (
        author VARCHAR(16),
        permlink VARCHAR(256),
        created DATETIME,
        total_value DECIMAL(10,2),
        
        UNIQUE KEY unique_pending_post (author, permlink)
    );

    WHILE i < total_entries DO
        -- Extract values from JSON
        SET v_author = JSON_UNQUOTE(JSON_EXTRACT(updates_json, CONCAT('$[', i, '].author')));
        SET v_permlink = JSON_UNQUOTE(JSON_EXTRACT(updates_json, CONCAT('$[', i, '].permlink')));
		SET v_created = JSON_EXTRACT(updates_json, CONCAT('$[', i, '].created'));
        SET v_total_value = JSON_EXTRACT(updates_json, CONCAT('$[', i, '].total_value'));
        
        INSERT IGNORE INTO temp_pending_post_percentiles (author, permlink, created, total_value) 
        VALUES (v_author, v_permlink, v_created, v_total_value);

        SET i = i + 1;
    END WHILE;
    
    INSERT INTO pending_post_percentiles (author, permlink, created, total_value)
	SELECT t.author, t.permlink, t.created, t.total_value
	FROM temp_pending_post_percentiles t
	JOIN posts p ON t.author = p.author AND t.permlink = p.permlink
	LEFT JOIN pending_post_percentiles pp
		ON t.author = pp.author AND t.permlink = pp.permlink
	WHERE pp.author IS NULL;
    
    DROP TABLE temp_pending_post_percentiles;
    
    CALL update_post_values_and_percentiles();
END $$

DELIMITER ;