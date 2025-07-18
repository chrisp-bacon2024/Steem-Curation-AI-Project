CREATE INDEX idx_votes_apvt ON votes(author, permlink, voter, time);
CREATE INDEX idx_curation_rewards_apc ON curation_rewards(author, permlink, curator);
CREATE INDEX idx_curation_rewards_apcv ON curation_rewards(author, permlink, curator, vote_time);
CREATE INDEX idx_beneficiaries_apb ON beneficiaries(author, permlink, beneficiary);
CREATE INDEX idx_beneficiary_rewards_apb ON beneficiary_rewards(author, permlink, beneficiary);
CREATE INDEX idx_author_rewards_ap ON author_rewards(author, permlink);
CREATE INDEX idx_author_percentile_history_apd ON author_percentile_history(author, permlink, days);
CREATE INDEX idx_vch_post_voter_days ON voter_curation_history(author, permlink, voter, days);
