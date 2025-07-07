# Tables in SteemSQL

This document provides detailed descriptions of all tables in the **SteemSQL** database, including their purposes, key columns, and foreign key relationships.

---

## 1. `steem_price_history`
- **Purpose**: Stores historical daily STEEM prices.
- **Columns**: `date`, `open`, `high`, `low`, `close`, `volume`
- **Primary Key**: `date`

## 2. `accounts`
- **Purpose**: Metadata for user accounts.
- **Columns**: `username`, `date_created`
- **Primary Key**: `username`

## 3. `posts`
- **Purpose**: Stores immutable metadata for each post.
- **Columns**: `author`, `permlink`, `created`, `category`, `total_value`, `percentile`
- **Primary Key**: (`author`, `permlink`)
- **Foreign Keys**:
  - `author` → `accounts(username)`

## 4. `pending_post_percentiles`
- **Purpose**: Tracks posts pending percentile/value calculation.
- **Columns**: `author`, `permlink`, `created`, `total_value`
- **Primary Key**: (`author`, `permlink`)
- **Foreign Keys**:
  - (`author`, `permlink`) → `posts(author, permlink)`

## 5. `bodies`
- **Purpose**: Stores post content and structural stats.
- **Columns**: `author`, `permlink`, `created`, `day`, `author_reputation`, `title`, `body`, `word_count`, `sentence_count`, `paragraph_count`, `img_count`, `followers`
- **Primary Key**: (`author`, `permlink`, `created`)
- **Foreign Keys**:
  - `author` → `accounts(username)`
  - (`author`, `permlink`) → `posts(author, permlink)`

## 6. `languages`
- **Purpose**: Stores language analysis of each post version.
- **Columns**: `author`, `permlink`, `created`, `code`, `n_words`, `n_sentences`, `n_paragraphs`, `spelling_errors`
- **Primary Key**: (`author`, `permlink`, `created`, `code`)
- **Foreign Keys**:
  - (`author`, `permlink`, `created`) → `bodies(author, permlink, created)`

## 7. `tags`
- **Purpose**: Tags applied to each version of a post.
- **Columns**: `author`, `permlink`, `created`, `tag`
- **Primary Key**: (`author`, `permlink`, `created`, `tag`)
- **Foreign Keys**:
  - (`author`, `permlink`, `created`) → `bodies(author, permlink, created)`

## 8. `beneficiaries`
- **Purpose**: Lists reward-sharing beneficiaries for a post.
- **Columns**: `author`, `permlink`, `beneficiary`, `pct`
- **Primary Key**: (`author`, `permlink`, `beneficiary`)
- **Foreign Keys**:
  - (`author`, `permlink`) → `posts(author, permlink)`
  - `beneficiary` → `accounts(username)`

## 9. `votes`
- **Purpose**: Stores vote details on posts.
- **Columns**: `author`, `permlink`, `voter`, `time`, `weight`, `rshares`
- **Primary Key**: (`author`, `permlink`, `voter`, `time`)
- **Foreign Keys**:
  - (`author`, `permlink`) → `posts(author, permlink)`
  - `voter` → `accounts(username)`

## 10. `author_rewards`
- **Purpose**: Author rewards associated with a post.
- **Columns**: `author`, `permlink`, `reward_time`, `vests`, `value`, `steem`
- **Primary Key**: (`author`, `permlink`)
- **Foreign Keys**:
  - (`author`, `permlink`) → `posts(author, permlink)`

## 11. `curation_rewards`
- **Purpose**: Curation rewards linked to vote actions.
- **Columns**: `author`, `permlink`, `curator`, `reward_time`, `vote_time`, `vests`, `efficiency`, `value`, `steem`
- **Primary Key**: (`author`, `permlink`, `curator`)
- **Foreign Keys**:
  - (`author`, `permlink`) → `posts(author, permlink)`
  - `curator` → `accounts(username)`
  - (`author`, `permlink`, `curator`, `vote_time`) → `votes(author, permlink, voter, time)`

## 12. `beneficiary_rewards`
- **Purpose**: Rewards paid to post beneficiaries.
- **Columns**: `author`, `permlink`, `beneficiary`, `reward_time`, `vests`, `value`, `steem`
- **Primary Key**: (`author`, `permlink`, `beneficiary`)
- **Foreign Keys**:
  - (`author`, `permlink`, `beneficiary`) → `beneficiaries(author, permlink, beneficiary)`
  - (`author`, `permlink`) → `posts(author, permlink)`
  - `beneficiary` → `accounts(username)`

## 13. `author_percentile_history`
- **Purpose**: Historical percentile stats for post authors.
- **Columns**: `author`, `permlink`, `days`, `total_rewards`, `min_percentile`, `max_percentile`, `avg_percentile`, `med_percentile`
- **Primary Key**: (`author`, `permlink`, `days`)
- **Foreign Keys**:
  - (`author`, `permlink`) → `posts(author, permlink)`

## 14. `voter_curation_history`
- **Purpose**: Historical stats for curator efficiency.
- **Columns**: `author`, `permlink`, `voter`, `days`, `total_rewards`, `min_efficiency`, `max_efficiency`, `avg_efficiency`, `med_efficiency`
- **Primary Key**: (`author`, `permlink`, `voter`, `days`)
- **Foreign Keys**:
  - (`author`, `permlink`) → `posts(author, permlink)`

## 15. `pending_vote_history`
- **Purpose**: Temporary list of votes pending efficiency analysis.
- **Columns**: `author`, `permlink`, `voter`
- **Primary Key**: (`author`, `permlink`, `voter`)
- **Standalone** (no FKs to allow pre-validation)

## 16. `comments`
- **Purpose**: Metadata for post comments.
- **Columns**: `commenter`, `permlink`, `parent_author`, `parent_permlink`, `root_author`, `root_permlink`, `time`, `commenter_reputation`
- **Primary Key**: (`commenter`, `permlink`)
- **Foreign Keys**:
  - (`root_author`, `root_permlink`) → `posts(author, permlink)`

## 17. `resteems`
- **Purpose**: Tracks resteems (reblogs).
- **Columns**: `author`, `permlink`, `resteemed_by`, `time`, `followers`
- **Primary Key**: (`author`, `permlink`, `resteemed_by`)
- **Foreign Keys**:
  - (`author`, `permlink`) → `posts(author, permlink)`
  - `resteemed_by` → `accounts(username)`

## 18. `vote_batch_log`
- **Purpose**: Logs vote batch inserts to trigger downstream processing.
- **Columns**: `id`, `inserted_at`
- **Primary Key**: `id`
- **Standalone**

---

This schema uses foreign keys extensively to ensure referential integrity and enable complex analytic joins across post, reward, vote, and user activity data.

