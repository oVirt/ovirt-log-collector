SELECT
    COUNT(vm_name)
FROM
    vm_static
WHERE
    os IN (
        1,
        3,
        4,
        10,
        11,
        12,
        16,
        17,
        20,
        21,
        23,
        25,
        26,
        27,
        29
    ) AND
    entity_type = 'VM'
