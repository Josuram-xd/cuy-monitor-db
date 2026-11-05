-- The alert history of the dashboard (backend GET /api/v1/alerts/history) filters by cage, by guinea pig, or
-- both, newest first. The cage already has ix_alert_cage_created; this one serves the history of one guinea pig.
-- Partial: cage-level alerts (AUDIO, WEIGHT) have no guinea pig and never need it.
CREATE INDEX ix_alert_guinea_pig_created ON alert (guinea_pig_id, created_at DESC)
    WHERE guinea_pig_id IS NOT NULL;
