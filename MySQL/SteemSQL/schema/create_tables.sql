USE SteemSQL;

-- Table: steem_price_history
-- Purpose: Stores historical Steem prices for converting reward values.

DROP TABLE IF EXISTS steem_price_history;
CREATE TABLE steem_price_history (
    date DATE NOT NULL,
    open DECIMAL(10,4) NOT NULL,
    high DECIMAL(10,4) NOT NULL,
    low DECIMAL(10,4) NOT NULL,
    close DECIMAL(10,4) NOT NULL,
    volume BIGINT NOT NULL,

    PRIMARY KEY (date)
);

-- Table: accounts
-- Purpose: Stores account metadata for all users.
-- Required by: posts, votes, rewards, comments, resteems, beneficiaries

DROP TABLE IF EXISTS accounts;
CREATE TABLE accounts (
	username VARCHAR(16) PRIMARY KEY,
    date_created DATETIME
);

-- Table: posts
-- Table: posts
-- Purpose: Stores immutable metadata for each post (author, created time, category).
-- Used in: rewards, votes, bodies, resteems, comments
-- Depends on: accounts

DROP TABLE IF EXISTS posts;
CREATE TABLE posts (
    author VARCHAR(16) NOT NULL,
    permlink VARCHAR(256) NOT NULL,
    created DATETIME NOT NULL,
    category VARCHAR(24) NOT NULL,
    total_value DECIMAL(7,2) DEFAULT NULL,
    percentile TINYINT UNSIGNED DEFAULT NULL,
    PRIMARY KEY (author, permlink),
    FOREIGN KEY (author) REFERENCES accounts(username) ON DELETE CASCADE ON UPDATE CASCADE
);

-- Table: pending_post_percentiles
-- Purpose: Tracks posts that have not yet had their total_value and percentile computed.
-- Used in: percentile calculation pipeline
-- Depends on: posts

DROP TABLE IF EXISTS pending_post_percentiles;
CREATE TABLE pending_post_percentiles(
	author VARCHAR(16),
    permlink VARCHAR(256),
    total_value DECIMAL(7,2) DEFAULT 0.00,
    created DATETIME NOT NULL,
    
    PRIMARY KEY (author, permlink),
    FOREIGN KEY (author, permlink) REFERENCES posts(author, permlink)
);

-- Table: bodies
-- Purpose: Stores all versions of a post's content. Each edit is a new row.
-- Used in: languages, tags
-- Depends on: posts, accounts

DROP TABLE IF EXISTS bodies;
CREATE TABLE bodies (
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
    followers BIGINT UNSIGNED,
    
    -- Define composite primary key (author, permlink, created)
    PRIMARY KEY (author, permlink, created),

    -- Foreign key references
    FOREIGN KEY (author) REFERENCES accounts(username) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (author, permlink) REFERENCES posts(author, permlink) ON DELETE CASCADE ON UPDATE CASCADE
);

-- Table: languages
-- Purpose: Stores language metrics (word count, spelling errors, etc.) for each body version.
-- Depends on: bodies

DROP TABLE IF EXISTS languages;
CREATE TABLE languages (
    author VARCHAR(16) NOT NULL,
    permlink VARCHAR(256) NOT NULL,
    created DATETIME NOT NULL,
    code VARCHAR(15) NOT NULL,
    n_words SMALLINT NOT NULL,
    n_sentences SMALLINT NOT NULL,
    n_paragraphs SMALLINT NOT NULL,
    spelling_errors SMALLINT NOT NULL,

    -- Define composite primary key
    PRIMARY KEY (author, permlink, created, code),

    -- Foreign key references to ensure valid bodies exist
    FOREIGN KEY (author, permlink, created) 
        REFERENCES bodies(author, permlink, created) ON DELETE CASCADE ON UPDATE CASCADE
);

-- Table: tags
-- Purpose: Stores tags applied to each version of a post body.
-- Notes: Tags can change per body version.
-- Depends on: bodies

USE SteemSQL;

USE SteemSQL;

DROP TABLE IF EXISTS tags;
CREATE TABLE tags (
    author VARCHAR(16) NOT NULL,
    permlink VARCHAR(256) NOT NULL,
    created DATETIME NOT NULL,
    tag VARCHAR(24) NOT NULL,

    -- Define composite primary key to ensure uniqueness
    PRIMARY KEY (author, permlink, created, tag),

    -- Foreign key reference to ensure valid bodies exist
    FOREIGN KEY (author, permlink, created) 
        REFERENCES bodies(author, permlink, created) ON DELETE CASCADE ON UPDATE CASCADE
);

-- Table: beneficiaries
-- Purpose: Declares the beneficiaries of a post and their reward percentages.
-- Used in: validating beneficiary reward payouts.
-- Depends on: posts, accounts

DROP TABLE IF EXISTS beneficiaries;
CREATE TABLE beneficiaries(
	author VARCHAR(16),
    permlink VARCHAR(256),
    beneficiary VARCHAR(16),
    pct TINYINT UNSIGNED NOT NULL,
    
    PRIMARY KEY (author, permlink, beneficiary),
    FOREIGN KEY (author, permlink) references Posts (author, permlink) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (beneficiary) references Accounts(username) ON DELETE CASCADE ON UPDATE CASCADE
);

-- Table: votes
-- Purpose: Stores individual votes made on posts, including weight and rshares.
-- Used in: curation rewards, voter history analytics.
-- Depends on: posts, accounts

DROP TABLE IF EXISTS votes;
CREATE TABLE votes (
    author VARCHAR(16) NOT NULL,
    permlink VARCHAR(256) NOT NULL,
    voter VARCHAR(16) NOT NULL,
    time DATETIME NOT NULL,
    weight TINYINT NOT NULL CHECK (weight BETWEEN -100 AND 100),
    rshares BIGINT NOT NULL,

    -- Define composite primary key to ensure uniqueness
    PRIMARY KEY (author, permlink, voter, time),

    -- Foreign key references
    FOREIGN KEY (author, permlink) REFERENCES posts(author, permlink) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (voter) REFERENCES accounts(username) ON DELETE CASCADE ON UPDATE CASCADE,
    
    INDEX idx_votes_post_voter (author, permlink, voter)
);

-- Table: author_rewards
-- Purpose: Stores the author reward details for a post, including vests and calculated values.
-- Notes: One reward per post. Calculated via update procedure after insert.
-- Depends on: posts

DROP TABLE IF EXISTS author_rewards;
CREATE TABLE author_rewards (
    author VARCHAR(16) NOT NULL,
    permlink VARCHAR(256) NOT NULL,
    reward_time DATETIME NOT NULL,
    vests BIGINT UNSIGNED NOT NULL,
    value DECIMAL(7,2) DEFAULT NULL,
    steem DECIMAL(7,2) DEFAULT NULL,
    
    -- Define composite primary key (author, permlink)
    PRIMARY KEY (author, permlink),

    -- Foreign key reference to posts
    FOREIGN KEY (author, permlink) REFERENCES posts(author, permlink) ON DELETE CASCADE ON UPDATE CASCADE
);

-- Table: curation_rewards
-- Purpose: Stores individual curation rewards, linked to a vote.
-- Notes: Requires matching vote entry.
-- Depends on: posts, votes, accounts

DROP TABLE IF EXISTS curation_rewards;
CREATE TABLE curation_rewards (
    author VARCHAR(16) NOT NULL,
    permlink VARCHAR(256) NOT NULL,
    curator VARCHAR(16) NOT NULL,
    reward_time DATETIME NOT NULL,
    vote_time DATETIME NOT NULL,
    vests BIGINT NOT NULL,
    efficiency SMALLINT NOT NULL,
    value DECIMAL(7,2) DEFAULT NULL,
    steem DECIMAL(7,2) DEFAULT NULL,

    -- Define composite primary key
    PRIMARY KEY (author, permlink, curator),

    -- Foreign key references
    FOREIGN KEY (author, permlink) REFERENCES posts(author, permlink) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (curator) REFERENCES accounts(username) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (author, permlink, curator, vote_time) REFERENCES votes(author, permlink, voter, time) ON DELETE CASCADE ON UPDATE CASCADE
);

-- Table: beneficiary_rewards
-- Purpose: Stores the rewards received by post beneficiaries.
-- Depends on: posts, accounts, beneficiaries

DROP TABLE IF EXISTS beneficiary_rewards;
CREATE TABLE beneficiary_rewards(
	author VARCHAR(16),
    permlink VARCHAR(256),
    beneficiary VARCHAR(16),
    reward_time DATETIME NOT NULL,
    vests BIGINT UNSIGNED NOT NULL,
    value DECIMAL(7,2) DEFAULT NULL,
    steem DECIMAL(7,2) DEFAULT NULL,
    
    PRIMARY KEY (author, permlink, beneficiary),
    FOREIGN KEY (author, permlink, beneficiary) REFERENCES beneficiaries (author, permlink, beneficiary) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (author, permlink) REFERENCES posts (author, permlink) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (beneficiary) REFERENCES accounts (username) ON DELETE CASCADE ON UPDATE CASCADE
);

-- Table: author_percentile_history
-- Purpose: Stores historical percentile performance of a post's author over various time windows.
-- Used in: modeling and evaluating author consistency over time.
-- Depends on: posts

DROP TABLE IF EXISTS author_percentile_history;
CREATE TABLE author_percentile_history(
	author VARCHAR(16),
    permlink VARCHAR(256),
    days TINYINT,
    total_rewards INT,
    min_percentile TINYINT DEFAULT 0,
    max_percentile TINYINT DEFAULT 0,
    avg_percentile TINYINT DEFAULT 0,
    med_percentile TINYINT DEFAULT 0,
    
    PRIMARY KEY(author, permlink, days),
	FOREIGN KEY(author, permlink) REFERENCES posts(author,permlink)
);

-- Table: voter_curation_history
-- Purpose: Stores historical curation efficiency stats for each vote a user has made.
-- Used in: evaluating how efficient a curator has been in past time windows.
-- Depends on: posts

DROP TABLE IF EXISTS voter_curation_history;
CREATE TABLE voter_curation_history(
	author VARCHAR(16),
    permlink VARCHAR(256),
    voter VARCHAR(16),
    days TINYINT,
    total_rewards INT,
    min_efficiency INT DEFAULT 0,
    max_efficiency INT DEFAULT 0,
    avg_efficiency INT DEFAULT 0,
    med_efficiency INT DEFAULT 0,
    
    PRIMARY KEY(author, permlink, voter, days),
	FOREIGN KEY(author, permlink) REFERENCES posts(author,permlink),
    INDEX idx_vch_post_voter (author, permlink, voter)
);

-- Table: pending_vote_history
-- Purpose: Tracks votes that haven't yet had their curation history processed.
-- Used as a queue for batch history population.
-- Standalone (no FKs for flexibility during pre-validation)

DROP TABLE IF EXISTS pending_vote_history;
CREATE TABLE pending_vote_history (
	author VARCHAR(16) NOT NULL,
    permlink VARCHAR(256) NOT NULL,
    voter VARCHAR(16) NOT NULL,
    PRIMARY KEY (author, permlink, voter)
);

-- Table: comments
-- Purpose: Stores metadata about comments on posts, including parent and root context.
-- Notes: Only root_author/permlink is validated as a post (not threaded replies).
-- Depends on: posts, accounts

DROP TABLE IF EXISTS comments;
CREATE TABLE comments (
    commenter VARCHAR(16),
    permlink VARCHAR(256),
    parent_author VARCHAR(16) DEFAULT NULL,
    parent_permlink VARCHAR(256) DEFAULT NULL,
    root_author VARCHAR(16) NOT NULL,
    root_permlink VARCHAR(256) NOT NULL,
    time DATETIME NOT NULL,
    commenter_reputation TINYINT NOT NULL,

    PRIMARY KEY (commenter, permlink),
    
    -- Foreign key only on root (every comment must be tied to a post)
    FOREIGN KEY (root_author, root_permlink)
        REFERENCES posts(author, permlink)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- Table: resteems
-- Purpose: Tracks which accounts have resteemed a given post.
-- Used for measuring post amplification.
-- Depends on: posts, accounts

DROP TABLE IF EXISTS resteems;
CREATE TABLE resteems(
	author VARCHAR(16),
    permlink VARCHAR(256),
    resteemed_by VARCHAR(16),
    time DATETIME NOT NULL,
    followers BIGINT UNSIGNED,
    
    PRIMARY KEY (author, permlink, resteemed_by),
    FOREIGN KEY (author, permlink) REFERENCES posts (author, permlink) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (resteemed_by) REFERENCES accounts (username) ON DELETE CASCADE ON UPDATE CASCADE
);

-- Table: vote_batch_log
-- Purpose: Logs each batch of vote inserts.
-- Used to trigger population of voter_curation_history via after-insert trigger.
-- Standalone: does not reference other tables.

DROP TABLE IF EXISTS vote_batch_log;
CREATE TABLE vote_batch_log (
	id INT AUTO_INCREMENT PRIMARY KEY,
    inserted_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

