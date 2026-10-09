-- Deleting a guinea pig is a soft delete (active = false): its history stays. Its mark color, though, must
-- be free again so another guinea pig can wear it. So the "one color per cage" rule now only counts the
-- active ones: a partial unique index replaces the constraint (same name).

ALTER TABLE guinea_pig DROP CONSTRAINT uq_guinea_pig_cage_color;

CREATE UNIQUE INDEX uq_guinea_pig_cage_color ON guinea_pig (cage_id, mark_color) WHERE active;
