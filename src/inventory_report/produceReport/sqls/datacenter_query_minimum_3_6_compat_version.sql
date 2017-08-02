COPY (
    SELECT
        row_number() OVER (ORDER BY name NULLs last) AS "NO.",
        name AS "Data Center",
        compatibility_version AS "Compatibility version"
    FROM
        storage_pool
    WHERE
        compatibility_version <> '' AND
        compatibility_version < '3.6'
) To STDOUT With CSV DELIMITER E'\|' HEADER;
