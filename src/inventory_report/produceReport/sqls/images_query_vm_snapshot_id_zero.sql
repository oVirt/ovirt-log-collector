COPY (
    SELECT
        vm_static.vm_name AS "Virtual Machine",
        images.image_guid AS "Image GUID",
        images.image_group_id AS "Image Group ID",
        images.vm_snapshot_id AS "VM Snapshot ID"
    FROM
        images
    INNER JOIN vm_device ON vm_device.device_id=images.image_group_id
    INNER JOIN vm_static ON vm_static.vm_guid=vm_device.vm_id
    AND vm_snapshot_id='00000000-0000-0000-0000-000000000000'
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;
