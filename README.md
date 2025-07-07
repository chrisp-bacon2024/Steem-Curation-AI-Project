# SteemSQL Database Documentation

This document outlines the structure, procedures, and triggers used in the **SteemSQL** database for managing and analyzing content, votes, rewards, and historical metrics on the Steem blockchain.

---

## Table of Contents

1. [Tables](#tables)
2. [Stored Procedures](#stored-procedures)
3. [Triggers](#triggers)

---

## Tables

### 1. `steem_price_history`
- **Purpose**: Stores daily historical STEEM prices.
- **Columns**: `date`, `open`, `high`, `low`, `close`, `volume`

### 2. `accounts`
- **Purpose**: Holds metadata for user accounts.
- **Columns**: `username`, `date_created`

### 3. `posts`
- **Purpose**: Metadata for each post.
- **Depends on**: `accounts`
- **Columns**: `author`, `permlink`, `created`, `category`, `total_value`, `percentile`

### 4. `pending_post_percentiles`
- **Purpose**: Posts pending percentile calculation.
- **Columns**: `author`, `permlink`, `total_value`, `created`

### 5. `bodies`
- **Purpose**: Content and structure of post edits.
- **Columns**: Author, permlink, created, title, body, counts (words, sentences, etc.), followers

### 6. `languages`
- **Purpose**: Language metrics for each body version.
- **Columns**: Language code, spelling errors, etc.

### 7. `tags`
- **Purpose**: Tags for each body version.

### 8. `beneficiaries`
- **Purpose**: Declares beneficiaries and their reward percentage.

### 9. `votes`
- **Purpose**: Records user votes on posts.
- **Columns**: `author`, `permlink`, `voter`, `time`, `weight`, `rshares`

### 10. `author_rewards`
- **Purpose**: Reward data for post authors.

### 11. `curation_rewards`
- **Purpose**: Reward data for curators (voters).

### 12. `beneficiary_rewards`
- **Purpose**: Reward data for post beneficiaries.

### 13. `author_percentile_history`
- **Purpose**: Tracks author's performance over time.

### 14. `voter_curation_history`
- **Purpose**: Tracks voter efficiency over time windows.

### 15. `pending_vote_history`
- **Purpose**: Queues votes awaiting history calculation.

### 16. `comments`
- **Purpose**: Tracks post comments.

### 17. `resteems`
- **Purpose**: Tracks resteems (reblogs) of posts.

### 18. `vote_batch_log`
- **Purpose**: Logs batches of vote inserts to trigger processing.

---

## Stored Procedures

Stored procedures are grouped based on function:

### A. **Foundation Insertion**
- `insert_accounts`
- `insert_steem_price_history`

### B. **Content Insertion**
- `insert_posts`
- `insert_bodies`
- `insert_languages`
- `insert_tags`

### C. **Social Insertion**
- `insert_votes`
- `insert_comments`
- `insert_resteems`
- `insert_beneficiaries`

### D. **Reward Insertion**
- `insert_author_rewards`
- `insert_curation_rewards`
- `insert_beneficiary_rewards`

### E. **History Insertion**
- `insert_author_percentile_history`

### F. **Update Procedures**
- `update_value_and_steem_for_author_rewards`
- `update_value_and_steem_for_curation_rewards`
- `update_value_and_steem_for_beneficiary_rewards`
- `update_post_values_and_percentiles`

### G. **Utility Procedures**
- `get_missing_price_dates`
- `get_steem_price_on_date`
- `get_steem_prices`
- `calculate_efficiency_stats`
- `populate_voter_curation_history`

---

## Triggers

### 1. `after_pending_post_percentiles_update`
- **Table**: `pending_post_percentiles`
- **Purpose**: Updates post `total_value` and `percentile`.

### 2. `after_post_insert`
- **Table**: `posts`
- **Purpose**: Automatically records historical author stats across several time windows.

### 3. `after_vote_batch_insert`
- **Table**: `vote_batch_log`
- **Purpose**: Automatically populates `voter_curation_history` from `pending_vote_history`.

---

## Summary

This schema enables detailed tracking and analytics for Steem blockchain activity, including post content, language, tags, rewards, vote efficiency, and beneficiary distribution. It uses:
- Composite keys for data integrity
- Temp tables for safe bulk inserts
- Post-processing triggers for maintaining historical consistency

---

## License
MIT

## Author
Christopher Palmer

---

To contribute or explore more, visit the [GitHub repository](https://github.com/your-repo-here).

