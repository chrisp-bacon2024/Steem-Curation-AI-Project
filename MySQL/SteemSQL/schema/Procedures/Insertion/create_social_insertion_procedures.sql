USE SteemSQL;

-- Procedure: insert_votes
-- Purpose: Inserts a batch of votes into the votes table.
-- Notes:
-- - Avoids inserting duplicates using a temporary staging table.
-- - Validates that the post and voter exist.

DELIMITER $$

DROP PROCEDURE IF EXISTS insert_votes $$
CREATE PROCEDURE insert_votes(IN votes_json JSON)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE total INT;

    -- Variables for each vote
    DECLARE v_author VARCHAR(16);
    DECLARE v_permlink VARCHAR(256);
    DECLARE v_voter VARCHAR(16);
    DECLARE v_time DATETIME;
    DECLARE v_weight TINYINT;
    DECLARE v_rshares BIGINT;

    -- Get total number of votes
    SET total = JSON_LENGTH(votes_json);

    -- Temporary table to store incoming vote data
    DROP TEMPORARY TABLE IF EXISTS temp_votes;
    CREATE TEMPORARY TABLE temp_votes (
        author VARCHAR(16) NOT NULL,
        permlink VARCHAR(256) NOT NULL,
        voter VARCHAR(16) NOT NULL,
        time DATETIME NOT NULL,
        weight TINYINT,
        rshares BIGINT,
        
        UNIQUE KEY uniq_comment (author, permlink, voter, time)
    );

    -- Loop to extract and insert each vote into temp_votes
    WHILE i < total DO
        SET v_author = JSON_UNQUOTE(JSON_EXTRACT(votes_json, CONCAT('$[', i, '].author')));
        SET v_permlink = JSON_UNQUOTE(JSON_EXTRACT(votes_json, CONCAT('$[', i, '].permlink')));
        SET v_voter = JSON_UNQUOTE(JSON_EXTRACT(votes_json, CONCAT('$[', i, '].voter')));
        SET v_time = JSON_UNQUOTE(JSON_EXTRACT(votes_json, CONCAT('$[', i, '].time')));
        SET v_weight = JSON_UNQUOTE(JSON_EXTRACT(votes_json, CONCAT('$[', i, '].weight')));
        SET v_rshares = JSON_UNQUOTE(JSON_EXTRACT(votes_json, CONCAT('$[', i, '].rshares')));

        INSERT IGNORE INTO temp_votes (author, permlink, voter, time, weight, rshares)
        VALUES (v_author, v_permlink, v_voter, v_time, v_weight, v_rshares);

        SET i = i + 1;
    END WHILE;

    -- Final insert: only include votes where post and voter exist
    INSERT INTO votes (author, permlink, voter, time, weight, rshares)
    SELECT tv.author, tv.permlink, tv.voter, tv.time, tv.weight, tv.rshares
    FROM temp_votes tv
    JOIN posts p ON p.author = tv.author AND p.permlink = tv.permlink
    JOIN accounts a ON a.username = tv.voter
    LEFT JOIN votes v 
		ON tv.author = v.author
        AND tv.permlink = v.permlink
        AND tv.voter = v.voter
        AND tv.time = v.time
	WHERE v.author IS NULL;
    INSERT INTO pending_vote_history (author, permlink, voter)
    SELECT DISTINCT tv.author, tv.permlink, tv.voter
    FROM temp_votes tv
    JOIN posts p ON p.author = tv.author AND p.permlink = tv.permlink
    JOIN accounts a ON a.username = tv.voter
    LEFT JOIN pending_vote_history pvh 
		ON tv.author = pvh.author
        AND tv.permlink = pvh.permlink
        AND tv.voter = pvh.voter
	WHERE pvh.author IS NULL;
    
    INSERT INTO vote_batch_log () VALUES (); -- Logs the insert, and triggers voter_curation_history inserts
    DROP TEMPORARY TABLE IF EXISTS temp_votes;
END $$
DELIMITER ;

-- Procedure: insert_comments
-- Purpose: Inserts a batch of comments into the comments table.
-- Notes:
-- - Assumes root post exists.
-- - Deduplicates using a temporary table.

DELIMITER $$

DROP PROCEDURE IF EXISTS insert_comments $$
CREATE PROCEDURE insert_comments(IN comments_json JSON)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE total_entries INT;

    -- Variables for each comment
    DECLARE v_commenter VARCHAR(16);
    DECLARE v_permlink VARCHAR(256);
    DECLARE v_parent_author VARCHAR(16);
    DECLARE v_parent_permlink VARCHAR(256);
    DECLARE v_root_author VARCHAR(16);
    DECLARE v_root_permlink VARCHAR(256);
    DECLARE v_time DATETIME;
    DECLARE v_commenter_reputation TINYINT;

    -- Create temporary table for batch insert
    DROP TEMPORARY TABLE IF EXISTS temp_comments;
    CREATE TEMPORARY TABLE temp_comments (
        commenter VARCHAR(16) NOT NULL,
        permlink VARCHAR(256) NOT NULL,
        parent_author VARCHAR(16),
        parent_permlink VARCHAR(256),
        root_author VARCHAR(16) NOT NULL,
        root_permlink VARCHAR(256) NOT NULL,
        time DATETIME NOT NULL,
        commenter_reputation TINYINT NOT NULL,
        
        UNIQUE KEY uniq_comment (commenter, permlink)
    );

    -- Get total number of comments to process
    SET total_entries = JSON_LENGTH(comments_json);

    WHILE i < total_entries DO
        -- Extract comment details from JSON
        SET v_commenter = JSON_UNQUOTE(JSON_EXTRACT(comments_json, CONCAT('$[', i, '].commenter')));
        SET v_permlink = JSON_UNQUOTE(JSON_EXTRACT(comments_json, CONCAT('$[', i, '].permlink')));
        SET v_parent_author = JSON_UNQUOTE(JSON_EXTRACT(comments_json, CONCAT('$[', i, '].parent_author')));
        SET v_parent_permlink = JSON_UNQUOTE(JSON_EXTRACT(comments_json, CONCAT('$[', i, '].parent_permlink')));
        SET v_root_author = JSON_UNQUOTE(JSON_EXTRACT(comments_json, CONCAT('$[', i, '].root_author')));
        SET v_root_permlink = JSON_UNQUOTE(JSON_EXTRACT(comments_json, CONCAT('$[', i, '].root_permlink')));
        SET v_time = JSON_UNQUOTE(JSON_EXTRACT(comments_json, CONCAT('$[', i, '].time')));
        SET v_commenter_reputation = JSON_UNQUOTE(JSON_EXTRACT(comments_json, CONCAT('$[', i, '].commenter_reputation')));

        -- Convert empty strings to NULL for parent
        IF v_parent_author = '' THEN SET v_parent_author = NULL; END IF;
        IF v_parent_permlink = '' THEN SET v_parent_permlink = NULL; END IF;

        INSERT IGNORE INTO temp_comments (
            commenter, permlink, parent_author, parent_permlink,
            root_author, root_permlink, time, commenter_reputation
        )
        VALUES (
            v_commenter, v_permlink, v_parent_author, v_parent_permlink,
            v_root_author, v_root_permlink, v_time, v_commenter_reputation
        );

        SET i = i + 1;
    END WHILE;

    -- Insert only valid comments
    INSERT INTO comments (
        commenter, permlink, parent_author, parent_permlink,
        root_author, root_permlink, time, commenter_reputation
    )
    SELECT tc.commenter, tc.permlink, tc.parent_author, tc.parent_permlink,
           tc.root_author, tc.root_permlink, tc.time, tc.commenter_reputation
    FROM temp_comments tc
    JOIN accounts a ON a.username = tc.commenter
    JOIN posts p_root ON p_root.author = tc.root_author AND p_root.permlink = tc.root_permlink
    LEFT JOIN comments c ON tc.commenter = c.commenter AND tc.permlink = c.permlink
    WHERE c.commenter IS NULL;

    DROP TEMPORARY TABLE temp_comments;

END $$
DELIMITER ;

-- Procedure: insert_resteems
-- Purpose: Inserts resteems (reblogs) for a given post.
-- Notes:
-- - Ensures uniqueness by checking existing table entries.

DELIMITER $$

DROP PROCEDURE IF EXISTS insert_resteems $$
CREATE PROCEDURE insert_resteems(IN resteems_json JSON)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE total_entries INT;

    -- Variables for each resteem
    DECLARE v_author VARCHAR(16);
    DECLARE v_permlink VARCHAR(256);
    DECLARE v_resteemed_by VARCHAR(16);
    DECLARE v_followers BIGINT;
    DECLARE v_time DATETIME;

    -- Create temporary table for batch insert
    DROP TEMPORARY TABLE IF EXISTS temp_resteems;
    CREATE TEMPORARY TABLE temp_resteems (
        author VARCHAR(16) NOT NULL,
        permlink VARCHAR(256) NOT NULL,
        resteemed_by VARCHAR(16) NOT NULL,
        followers BIGINT NOT NULL,
        time DATETIME NOT NULL,
        
        UNIQUE KEY uniq_comment (author, permlink, resteemed_by)
    );

    -- Get total number of resteems to process
    SET total_entries = JSON_LENGTH(resteems_json);

    WHILE i < total_entries DO
        -- Extract resteem details from JSON
        SET v_author = JSON_UNQUOTE(JSON_EXTRACT(resteems_json, CONCAT('$[', i, '].author')));
        SET v_permlink = JSON_UNQUOTE(JSON_EXTRACT(resteems_json, CONCAT('$[', i, '].permlink')));
        SET v_resteemed_by = JSON_UNQUOTE(JSON_EXTRACT(resteems_json, CONCAT('$[', i, '].resteemed_by')));
        SET v_followers = JSON_UNQUOTE(JSON_EXTRACT(resteems_json, CONCAT('$[', i, '].followers')));
        SET v_time = JSON_UNQUOTE(JSON_EXTRACT(resteems_json, CONCAT('$[', i, '].time')));

        -- Insert into temporary table (validation deferred to main insert)
        INSERT IGNORE INTO temp_resteems (author, permlink, resteemed_by, followers, time)
        VALUES (v_author, v_permlink, v_resteemed_by, v_followers, v_time);

        SET i = i + 1;
    END WHILE;

    -- Final insert: only valid resteems where post and account exist, and no duplicate
    INSERT INTO resteems (author, permlink, resteemed_by, followers, time)
    SELECT t.author, t.permlink, t.resteemed_by, t.followers, t.time
    FROM temp_resteems t
    JOIN posts p ON p.author = t.author AND p.permlink = t.permlink
    JOIN accounts a ON a.username = t.resteemed_by
    LEFT JOIN resteems r ON r.author = t.author AND r.permlink = t.permlink AND r.resteemed_by = t.resteemed_by
    WHERE r.author IS NULL;

    DROP TEMPORARY TABLE temp_resteems;

END $$
DELIMITER ;

-- Procedure: insert_beneficiaries
-- Purpose: Inserts post beneficiaries (if any) into the beneficiaries table.
-- Notes:
-- - Uses JSON input, deduplicates with temp table.

DELIMITER $$

DROP PROCEDURE IF EXISTS insert_beneficiaries;
CREATE PROCEDURE insert_beneficiaries(IN beneficiaries_json JSON)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE total_entries INT;

    -- Variables for each beneficiary
    DECLARE v_author VARCHAR(16);
    DECLARE v_permlink VARCHAR(256);
    DECLARE v_beneficiary VARCHAR(16);
    DECLARE v_pct TINYINT UNSIGNED;

    -- Create temporary table for batch insert
    DROP TEMPORARY TABLE IF EXISTS temp_beneficiaries;
    CREATE TEMPORARY TABLE temp_beneficiaries (
        author VARCHAR(16) NOT NULL,
        permlink VARCHAR(256) NOT NULL,
        beneficiary VARCHAR(16) NOT NULL,
        pct TINYINT UNSIGNED NOT NULL,
        
        UNIQUE KEY uniq_comment (author, permlink, beneficiary)
    );

    -- Get total number of beneficiaries to process
    SET total_entries = JSON_LENGTH(beneficiaries_json);

    WHILE i < total_entries DO
        -- Extract beneficiary details from JSON
        SET v_author = JSON_UNQUOTE(JSON_EXTRACT(beneficiaries_json, CONCAT('$[', i, '].author')));
        SET v_permlink = JSON_UNQUOTE(JSON_EXTRACT(beneficiaries_json, CONCAT('$[', i, '].permlink')));
        SET v_beneficiary = JSON_UNQUOTE(JSON_EXTRACT(beneficiaries_json, CONCAT('$[', i, '].beneficiary')));
        SET v_pct = JSON_UNQUOTE(JSON_EXTRACT(beneficiaries_json, CONCAT('$[', i, '].pct')));

        -- Insert into temporary table for batch insert
        INSERT IGNORE INTO temp_beneficiaries (author, permlink, beneficiary, pct)
        VALUES (v_author, v_permlink, v_beneficiary, v_pct);

        SET i = i + 1;
    END WHILE;

    -- Bulk insert all beneficiaries at once
    INSERT INTO beneficiaries (author, permlink, beneficiary, pct)
    SELECT tb.author, tb.permlink, tb.beneficiary, tb.pct FROM temp_beneficiaries tb
    JOIN accounts a
		ON a.username = tb.beneficiary
    JOIN posts p
		ON tb.author = p.author
		AND tb.permlink = p.permlink
    LEFT JOIN beneficiaries b
		ON tb.author = b.author
        AND tb.permlink = b.permlink
        AND tb.beneficiary = b.beneficiary
	WHERE b.author IS NULL;

    -- Drop the temporary table
    DROP TEMPORARY TABLE temp_beneficiaries;

END $$

DELIMITER ;