-- Procedure: insert_author_percentile_history
-- Purpose: Inserts historical percentile stats for a post's author based on reward performance over time.
-- Notes:
-- - Can insert multiple time windows per post (e.g., 7, 14, 28 days).
-- - Used to assess author consistency and improvement trends.

DELIMITER $$

DROP PROCEDURE IF EXISTS insert_author_percentile_history $$
CREATE PROCEDURE insert_author_percentile_history(
    IN v_author VARCHAR(16),
    IN v_permlink VARCHAR(256),
    IN v_created DATETIME,
    IN days_array JSON  -- Ex: '[7, 14, 21, 28, 90]'
)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE total INT;
    DECLARE window_days INT;
    DECLARE from_date DATETIME;

    -- Get number of elements in array
    SET total = JSON_LENGTH(days_array);

    WHILE i < total DO
        SET window_days = JSON_EXTRACT(days_array, CONCAT('$[', i, ']'));
        SET from_date = v_created - INTERVAL window_days DAY;

        INSERT INTO author_percentile_history (
            author, permlink, days, total_rewards,
            min_percentile, max_percentile, avg_percentile, med_percentile
        )
        SELECT
            v_author,
            v_permlink,
            window_days,
            COUNT(*),
            IFNULL(MIN(percentile), 0),
            IFNULL(MAX(percentile), 0),
            IFNULL(ROUND(AVG(percentile)), 0),
            IFNULL((
                SELECT percentile
                FROM (
                    SELECT percentile,
                           ROW_NUMBER() OVER (ORDER BY percentile) AS rn,
                           COUNT(*) OVER () AS total_rows
                    FROM posts
                    WHERE author = v_author
                      AND created BETWEEN from_date AND v_created
                      AND percentile IS NOT NULL
                ) ranked
                WHERE rn IN (FLOOR((total_rows + 1)/2), CEIL((total_rows + 1)/2))
                ORDER BY rn
                LIMIT 1
            ), 0)
        FROM posts p
        LEFT JOIN author_percentile_history h
        ON h.author = v_author AND h.permlink=v_permlink AND h.days = window_days
        WHERE author = v_author
          AND created BETWEEN from_date AND v_created
          AND percentile IS NOT NULL
          AND h.author IS NULL;

        SET i = i + 1;
    END WHILE;
END $$
DELIMITER ;

