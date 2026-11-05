-- The backend learns what is normal for each guinea pig from its own normal windows (backend Task 11.1).
-- It needs to know how many windows the profile was learned from: a plain average while it has few, then a
-- slow moving average, and the default profile is used until enough windows were seen.
ALTER TABLE baseline_profile ADD COLUMN sample_count INT NOT NULL DEFAULT 0;

ALTER TABLE baseline_profile ADD CONSTRAINT ck_baseline_profile_samples CHECK (sample_count >= 0);
