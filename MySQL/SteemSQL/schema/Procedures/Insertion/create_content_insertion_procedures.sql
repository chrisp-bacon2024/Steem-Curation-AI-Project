USE SteemSQL;

-- Procedure: insert_posts
-- Purpose: Inserts new posts into the `posts` table.
-- Notes:
--   - Expects a JSON array of post objects.
--   - Uses a temporary table to batch parse and validate data.
--   - Ignores posts that already exist (by author + permlink).

DELIMITER $$

DROP PROCEDURE IF EXISTS insert_posts;
CREATE PROCEDURE insert_posts(
    IN post_data JSON  -- Pass an array of JSON objects
)
BEGIN
    -- Declare variables at the start
    DECLARE v_last_inserted DATE;
    DECLARE v_last_processed DATE;
    DECLARE total INT DEFAULT 0;
    DECLARE i INT DEFAULT 0;

    -- Create a temporary table to store the incoming posts with unique constraint
    DROP TEMPORARY TABLE IF EXISTS temp_posts;
    CREATE TEMPORARY TABLE temp_posts (
        author VARCHAR(16) NOT NULL,
        permlink VARCHAR(256) NOT NULL,
        created DATETIME NOT NULL,
        category VARCHAR(24) NOT NULL,
        UNIQUE KEY (author, permlink)
    );

    -- Get the total number of posts from JSON
    SET total = JSON_LENGTH(post_data);

    -- Insert data from JSON input into the temporary table
    WHILE i < total DO
        INSERT IGNORE INTO temp_posts (author, permlink, created, category)
        VALUES (
            JSON_UNQUOTE(JSON_EXTRACT(post_data, CONCAT('$[', i, '].author'))),
            JSON_UNQUOTE(JSON_EXTRACT(post_data, CONCAT('$[', i, '].permlink'))),
            JSON_UNQUOTE(JSON_EXTRACT(post_data, CONCAT('$[', i, '].created'))),
            JSON_UNQUOTE(JSON_EXTRACT(post_data, CONCAT('$[', i, '].category')))
        );
        SET i = i + 1;
    END WHILE;

    -- Insert only new posts that don't exist in the posts table, grouped to avoid any residual duplicates
    INSERT INTO posts (author, permlink, created, category)
    SELECT tmp.author, tmp.permlink, MIN(tmp.created), MIN(tmp.category)
    FROM temp_posts tmp
    LEFT JOIN posts p ON tmp.author = p.author AND tmp.permlink = p.permlink
    WHERE p.author IS NULL
    GROUP BY tmp.author, tmp.permlink;

    -- Drop the temporary table after processing
    DROP TEMPORARY TABLE IF EXISTS temp_posts;
END $$

DELIMITER ;

-- Procedure: insert_bodies
-- Purpose: Inserts post body versions into the `bodies` table.
-- Notes:
--   - Stores edits over time using (author, permlink, created).
--   - Tracks statistics such as word/sentence/paragraph/image count.
--   - Includes author reputation and follower count.

DELIMITER $$

DROP PROCEDURE IF EXISTS insert_bodies $$
CREATE PROCEDURE insert_bodies(
    IN bodies_json JSON
)
BEGIN
    DECLARE total INT DEFAULT 0;
    DECLARE i INT DEFAULT 0;

    -- Create a temporary table for batch inserts
    DROP TEMPORARY TABLE IF EXISTS temp_bodies;
    CREATE TEMPORARY TABLE temp_bodies (
        author VARCHAR(16) NOT NULL,
        permlink VARCHAR(256) NOT NULL,
        created DATETIME NOT NULL,
        day VARCHAR(3) NOT NULL,
        author_reputation TINYINT NOT NULL,
        title VARCHAR(255) NOT NULL,
        body TEXT NOT NULL,
        word_count SMALLINT UNSIGNED NOT NULL,
        sentence_count SMALLINT UNSIGNED NOT NULL,
        paragraph_count SMALLINT UNSIGNED NOT NULL,
        img_count SMALLINT UNSIGNED NOT NULL,
        followers BIGINT UNSIGNED NOT NULL,
        
        UNIQUE KEY uniq_comment (author, permlink, created)
    );

    -- Get the total number of elements in JSON array
    SET total = JSON_LENGTH(bodies_json);

    -- Loop through JSON data and insert into temp table
    WHILE i < total DO
        INSERT IGNORE INTO temp_bodies (
            author, permlink, created, day, author_reputation, title, body, word_count, 
            sentence_count, paragraph_count, img_count, followers
        )
        VALUES (
            JSON_UNQUOTE(JSON_EXTRACT(bodies_json, CONCAT('$[', i, '].author'))),
            JSON_UNQUOTE(JSON_EXTRACT(bodies_json, CONCAT('$[', i, '].permlink'))),
            JSON_UNQUOTE(JSON_EXTRACT(bodies_json, CONCAT('$[', i, '].created'))),
            JSON_UNQUOTE(JSON_EXTRACT(bodies_json, CONCAT('$[', i, '].day'))),
            JSON_UNQUOTE(JSON_EXTRACT(bodies_json, CONCAT('$[', i, '].author_reputation'))),
            JSON_UNQUOTE(JSON_EXTRACT(bodies_json, CONCAT('$[', i, '].title'))),
            JSON_UNQUOTE(JSON_EXTRACT(bodies_json, CONCAT('$[', i, '].body'))),
            JSON_UNQUOTE(JSON_EXTRACT(bodies_json, CONCAT('$[', i, '].word_count'))),
            JSON_UNQUOTE(JSON_EXTRACT(bodies_json, CONCAT('$[', i, '].sentence_count'))),
            JSON_UNQUOTE(JSON_EXTRACT(bodies_json, CONCAT('$[', i, '].paragraph_count'))),
            JSON_UNQUOTE(JSON_EXTRACT(bodies_json, CONCAT('$[', i, '].img_count'))),
            JSON_UNQUOTE(JSON_EXTRACT(bodies_json, CONCAT('$[', i, '].followers')))
        );
        SET i = i + 1;
    END WHILE;

    -- Bulk insert only new records that are not already in `bodies`
    INSERT INTO bodies (
        author, permlink, created, day, author_reputation, title, body, word_count, 
        sentence_count, paragraph_count, img_count, followers
    )
    SELECT tb.author, tb.permlink, tb.created, tb.day, tb.author_reputation, tb.title, tb.body, 
           tb.word_count, tb.sentence_count, tb.paragraph_count, tb.img_count, tb.followers
    FROM temp_bodies tb
    JOIN accounts a ON tb.author = a.username
    JOIN posts p ON tb.author = p.author AND tb.permlink = p.permlink
    LEFT JOIN bodies b ON tb.author = b.author AND tb.permlink = b.permlink
    WHERE b.author IS NULL;

    -- Drop temporary table
    DROP TEMPORARY TABLE IF EXISTS temp_bodies;
END $$

DELIMITER ;

-- Procedure: insert_languages
-- Purpose: Inserts language analysis data for each body version.
-- Notes:
--   - Each language is tracked separately per body (multi-language support).
--   - Tracks spelling error count and counts by structure type.

DELIMITER $$

DROP PROCEDURE IF EXISTS insert_languages;
CREATE PROCEDURE insert_languages(
    IN languages_json JSON
)
BEGIN
    DECLARE total INT DEFAULT 0;
    DECLARE i INT DEFAULT 0;

    -- Create a temporary table for batch inserts
    DROP TEMPORARY TABLE IF EXISTS temp_languages;
    CREATE TEMPORARY TABLE temp_languages (
        author VARCHAR(16) NOT NULL,
        permlink VARCHAR(256) NOT NULL,
        created DATETIME NOT NULL,
        code VARCHAR(15) NOT NULL,
        n_words SMALLINT NOT NULL,
        n_sentences SMALLINT NOT NULL,
        n_paragraphs SMALLINT NOT NULL,
        spelling_errors SMALLINT NOT NULL,
        
        UNIQUE KEY uniq_comment (author, permlink, created, code)
    );

    -- Get the total number of elements in JSON array
    SET total = JSON_LENGTH(languages_json);

    -- Loop through JSON data and insert into temp table
    WHILE i < total DO
        INSERT IGNORE INTO temp_languages (
            author, permlink, created, code, n_words, n_sentences, n_paragraphs, spelling_errors
        )
        VALUES (
            JSON_UNQUOTE(JSON_EXTRACT(languages_json, CONCAT('$[', i, '].author'))),
            JSON_UNQUOTE(JSON_EXTRACT(languages_json, CONCAT('$[', i, '].permlink'))),
            JSON_UNQUOTE(JSON_EXTRACT(languages_json, CONCAT('$[', i, '].created'))),
            JSON_UNQUOTE(JSON_EXTRACT(languages_json, CONCAT('$[', i, '].code'))),
            JSON_UNQUOTE(JSON_EXTRACT(languages_json, CONCAT('$[', i, '].n_words'))),
            JSON_UNQUOTE(JSON_EXTRACT(languages_json, CONCAT('$[', i, '].n_sentences'))),
            JSON_UNQUOTE(JSON_EXTRACT(languages_json, CONCAT('$[', i, '].n_paragraphs'))),
            JSON_UNQUOTE(JSON_EXTRACT(languages_json, CONCAT('$[', i, '].spelling_errors')))
        );
        SET i = i + 1;
    END WHILE;

    -- Bulk insert into the real languages table, ensuring records exist in `bodies`
    INSERT INTO languages (
        author, permlink, created, code, n_words, n_sentences, n_paragraphs, spelling_errors
    )
    SELECT tl.author, tl.permlink, tl.created, tl.code, tl.n_words, tl.n_sentences, 
           tl.n_paragraphs, tl.spelling_errors
    FROM temp_languages tl
    JOIN bodies b ON tl.author = b.author AND tl.permlink = b.permlink AND tl.created = b.created
    LEFT JOIN languages l 
		on l.author = tl.author 
		AND l.permlink = tl.permlink 
		AND l.created = tl.created 
		AND l.code = tl.code
    WHERE l.author IS NULL;

    -- Drop temporary table
    DROP TEMPORARY TABLE IF EXISTS temp_languages;
END $$

DELIMITER ;

-- Procedure: insert_tags
-- Purpose: Inserts tags used in each body version.
-- Notes:
--   - Tags are versioned with each body edit.
--   - Ensures uniqueness using composite key (author, permlink, created, tag).

DELIMITER $$

DROP PROCEDURE IF EXISTS insert_tags $$
CREATE PROCEDURE insert_tags(
    IN tags_json JSON
)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE total INT;

    -- Temporary variables
    DECLARE v_author VARCHAR(16);
    DECLARE v_permlink VARCHAR(256);
    DECLARE v_created DATETIME;
    DECLARE v_tag VARCHAR(24);

    -- Create a temporary table
    DROP TEMPORARY TABLE IF EXISTS temp_tags;
    CREATE TEMPORARY TABLE temp_tags (
        author VARCHAR(16) NOT NULL,
        permlink VARCHAR(256) NOT NULL,
        created DATETIME NOT NULL,
        tag VARCHAR(24) NOT NULL
    );

    -- Get total number of elements in JSON array
    SET total = JSON_LENGTH(tags_json);

    -- Loop through JSON and insert into temp table
    WHILE i < total DO
        SET v_author = JSON_UNQUOTE(JSON_EXTRACT(tags_json, CONCAT('$[', i, '].author')));
        SET v_permlink = JSON_UNQUOTE(JSON_EXTRACT(tags_json, CONCAT('$[', i, '].permlink')));
        SET v_created = JSON_UNQUOTE(JSON_EXTRACT(tags_json, CONCAT('$[', i, '].created')));
        SET v_tag = JSON_UNQUOTE(JSON_EXTRACT(tags_json, CONCAT('$[', i, '].tag')));

        INSERT INTO temp_tags (author, permlink, created, tag)
        VALUES (v_author, v_permlink, v_created, v_tag);

        SET i = i + 1;
    END WHILE;

    -- Insert only tags that match a body and are not already in the tags table
    INSERT INTO tags (author, permlink, created, tag)
    SELECT DISTINCT tt.author, tt.permlink, tt.created, tt.tag
    FROM temp_tags tt
    JOIN bodies b
        ON tt.author = b.author
        AND tt.permlink = b.permlink
        AND tt.created = b.created
    LEFT JOIN tags t
        ON tt.author = t.author
        AND tt.permlink = t.permlink
        AND tt.created = t.created
        AND tt.tag = t.tag
    WHERE t.author IS NULL;

    DROP TEMPORARY TABLE IF EXISTS temp_tags;
END $$

DELIMITER ;