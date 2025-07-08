USE SteemSQL;

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