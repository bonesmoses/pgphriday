/* This was a silly post that defined procedures you should never use in prod.
 *
 * https://www.2ndquadrant.com/en/blog/pg-phriday-stored-procedures-postgres-11/
 */

-- This procedure will waste the specified amount of transactions.
-- DO NOT DO THIS IF YOU ARE CLOSE TO XID WRAPAROUND!

CREATE OR REPLACE PROCEDURE waste_xid(cnt INT)
AS $$
DECLARE
    i INT;
    x BIGINT;
BEGIN
    FOR i IN 1..cnt LOOP
        x := txid_current();
        COMMIT;
    END LOOP;
END;
$$
LANGUAGE plpgsql;

-- This procedure will show how now() works in procedural transactions.
-- The beta of Postgres 11 showed all of these values were the same.
-- Postgres 11 release fixed that bug.

CREATE OR REPLACE PROCEDURE check_now()
AS $$
DECLARE
    i int;
BEGIN
    FOR i in 1..5 LOOP
        RAISE NOTICE 'It is now: %', now();
        PERFORM txid_current();
        COMMIT;
        PERFORM pg_sleep(0.1);
    END LOOP;
END;
$$
LANGUAGE plpgsql;

