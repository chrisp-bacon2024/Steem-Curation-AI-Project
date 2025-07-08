USE SteemSQL;

-- Procedure: delete_2_yr_old_records
-- Purpose: Delete posts from database that are older than 2 years old (paired with event scheduler)

DELIMITER $$

CREATE PROCEDURE delete_2_yr_old_records()
BEGIN
  DELETE FROM posts
  WHERE created < NOW() - INTERVAL 2 YEAR;
END $$

DELIMITER ;