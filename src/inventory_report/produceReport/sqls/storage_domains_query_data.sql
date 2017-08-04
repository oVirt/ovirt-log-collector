COPY (
    SELECT
        row_number() OVER (ORDER BY sds.storage_name NULLs last) AS "NO.",
        sds.storage_name AS "Storage Domain",
        sds.storage_pool_name AS "Data Center",
        stt.text AS "Type",
        sdtt.text AS "Storage Domain Type",
        sds.available_disk_size AS "Available disk size (GB)",
        sds.used_disk_size AS "Used disk size (GB)",
        sum(sds.available_disk_size + sds.used_disk_size) AS "Total disk size (GB)",
        count(image_storage_domain_map.image_id) AS "Number of disks"
    FROM
        storage_domains sds
    JOIN storage_type_temp stt ON sds.storage_type=stt.id
    JOIN storage_domain_type_temp sdtt ON sds.storage_domain_type=sdtt.id
    JOIN image_storage_domain_map ON sds.id=image_storage_domain_map.storage_domain_id
    GROUP BY
        sds.storage_name, sds.storage_pool_name, sds.available_disk_size, sds.used_disk_size, stt.text, sdtt.text
    ORDER BY
        sds.storage_name
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;
