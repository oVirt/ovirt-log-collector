COPY (
    SELECT
        vm_static.vm_name AS "Virtual Machine",
        vds.vds_name AS "Hypervisor"
    FROM
        vm_static
    INNER JOIN vds ON vm_static.dedicated_vm_for_vds::uuid=vds.vds_id
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;
