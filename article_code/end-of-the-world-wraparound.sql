/* These views help monitor Postgres to avoid wraparound and other issues.
 *
 * Many of these views would be useful in a Prometheus context, feeding a TIG
 * stack, or other monitoring tools.
 * https://www.2ndquadrant.com/en/blog/its-the-end-of-the-world-as-we-know-it-and-postgres-is-fine/
 * 
 */

-- Shows which tables are within 90% of a VACUUM FREEZE operation.
-- Useful for knowing current / future VACUUM workload or tables in danger.

CREATE OR REPLACE VIEW v_needs_vacuum AS
SELECT c.relname AS table_name, 
       greatest(age(c.relfrozenxid), age(t.relfrozenxid)) as age
  FROM pg_class c
  LEFT JOIN pg_class t ON (c.reltoastrelid = t.oid)
 WHERE c.relkind IN ('r', 'm', 'p')
   AND greatest(age(c.relfrozenxid), age(t.relfrozenxid)) >
       current_setting('autovacuum_freeze_max_age')::NUMERIC * 0.9
 ORDER BY table_name DESC;

-- Shows any prepared transactions, sorted by age.
-- Useful to identify prepared transactions preventing VACUUM cleanup.

CREATE OR REPLACE VIEW v_database_prepared_xact_age AS
SELECT database, prepared,
       round(extract(epoch FROM now() - prepared)) AS age
  FROM pg_prepared_xacts
 ORDER BY age DESC;

-- Shows which replication slots are active and any lag amounts in bytes.
-- Good for finding sources of lag in a system using replication slots.

CREATE OR REPLACE VIEW v_replication_slot_lag AS
SELECT slot_name, active,
       pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) AS restart_lag,
       pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn) AS flush_lag
  FROM pg_replication_slots;

-- Shows the client and any known lag amounts for a replication stream.
-- Good for finding sources of lag for connected replicas of all types.

CREATE OR REPLACE VIEW v_replication_lag AS
SELECT application_name, client_addr,
       pg_wal_lsn_diff(pg_current_wal_lsn(), sent_lsn) AS sent_lag,
       pg_wal_lsn_diff(pg_current_wal_lsn(), write_lsn) AS write_lag,
       pg_wal_lsn_diff(pg_current_wal_lsn(), flush_lsn) AS flush_lag,
       pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS replay_lag
  FROM pg_stat_replication;

-- The following views should be used as a difference between two measurements.
-- This will show the absolute activity over time.

-- Shows temporary files and bytes per database as a snapshot.
-- Can be used to adjust work_mem if the average size is relatively low.

CREATE OR REPLACE VIEW v_current_temp_file_usage AS
SELECT now() AS check_dt, datname,
       temp_files, temp_bytes
  FROM pg_stat_database;

-- Shows various statistics about the background writer / checkpointer process.
-- Especially useful to see write volume induced by checkpoints, and then
-- to adjust max_wal_size or checkpoint_timeout.

CREATE OR REPLACE VIEW v_current_bgwriter_stats AS
SELECT now() AS check_dt,
       checkpoints_timed, checkpoints_req,
       checkpoint_write_time, checkpoint_sync_time
  FROM pg_stat_bgwriter;

-- Shows database commit and rollback transaction counts as a snapshot.
-- Generally just a useful heuristic measurement of database throughput.

CREATE OR REPLACE VIEW v_current_transaction_stats AS
SELECT now() AS check_dt, datname, 
       xact_commit AS commit, xact_rollback AS rollback
  FROM pg_stat_database;

-- Shows the absolute WAL progression of the database instance as a snapshot.
-- WAL production rate is the best indicator of "true" data throughput.

CREATE OR REPLACE VIEW v_current_wal_activity AS
SELECT now() AS check_dt,
       pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0') AS total_bytes;
