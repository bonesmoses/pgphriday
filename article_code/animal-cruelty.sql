/* A Game of unnecessary cruelty to animals
*
* This is supposed to be a Tamagachi style of game but contains a horrifying
* flaw that leads to the nearly immediate demise of all pets contained within.
* Can you find and correct the flaw before your pet succumbs to its fate?
*
* The following two postgresql.conf parameters must be set:
*
*   shared_preload_libraries = 'pg_cron'
*   cron.database_name = 'phriday'
*/


-- This is the only physical table structure in the game. 
-- Yes, we are that lazy. We do keep track of when the pet was born and died,
-- but have also denormalized the fact it's dead for convenience.
-- Note that we allow DELETEs on the table, mostly for amusement purposes;
-- the game will not allow resurrection, and calls it out.

CREATE TABLE db_pet (
  player      VARCHAR  NOT NULL PRIMARY KEY,
  pet_name    VARCHAR  NOT NULL,
  mood        INT      NOT NULL DEFAULT 24,
  food        INT      NOT NULL DEFAULT 24,
  is_dead     BOOLEAN  NOT NULL DEFAULT FALSE,
  birth_date  TIMESTAMPTZ NOT NULL DEFAULT now(),
  death_date  TIMESTAMPTZ NULL
);

GRANT SELECT, INSERT, UPDATE ON db_pet TO PUBLIC;

-- Now enable and define RLS so owners can only interact with their own pets.
-- We'll also define triggers for other integrity needs, but this prevents
-- outright abuse.

ALTER TABLE db_pet ENABLE ROW LEVEL SECURITY;

CREATE POLICY only_pet_owner
    ON db_pet
   FOR ALL TO PUBLIC
 USING (player = SESSION_USER);

-- Create a handy view to represent a "GUI" for the current state of the pet.
-- We can display how fed or entertained, overall health, and age.

CREATE OR REPLACE VIEW my_pet AS
SELECT pet_name,
       CASE WHEN food = 0 THEN 'NONE!'
            WHEN food < 8 THEN 'STARVING'
            WHEN food < 16 THEN 'HUNGRY'
            ELSE 'FULL'
       END AS appetite,
       CASE WHEN mood = 0 THEN 'NONE!'
            WHEN mood < 8 THEN 'DEPRESSED'
            WHEN mood < 16 THEN 'BORED'
            ELSE 'HAPPY'
       END AS spirits,
       CASE WHEN is_dead THEN 'DEAD (you monster!)'
            WHEN food < 5 OR mood < 5 THEN 'SICK'
            WHEN food < 13 OR mood < 13 THEN 'OK'
            ELSE 'GREAT'
       END AS health,
       (COALESCE(death_date, now()) - birth_date)::INTERVAL(0) AS age
  FROM db_pet
 WHERE player = SESSION_USER;

GRANT SELECT ON my_pet TO PUBLIC;

-- Define a trigger to prevent duplicate pets per player.
-- This is technically already handled by the primary key, but a user can try
-- to create a new pet, and we want to present a different error if they do.
--  - If their previous pet died, no more pets!
--  - If they try to create more than one, tell them about the limit.

CREATE OR REPLACE FUNCTION check_pet_state()
RETURNS TRIGGER AS
$$
DECLARE
  pet_dead BOOLEAN;
BEGIN
  SELECT is_dead INTO pet_dead FROM db_pet;

  IF pet_dead THEN
    RAISE EXCEPTION 'Your ONLY pet is dead forever. Murderer!';
  ELSEIF FOUND THEN 
    RAISE EXCEPTION 'You can only ever have one pet!';
  END IF;

  NEW.player = SESSION_USER;
  NEW.birth_date = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER t_enforce_pet_state_b_i
BEFORE INSERT ON db_pet
   FOR EACH ROW EXECUTE PROCEDURE check_pet_state();

-- Define a trigger to prevent a player from exceeding pet limitations
-- This includes:
--  - No raising a pet from the dead by setting is_dead to false.
--  - No overfeeding or too much entertainment
--  - No foisting of commitment to others

CREATE OR REPLACE FUNCTION check_pet_limits()
RETURNS TRIGGER AS
$$
BEGIN
  -- First things first: no necromancy!

  IF OLD.is_dead THEN
    RAISE EXCEPTION 'Your ONLY pet is dead forever. Murderer!';
  END IF;

  -- Don't let the player sell or give away their pet!

  IF OLD.player != NEW.player THEN
    RAISE EXCEPTION 'You must commit to your pet. No selling!';
  END IF;

  -- Don't let pets accumulate more than 24 hours worth survival.

  NEW.mood := least(24, NEW.mood);
  NEW.food := least(24, NEW.food);

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER t_enforce_pet_limits_b_ud
BEFORE UPDATE OR DELETE ON db_pet
   FOR EACH ROW EXECUTE PROCEDURE check_pet_limits();

-- Function to conveniently create a new pet by just supplying the name
-- This only works once per player.

CREATE OR REPLACE FUNCTION new_pet(p_name TEXT)
RETURNS SETOF my_pet AS
$$
  INSERT INTO db_pet (pet_name) VALUES (p_name);
  SELECT * FROM my_pet;
$$ LANGUAGE SQL;

-- Function to feed the pet 8 hours worth of food.
-- Table trigger prevents overfeeding.

CREATE OR REPLACE FUNCTION feed_pet()
RETURNS SETOF my_pet AS
$$
  UPDATE db_pet
     SET food = food + 8
   WHERE player = SESSION_USER;

  SELECT * FROM my_pet;
$$ LANGUAGE SQL;

-- Function to give the pet 12 hours worth of entertainment.
-- Table trigger prevents over 24 hours of satisfaction.

CREATE OR REPLACE FUNCTION train_pet()
RETURNS SETOF my_pet AS
$$
  UPDATE db_pet
     SET mood = mood + 12
   WHERE player = SESSION_USER;

  SELECT * FROM my_pet;
$$ LANGUAGE SQL;

-- Function to deduct 1 food/entertainment or kill unhealthy ones.
-- This should be called every hour via pg_cron.

CREATE OR REPLACE FUNCTION pet_game_loop()
RETURNS VOID AS
$$
  UPDATE db_pet
     SET food = food - 1,
         mood = mood - 1
   WHERE NOT is_dead;

  UPDATE db_pet
     SET is_dead = TRUE,
         death_date = now()
   WHERE (mood < 1 OR food < 1)
     AND NOT is_dead;
$$ LANGUAGE SQL;

-- Set the schedule to one hour. What could go wrong?

SELECT cron.schedule(
  'game-loop', '1 second', 'SELECT pet_game_loop()'
);
