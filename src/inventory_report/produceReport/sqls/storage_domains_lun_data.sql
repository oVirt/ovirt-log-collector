COPY (
    SELECT
        lv.storage_name AS "Storage Domain",
        storage_server_connections.iqn AS "IQN",
        storage_server_connections.port AS "Port",
        storage_server_connections.connection AS "Connection",
        storage_server_connections.portal AS "Portal"
    FROM
        storage_server_connections
    INNER JOIN
        lun_storage_server_connection_map
    ON
        storage_server_connections.id=lun_storage_server_connection_map.storage_server_connection
    INNER JOIN
        luns_view lv
    ON
        lun_storage_server_connection_map.lun_id=lv.lun_id
) TO STDOUT With CSV DELIMITER E'\|' HEADER;
