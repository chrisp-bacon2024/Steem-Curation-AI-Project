USE SteemSQL;

-- Trigger: after_pending_post_percentiles_update
-- Table: pending_post_percentiles
-- Timing: AFTER UPDATE
-- Purpose: When a pending post percentile is updated (e.g., total_value is filled), 
--          this trigger calls `update_post_values_and_percentiles()` to assign percentile ranks
--          to posts whose values are now available and ready. It also sets the value of the post.
--
-- Notes:
--   - The procedure will rank all posts for the relevant dates and update `percentile` and `total_value` in the `posts` table.

DELIMITER $$

DROP TRIGGER IF EXISTS after_pending_post_percentiles_update;
CREATE TRIGGER after_pending_post_percentiles_update
AFTER UPDATE ON pending_post_percentiles
FOR EACH ROW
BEGIN
    CALL update_post_values_and_percentiles();
END $$

DELIMITER ;

-- Trigger: after_post_insert
-- Table: posts
-- Timing: AFTER INSERT
-- Purpose: When a new post is inserted, this trigger records historical percentile data
--          for the author at the time of that post, across several past time windows.
--
-- Calls: insert_author_percentile_history(author, permlink, created, '[7 (1 week), 14 (2 weeks), 21 (3 weeks), 28 (4 weeks), 90 (3 months)]')

DELIMITER $$

DROP TRIGGER IF EXISTS after_post_insert;
CREATE TRIGGER after_post_insert
AFTER INSERT ON posts
FOR EACH ROW
BEGIN
    CALL insert_author_percentile_history(
        NEW.author,
        NEW.permlink,
        NEW.created,
        '[7, 14, 21, 28, 90]'
    );
END $$

DELIMITER ;

-- Trigger: after_vote_batch_insert
-- Table: vote_batch_log
-- Timing: AFTER INSERT
-- Purpose: After a new batch of votes is logged in the `vote_batch_log` table,
--          this trigger initiates the population of historical curation efficiency data
--          for all votes that haven't yet been processed.
--
-- Calls: populate_voter_curation_history()

DELIMITER $$

DROP TRIGGER IF EXISTS after_vote_batch_insert;
CREATE TRIGGER after_vote_batch_insert
AFTER INSERT ON vote_batch_log
FOR EACH ROW
BEGIN
    CALL populate_voter_curation_history();
END $$

DELIMITER ;