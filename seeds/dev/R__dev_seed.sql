-- Development data only. This location is never copied into the migrate image, so it can't reach RDS.
-- Repeatable migration: Flyway runs it again whenever this file changes, so every insert must be idempotent.

-- One guinea pig per mark color in the pilot cage
INSERT INTO guinea_pig (cage_id, name, mark_color)
SELECT c.id, g.name, g.mark_color
FROM cage c
CROSS JOIN (VALUES
    ('Canela', 'RED'),
    ('Azulito', 'BLUE'),
    ('Menta', 'GREEN'),
    ('Mostaza', 'YELLOW'),
    ('Naranjo', 'ORANGE'),
    ('Lila', 'PURPLE'),
    ('Carbón', 'BLACK'),
    ('Nieve', 'WHITE')
) AS g (name, mark_color)
WHERE c.code = 'cage-1'
ON CONFLICT ON CONSTRAINT uq_guinea_pig_cage_color DO NOTHING;
