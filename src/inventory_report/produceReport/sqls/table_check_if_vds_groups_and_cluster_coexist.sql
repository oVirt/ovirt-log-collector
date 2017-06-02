-- vds_groups table has been renamed to cluster and should not co-exist
SELECT
    COUNT(1)
FROM
    information_schema.tables
WHERE
    table_name IN ('cluster', 'vds_groups');
