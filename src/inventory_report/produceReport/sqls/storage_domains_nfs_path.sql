-- storage_type value is based on engine project:
-- backend/manager/modules/common/src/main/java/org/ovirt/engine/core/common/businessentities/storage/StorageType.java
--
-- UNKNOWN(0, Subtype.NONE),
-- NFS(1, Subtype.FILE),
-- FCP(2, Subtype.BLOCK),
-- ISCSI(3, Subtype.BLOCK),
-- LOCALFS(4, Subtype.FILE),
-- POSIXFS(6, Subtype.FILE),
-- GLUSTERFS(7, Subtype.FILE),
-- GLANCE(8, Subtype.FILE),
-- CINDER(9, Subtype.OPENSTACK);
COPY (
    SELECT
        storage_domain_static.storage_name AS "NFS Storage Domain",
        storage_server_connections.connection AS "Storage Path"
    FROM
        storage_domain_static
    INNER JOIN
        storage_server_connections
    ON
        storage_domain_static.storage=storage_server_connections.id
    AND
        storage_server_connections.storage_type=1
    ORDER BY
        storage_domain_static.storage_name, storage_server_connections.connection
) TO STDOUT With CSV DELIMITER E'\|' HEADER;
