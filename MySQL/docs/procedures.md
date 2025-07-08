# Stored Procedures in SteemSQL

This document describes the stored procedures available in the **SteemSQL** database, grouped by functionality. Each procedure includes its name, purpose, and a summary of key behaviors.

---

## A. Foundation Insertion

### `insert_accounts`

- **Purpose**: Inserts new user accounts.
- **Input**: JSON array of accounts (`username`, `date_created`)
- **Notes**: Skips duplicates; uses temporary table for batch validation.

### `insert_steem_price_history`

- **Purpose**: Inserts or updates STEEM price history.
- **Input**: JSON object (`date`, `open`, `high`, `low`, `close`, `volume`)
- **Notes**: Uses `ON DUPLICATE KEY UPDATE`.

---

## B. Content Insertion

### `insert_posts`

- **Purpose**: Inserts new posts.
- **Input**: JSON array of posts.
- **Notes**: Adds to `pending_post_percentiles`; avoids duplicate inserts.

### `insert_bodies`

- **Purpose**: Adds body versions for posts.
- **Input**: JSON array of body content versions.
- **Notes**: Includes word/image/paragraph stats and reputation.

### `insert_languages`

- **Purpose**: Adds language analysis per post version.
- **Input**: JSON array of language metrics.
- **Notes**: Multi-language support; validated against `bodies`.

### `insert_tags`

- **Purpose**: Stores tags per body version.
- **Input**: JSON array of tags.
- **Notes**: Ensures uniqueness using a composite key.

---

## C. Social Insertion

### `insert_votes`

- **Purpose**: Inserts votes for posts.
- **Input**: JSON array of vote actions.
- **Notes**: Ensures voter/post exist; logs to `vote_batch_log` and `pending_vote_history`.

### `insert_comments`

- **Purpose**: Inserts comment metadata.
- **Input**: JSON array of comments.
- **Notes**: Ties comments to root post only; uses temp table.

### `insert_resteems`

- **Purpose**: Tracks resteems.
- **Input**: JSON array of resteem actions.
- **Notes**: Requires post and account existence.

### `insert_beneficiaries`

- **Purpose**: Adds declared post beneficiaries.
- **Input**: JSON array.
- **Notes**: Validates existence before inserting.

---

## D. Reward Insertion

### `insert_author_rewards`

- **Purpose**: Adds author reward info.
- **Input**: JSON array of author rewards.
- **Notes**: Calls `update_value_and_steem_for_curation_rewards()`.

### `insert_curation_rewards`

- **Purpose**: Adds curation rewards for a post.
- **Input**: JSON structure grouped by post.
- **Notes**: Computes efficiency; validates vote existence. Calls `update_value_and_steem_for_author_rewards()`.

### `insert_beneficiary_rewards`

- **Purpose**: Adds rewards distributed to beneficiaries.
- **Input**: JSON structure grouped by post.
- **Notes**: Calls `update_value_and_steem_for_beneficiary_rewards()`.

---

## E. History Insertion

### `insert_author_percentile_history`

- **Purpose**: Logs percentile stats for author over time windows.
- **Input**: `author`, `permlink`, `created`, JSON array of day intervals.
- **Notes**: Computes count, min, max, avg, median.

---

## F. Update Procedures

### `update_value_and_steem_for_author_rewards`

- **Purpose**: Computes value and STEEM from vests.
- **Depends on**: `steem_price_history`, `posts`, `curation_rewards`

### `update_value_and_steem_for_curation_rewards`

- **Purpose**: Calculates curation reward values.
- **Depends on**: `posts`, `curation_rewards`, `steem_price_history`

### `update_value_and_steem_for_beneficiary_rewards`

- **Purpose**: Calculates value for beneficiary rewards.
- **Depends on**: `posts`, `curation_rewards`, `steem_price_history`

### `update_pending_post_percentiles_values`

- **Purpose**: update the `total_value` field in the `pending_post_percentiles` table as well as the `posts` table. This update will trigger the `update_post_values_and_percentiles` procedure to update the `percentile` value in the posts table if the whole day has been inserted.

### `update_post_values_and_percentiles`

- **Purpose**: Fills in `total_value` and `percentile` in `posts` from `pending_post_percentiles` Once all of the posts from a given day have been inserted.
- **Notes**: Uses `PERCENT_RANK()` over daily posts.

---

## G. Utility Procedures

### `get_missing_price_dates`

- **Purpose**: Finds reward dates missing from `steem_price_history`.

### `get_steem_price_on_date`

- **Purpose**: Gets STEEM price for a specific date.

### `get_steem_prices`

- **Purpose**: Returns full STEEM price history.

### `calculate_efficiency_stats`

- **Purpose**: Calculates min, max, avg, median efficiency stats over a time window for a voter.
- **Input**: `voter`, `timestamp`, `days`
- **Output**: Stats via OUT parameters

### `populate_voter_curation_history`

- **Purpose**: Fills in efficiency history from `pending_vote_history`.
- **Notes**: Uses temp tables and multiple windows (7, 14, 21, 28, 60, 90 days)

---

Each procedure is designed for scalable batch processing and integrity-safe inserts using temp tables and JSON input formats.

