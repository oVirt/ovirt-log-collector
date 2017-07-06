COPY (
    SELECT
        storage_name AS "Storage Domain",
        vendor_id AS "Vendor ID",
        product_id AS "Product ID",
        device_size AS "Device Size",
        serial AS "Serial",
        volume_group_id AS "Volume Group ID",
        lun_id AS "Lun ID",
        physical_volume_id AS "Physical Volume ID"
    FROM
        luns_view
) TO STDOUT With CSV DELIMITER E'\|' HEADER;
