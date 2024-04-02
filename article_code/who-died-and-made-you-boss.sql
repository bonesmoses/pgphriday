/* A series of useful views / functions / roles for Postgres system forensics
 *
 * https://bonesmoses.org/2017/pg-phriday-who-died-and-made-you-boss-the-investigatining/
 */

-- This is/was a useful method for obtaining information from pg_stat_activity
-- as a non-superuser. This has since been deprecated in favor of the
-- pg_read_all_stats role.

CREATE ROLE monitor;

CREATE OR REPLACE FUNCTION public.pg_stat_activity()
RETURNS SETOF pg_catalog.pg_stat_activity
AS $$
  SELECT * FROM pg_catalog.pg_stat_activity;
$$ LANGUAGE sql SECURITY DEFINER;

REVOKE ALL ON FUNCTION public.pg_stat_activity() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pg_stat_activity() TO monitor;

-- This view shows which index / table pages are in shared buffers, and the
-- proportion of the buffers used by each.

CREATE OR REPLACE VIEW v_buffer_contents AS
SELECT c.oid::REGCLASS::TEXT AS object_name,
       round(count(*) * 8.0 / 1024, 2) AS mb_used,
       round(c.relpages * 8.0 / 1024, 2) AS object_mb,
       round(count(*) * 100.0 / c.relpages, 2) AS object_pct,
       round(count(*) * 100.0 / sum(count(*)) OVER (), 2) AS buffer_pct
  FROM pg_buffercache b
  JOIN pg_class c USING (relfilenode)
  JOIN pg_namespace n ON (c.relnamespace = n.oid)
 WHERE n.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
   AND c.relpages > 0
 GROUP BY c.oid, c.relpages;

GRANT SELECT ON v_buffer_contents TO monitor;

-- View for watching tuple writes to all tables. This basically simplifies the
-- pg_stat_user_tables view to just show insert/update/delete activity.

CREATE OR REPLACE VIEW v_table_write_activity AS
SELECT schemaname, relname AS table_name, 
       sum(n_tup_ins) AS inserts,
       sum(n_tup_upd) AS updates,
       sum(n_tup_del) AS deletes,
       sum(n_tup_ins + n_tup_upd + n_tup_del) AS total_writes
  FROM pg_stat_user_tables
 GROUP BY schemaname, relname;

GRANT SELECT ON v_table_write_activity TO monitor;

-- View for watching tuple and index reads to all tables. This simplifies the
-- pg_stat_user_tables view to just show sequential and index scan activity.

CREATE OR REPLACE VIEW v_table_read_activity AS
SELECT s.schemaname, s.relname AS table_name, 
       s.seq_scan, s.idx_scan,
       s.idx_tup_fetch, c.reltuples AS row_count
  FROM pg_stat_user_tables s
  JOIN pg_class c ON (c.oid = s.relid);

GRANT SELECT ON v_table_read_activity TO monitor;

-- View for recursively finding all roles a user has been granted. This will
-- include roles granted to roles, etc.

CREATE OR REPLACE VIEW v_recursive_group_list AS
WITH RECURSIVE all_groups AS
(
  SELECT r.rolname AS user_name, g.rolname AS group_name
    FROM pg_authid r
    JOIN pg_auth_members m on (m.member=r.oid)
    JOIN pg_authid g on (m.roleid=g.oid)
  UNION ALL
  SELECT ag.user_name, g.rolname AS group_name
    FROM pg_authid r
    JOIN pg_auth_members m on (m.member=r.oid)
    JOIN pg_authid g on (m.roleid=g.oid)
    JOIN all_groups ag ON (r.rolname = ag.group_name)
)
SELECT * FROM all_groups;

GRANT SELECT ON v_recursive_group_list TO monitor;

-- A view that uses the recursive group list to decode which tables a user
-- has access to, based on all of their role grants.

CREATE OR REPLACE VIEW v_recursive_table_privileges AS
SELECT gl.user_name, t.table_schema, t.table_name, t.privilege_type
  FROM v_recursive_group_list gl
  JOIN information_schema.table_privileges t ON (t.grantee IN (gl.user_name, gl.group_name));

-- A view to group locked objects by session, making it easier to see which
-- tables, indexes, etc. are involved.

CREATE OR REPLACE VIEW v_activity_locks AS
SELECT a.pid, s.mode, s.locktype, a.wait_event, a.state,
       a.usename, a.query_start::TIMESTAMP(0), a.client_addr,
       now() - a.query_start as time_used, a.query, s.tables
  FROM pg_stat_activity() a
  LEFT JOIN (
         SELECT pid AS pid, mode, locktype,
                string_agg(relname::text, ', ') AS tables
           FROM (SELECT l.pid, l.mode, l.locktype, c.relname
                   FROM pg_locks l
                   JOIN pg_class c ON (l.relation=c.oid)
                  WHERE c.relkind = 'r'
                  ORDER BY pid, relname) agg
          GROUP BY 1, 2, 3
       ) s USING (pid);

GRANT SELECT ON v_activity_locks TO monitor;

-- View to show which session activity is blocking other session activity.
-- The magic here is the pg_blocking_pids() function.

CREATE OR REPLACE VIEW v_blocking_activity AS
SELECT l1.pid AS blocker_pid, l1.query AS blocker_query, 
       l1.usename AS blocker_user, l1.client_addr AS blocker_client,
       l2.pid AS blocked_pid, l2.query AS blocked_query,
       l2.usename AS blocked_user, l2.client_addr AS blocked_client,
       l1.mode AS lock_mode, l1.tables AS affected_tables
  FROM v_activity_locks l1
  JOIN v_activity_locks l2 ON (l1.pid = ANY(pg_blocking_pids(l2.pid)));

GRANT SELECT ON v_blocking_activity TO monitor;

