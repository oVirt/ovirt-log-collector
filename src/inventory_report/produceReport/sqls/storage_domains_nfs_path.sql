--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.
--
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
    INNER JOIN storage_server_connections ON storage_domain_static.storage=storage_server_connections.id AND
    storage_server_connections.storage_type=1
    ORDER BY storage_domain_static.storage_name, storage_server_connections.connection
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;
