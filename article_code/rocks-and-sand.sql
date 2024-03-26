/* This view lists columns in optimal order to maximize rows per page.
 *
 * From: https://www.2ndquadrant.com/en/blog/on-rocks-and-sand/
 * 
 * The easiest way to use this is to simply run this against your database and
 * then select from the view, focusing on a table you may like to optimize.
 *
 * To produce the results of the example table from the associated article:
 *
 * SELECT * FROM v_optimum_column_order
 *  WHERE table_name = 'user_order';
 */

CREATE OR REPLACE VIEW v_optimum_column_order AS
SELECT c.relname AS table_name, a.attname AS column_name,
       t.typname AS column_type, t.typalign AS alignment,
       t.typlen AS type_length
  FROM pg_class c
  JOIN pg_attribute a ON (a.attrelid = c.oid)
  JOIN pg_type t ON (t.oid = a.atttypid)
  JOIN pg_namespace n ON (n.oid = c.relnamespace)
 WHERE c.relkind IN ('r', 'p')
   AND a.attnum >= 0
   AND n.nspname NOT IN ('pg_catalog', 'information_schema')
 ORDER BY t.typlen DESC;
