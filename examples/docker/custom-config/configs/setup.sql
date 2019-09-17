    /* the following are required for other container operations */
    ALTER USER postgres PASSWORD 'PG_ROOT_PASSWORD';

    CREATE USER PG_PRIMARY_USER WITH REPLICATION PASSWORD 'PG_PRIMARY_PASSWORD';

    CREATE ROLE PG_USER WITH CREATEROLE LOGIN PASSWORD 'PG_PASSWORD';
    CREATE DATABASE PG_DATABASE;
    GRANT ALL PRIVILEGES ON DATABASE PG_DATABASE TO PG_USER;
    CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
    \c PG_DATABASE

    /* the following can be customized for your purposes */


    DO $$
    DECLARE
      postgresql_type text;
    BEGIN
      SELECT setting
      FROM pg_settings
      WHERE name='data_directory'
      INTO postgresql_type;

      RAISE NOTICE 'Value: %', postgresql_type;

      -- Configure cstore_fdw extension
      IF postgresql_type NOT LIKE '%admindb' THEN
        RAISE NOTICE 'Setting up cstore_fdw on: %', postgresql_type;

        CREATE EXTENSION IF NOT EXISTS "cstore_fdw";
        GRANT USAGE ON FOREIGN DATA WRAPPER cstore_fdw TO PG_USER;
      END IF;

      -- Configure for btree_gist extension
      IF postgresql_type LIKE '%realtimedb' THEN
        RAISE NOTICE 'Setting up btree_gist on: %', postgresql_type;

        CREATE EXTENSION IF NOT EXISTS "btree_gist";
      END IF;

      -- Configure citus extension
      IF postgresql_type LIKE '%dw' THEN
        RAISE NOTICE 'Setting up citus on: %', postgresql_type;

        CREATE EXTENSION IF NOT EXISTS "citus";
      END IF;
    END $$;

    CREATE EXTENSION IF NOT EXISTS "pg_cron";
    ALTER EXTENSION "pg_cron" UPDATE;
    GRANT USAGE ON SCHEMA cron TO PG_USER;

    CREATE SCHEMA IF NOT EXISTS "partman";
    CREATE EXTENSION IF NOT EXISTS "pg_partman" SCHEMA "partman";
    GRANT USAGE ON SCHEMA partman TO PG_USER;
    GRANT SELECT, UPDATE ON TABLE partman.part_config TO PG_USER;
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE partman.part_config_sub TO PG_USER;

    CREATE EXTENSION IF NOT EXISTS "pg_stat_kcache";
    CREATE EXTENSION IF NOT EXISTS "pg_trgm";
    CREATE EXTENSION IF NOT EXISTS "tablefunc" CASCADE;
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp" CASCADE;
