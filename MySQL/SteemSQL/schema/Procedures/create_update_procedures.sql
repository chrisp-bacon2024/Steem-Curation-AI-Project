USE SteemSQL;

-- Procedure: update_author_rewards_value_and_steem
-- Purpose: Calculates and updates `value` and `steem` in the `author_rewards` table based on vests and price.
-- Depends on: steem_price_history

DELIMITER $$

DROP PROCEDURE IF EXISTS update_value_and_steem_for_author_rewards $$
CREATE PROCEDURE update_value_and_steem_for_author_rewards()
BEGIN
    SET @original_safe_updates := @@SQL_SAFE_UPDATES;
    SET SQL_SAFE_UPDATES = 0;

    UPDATE author_rewards ar
    JOIN posts p ON p.author = ar.author AND p.permlink = ar.permlink AND p.total_value IS NOT NULL
    JOIN steem_price_history sph ON DATE(ar.reward_time) = sph.date
    JOIN (
        SELECT author, permlink, SUM(vests) * 2 AS total_vests
        FROM curation_rewards
        GROUP BY author, permlink
    ) totals ON totals.author = ar.author AND totals.permlink = ar.permlink
    SET
        ar.value = (ar.vests / totals.total_vests) * p.total_value,
        ar.steem = ROUND((ar.vests / (totals.total_vests * 2.0)) * p.total_value / sph.close, 3)
    WHERE
        (ar.value IS NULL OR ar.steem IS NULL)
        AND ar.author IS NOT NULL AND ar.permlink IS NOT NULL;

    SET SQL_SAFE_UPDATES = @original_safe_updates;
END $$
DELIMITER ;

-- Procedure: update_curation_rewards_value_and_steem
-- Purpose: Calculates and updates `value` and `steem` in the `curation_rewards` table based on vests and price.

DELIMITER $$

DROP PROCEDURE IF EXISTS update_value_and_steem_for_curation_rewards $$
CREATE PROCEDURE update_value_and_steem_for_curation_rewards()
BEGIN
    -- Turn off safe updates temporarily
    SET @original_safe_updates := @@SQL_SAFE_UPDATES;
    SET SQL_SAFE_UPDATES = 0;

    -- Perform safe update
    UPDATE curation_rewards cr
    JOIN posts p 
        ON p.author = cr.author AND p.permlink = cr.permlink AND p.total_value IS NOT NULL
    JOIN steem_price_history sph 
        ON DATE(cr.reward_time) = sph.date
    JOIN (
        SELECT author, permlink, SUM(vests) AS total_vests
        FROM curation_rewards
        GROUP BY author, permlink
    ) totals 
        ON cr.author = totals.author AND cr.permlink = totals.permlink
    SET
        cr.value = (cr.vests / (totals.total_vests * 2.0)) * p.total_value,
        cr.steem = ROUND((cr.vests / (totals.total_vests * 2.0)) * p.total_value / sph.close, 3)
    WHERE
        cr.value IS NULL OR cr.steem IS NULL;

    -- Restore safe updates to original value
    SET SQL_SAFE_UPDATES = @original_safe_updates;
END $$
DELIMITER ;

-- Procedure: update_beneficiary_rewards_value_and_steem
-- Purpose: Calculates and updates `value` and `steem` in the `beneficiary_rewards` table based on vests and price.

DELIMITER $$

DROP PROCEDURE IF EXISTS update_value_and_steem_for_beneficiary_rewards $$
CREATE PROCEDURE update_value_and_steem_for_beneficiary_rewards()
BEGIN
    SET @original_safe_updates := @@SQL_SAFE_UPDATES;
    SET SQL_SAFE_UPDATES = 0;

    UPDATE beneficiary_rewards br
    JOIN posts p ON p.author = br.author AND p.permlink = br.permlink AND p.total_value IS NOT NULL
    JOIN steem_price_history sph ON DATE(br.reward_time) = sph.date
    JOIN (
        SELECT author, permlink, SUM(vests) * 2 AS total_vests
        FROM curation_rewards
        GROUP BY author, permlink
    ) totals ON totals.author = br.author AND totals.permlink = br.permlink
    SET
        br.value = (br.vests / totals.total_vests) * p.total_value,
        br.steem = ROUND((br.vests / (totals.total_vests * 2.0)) * p.total_value / sph.close, 3)
    WHERE
        (br.value IS NULL OR br.steem IS NULL)
        AND br.author IS NOT NULL AND br.permlink IS NOT NULL;

    SET SQL_SAFE_UPDATES = @original_safe_updates;
END $$
DELIMITER ;

-- Procedure: update_pending_post_percentiles_values
-- Purpose: Updates the total_value field of the pending_post_percentiles table

DELIMITER $$

-- Procedure: update_post_values_and_percentiles
-- Purpose: Fills in `total_value` and `percentile` in the `posts` table using values from `pending_post_percentiles` and rank logic.

DELIMITER $$

DROP PROCEDURE IF EXISTS update_post_values_and_percentiles;
CREATE PROCEDURE update_post_values_and_percentiles ()
BEGIN
    DECLARE min_created DATE;
    DECLARE max_created DATE;

    SELECT 
        DATE(MIN(created)),
        DATE(MAX(created))
    INTO 
        min_created, 
        max_created
    FROM pending_post_percentiles p;

    IF min_created < max_created THEN
		-- Create a temporary table for collecting all posts
        DROP TEMPORARY TABLE IF EXISTS temp_post_joined;
        CREATE TEMPORARY TABLE temp_post_joined AS
		SELECT 
            p.author,
            p.permlink,
            p.created,
            IFNULL(ppp.total_value, 0) AS total_value -- Posts not in pending did not pay out and are therefore 0 dollars
		FROM posts p
        LEFT JOIN pending_post_percentiles ppp
			ON p.author = ppp.author AND p.permlink = ppp.permlink
		WHERE DATE(p.created) >= min_created AND DATE(p.created) < max_created;
    
        -- Update all percentiles for posts on each date from min_created to max_created - 1
        UPDATE posts p
        JOIN (
            SELECT author, permlink, total_value, FLOOR(PERCENT_RANK() OVER (PARTITION BY DATE(created) ORDER BY total_value) * 100) AS percentile
            FROM temp_post_joined
            WHERE DATE(created) >= min_created AND DATE(created) < max_created
        ) ranked ON p.author = ranked.author AND p.permlink = ranked.permlink
        SET p.total_value = ranked.total_value, p.percentile = ranked.percentile;
        
        -- Delete processed rows from pending_post_percentiles
        DELETE FROM pending_post_percentiles
        WHERE DATE(created) >= min_created AND DATE(created) < max_created;
    END IF;
END $$
DELIMITER ;
