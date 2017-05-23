SELECT
    vm_name AS "VM Name",
    os AS "OS",
    time_zone AS "TimeZone"
FROM
    vm_static
WHERE
    time_zone = '' AND
    vm_name != 'Tiny' AND
    vm_name != 'XLarge' AND
    vm_name != 'Small' AND
    vm_name != 'Large' AND
    vm_name != 'Medium' AND
    vm_name != 'Blank'
