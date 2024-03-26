/* Secure PgBouncer using an authentication function
 * 
 * PgBouncer can invoke a function to handle authentication rather than relying
 * on a defined user list. It does this by invoking a function which can read
 * the encrypted password hash values.
 *
 * The auth functions will raise a NOTICE for each invocation for auditing
 * purposes. To see these, set log_min_messages to NOTICE or lower in the
 * postgresql.conf file.
 *
 * Set a few PgBouncer parameters in pgbouncer.ini:
 *
 *   auth_type = scram-sha-256
 *   auth_file = /etc/pgbouncer/userlist.txt
 *   auth_user = pgbouncer
 *   auth_query = SELECT * FROM pgbouncer.get_auth($1)
 *
 * To avoid having to create these functions in every database, set the
 * following parameter after defining an alias in the [databases] section of
 * pgbouncer.ini
 *
 *   auth_dbname = my_auth_db
 *
 * Note: for this to work, the pgbouncer user password must be plain text in
 * the /etc/pgbouncer/userlist.txt file. Make sure this is only readable by
 * the OS user running the pgbouncer service.
 *
 * See the PgBouncer documentation for more info:
 *
 *   https://www.pgbouncer.org/config.html
 */

-- Create the pgbouncer user and use_proxy role if they don't already exist.
-- There's no IF EXISTS for this syntax, so just ignore exceptions.

DO $$
BEGIN
  CREATE USER pgbouncer WITH PASSWORD 'changeme';
EXCEPTION WHEN duplicate_object THEN
  NULL;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  CREATE ROLE use_proxy;
EXCEPTION WHEN duplicate_object THEN
  NULL;
END;
$$ LANGUAGE plpgsql;

-- Ensure there's a dedicated pgbouncer schema.

CREATE SCHEMA IF NOT EXISTS pgbouncer AUTHORIZATION pgbouncer;

-- Build the three function variants discussed in the blog. These include:
-- 1. A standard auth function that will validate anyone.
-- 2. A function that will only authenticate users in the auth_user role.
-- 3. Same as 2, but also no superuser auth.

/* Return authentication information for any user
 *
 * This auth function will work for any user, and is a good starting point for
 * defining authentication for PgBouncer. For more security, consider the other
 * functions instead.
 */
CREATE OR REPLACE FUNCTION pgbouncer.get_auth(p_username TEXT)
RETURNS TABLE(username TEXT, password TEXT) AS
$$
BEGIN
    RAISE NOTICE 'PgBouncer auth request: %', p_username;

    RETURN QUERY
    SELECT usename::TEXT, passwd::TEXT
      FROM pg_catalog.pg_shadow
     WHERE usename = p_username;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE ALL ON FUNCTION pgbouncer.get_auth(p_username TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION pgbouncer.get_auth(p_username TEXT) TO pgbouncer;

/* Return authentication information for users granted the use_proxy role
 *
 * In order to restrict users from authenticating via PgBouncer, this function
 * will only work if a user is a member of the use_proxy role. This acts as a
 * whitelist and prevents elevated or utility roles from operating through the
 * proxy.
 */
CREATE OR REPLACE FUNCTION pgbouncer.get_proxy_auth(p_username TEXT)
RETURNS TABLE(username TEXT, password TEXT) AS
$$
BEGIN
    RAISE NOTICE 'PgBouncer auth request: %', p_username;

    RETURN QUERY
    SELECT u.rolname::TEXT, u.rolpassword::TEXT
      FROM pg_authid g
      JOIN pg_auth_members m ON (m.roleid = g.oid)
      JOIN pg_authid u ON (u.oid = m.member)
     WHERE g.rolname = 'use_proxy'
       AND u.rolname = p_username;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE ALL ON FUNCTION pgbouncer.get_proxy_auth(p_username TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION pgbouncer.get_proxy_auth(p_username TEXT) TO pgbouncer;

/* Return authentication for non-superusers granted the use_proxy role
 *
 * This function will only authenticate users with the following attributes:
 *
 * - Is a member of the use_proxy whitelist role
 * - Is not a superuser
 *
 * This acts as a safeguard in case a superuser is inadvertently added to the
 * use_proxy role, or somehow becomes a superuser afterwards. This acts as a
 * safeguard to prevent privilege escalation from the application front-end if
 * the authentication mechanism is somehow exposed.
 *
 * This is the recommended function variant for secured systems.
 */
CREATE OR REPLACE FUNCTION pgbouncer.get_proxy_auth_nosuper(p_username TEXT)
RETURNS TABLE(username TEXT, password TEXT) AS
$$
BEGIN
    RAISE NOTICE 'PgBouncer auth request: %', p_username;

    RETURN QUERY
    SELECT u.rolname::TEXT, u.rolpassword::TEXT
      FROM pg_authid g
      JOIN pg_auth_members m ON (m.roleid = g.oid)
      JOIN pg_authid u ON (u.oid = m.member)
     WHERE NOT u.rolsuper
       AND g.rolname = 'use_proxy'
       AND u.rolname = p_username;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE ALL ON FUNCTION pgbouncer.get_proxy_auth_nosuper(p_username TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION pgbouncer.get_proxy_auth_nosuper(p_username TEXT) TO pgbouncer;
