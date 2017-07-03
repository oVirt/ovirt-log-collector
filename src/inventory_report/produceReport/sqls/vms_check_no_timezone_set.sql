SELECT
    vm_name AS "VM Name",
    os AS "OS",
    time_zone AS "TimeZone"
FROM
    vm_static
WHERE
    time_zone = '' AND
    entity_type = 'VM'
