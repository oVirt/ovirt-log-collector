SELECT
    row_number() OVER (ORDER BY storage_domains.storage_name NULLs last) AS "NO.",
    storage_domains.storage_name AS "Storage Domain",
    count(image_storage_domain_map.image_id) AS "Number of disks"
FROM
    image_storage_domain_map
INNER JOIN
    storage_domains ON image_storage_domain_map.storage_domain_id=storage_domains.id
GROUP BY storage_domains.storage_name, image_storage_domain_map.storage_domain_id
