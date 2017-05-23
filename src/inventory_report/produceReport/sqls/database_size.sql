SELECT
    pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database where pg_database.datname='report'
