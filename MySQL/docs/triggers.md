# Triggers in SteemSQL

This document describes the triggers used in the **SteemSQL** database. Triggers automate updates to derived data and maintain historical records when new records are inserted or updated.

---

## 1. `after_pending_post_percentiles_update`
- **Table**: `pending_post_percentiles`
- **Timing**: AFTER UPDATE
- **Purpose**: When the `total_value` of a pending post is updated, this trigger calls:
  - `update_post_values_and_percentiles()` to assign a percentile rank
- **Effect**: Populates `posts.total_value` and `posts.percentile` using percent ranking per day.

---

## 2. `after_post_insert`
- **Table**: `posts`
- **Timing**: AFTER INSERT
- **Purpose**: When a new post is created, this trigger:
  - Calls `insert_author_percentile_history()`
  - Computes historical stats for the author over multiple time windows (7, 14, 21, 28, 90 days)

---

## 3. `after_vote_batch_insert`
- **Table**: `vote_batch_log`
- **Timing**: AFTER INSERT
- **Purpose**: After a new vote batch is logged, this trigger:
  - Calls `populate_voter_curation_history()`
  - Populates the `voter_curation_history` table using `pending_vote_history`

---

These triggers ensure that key historical and analytical tables stay synchronized without requiring external orchestration. Each is optimized to handle changes in batch-oriented workflows.

