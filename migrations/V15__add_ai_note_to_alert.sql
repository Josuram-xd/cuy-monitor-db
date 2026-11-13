-- The assistant used to answer only when the breeder asked. Now an alert carries the explanation the
-- model wrote for it, so the dashboard shows it without anyone typing a question (and without paying
-- for the same answer again every time the alert is opened).
--
-- Both columns are nullable on purpose: the note arrives seconds after the alert, written by a
-- background task, and an alert whose model call failed keeps working without one.

ALTER TABLE alert ADD COLUMN ai_note VARCHAR(2000);
ALTER TABLE alert ADD COLUMN ai_note_at TIMESTAMPTZ;

-- Either both or neither: a note always says when it was written.
ALTER TABLE alert ADD CONSTRAINT ck_alert_ai_note
    CHECK ((ai_note IS NULL) = (ai_note_at IS NULL));
