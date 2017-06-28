SELECT
    row_number() OVER (ORDER BY name NULLs last) AS "NO.",
    name AS "Data Center",
    compatibility_version AS "Compatibility version"
FROM
    storage_pool
ORDER BY name
