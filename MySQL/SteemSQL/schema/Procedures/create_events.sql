USE SteemSQL;

-- Make sure event schedulre is on! You can permanently enable in cnf/ini file
SET GLOBAL event_scheduler = ON;

DROP EVENT IF EXISTS delete_2_yr_old_records;
CREATE EVENT delete_2_yr_old_records
ON SCHEDULE EVERY 1 DAY
DO
	CALL delete_2_yr_old_records();
