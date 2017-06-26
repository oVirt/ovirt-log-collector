SELECT
    COUNT(vm_name)
FROM
    vm_static
WHERE
    os IN (
        0,
        5,
        7,
        8,
        9,
        13,
        14,
        15,
        18,
        19,
        24,
        28,
        1193,
        1252,
        1253,
        1254,
        1255,
        1256,
        1300,
        1500,
        1501,
        1001,
        1002,
        1003,
        1004,
        1005,
        1006
    ) AND
    entity_type = 'VM'
