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
CREATE table storage_type_temp (
    id NUMERIC, text varchar
);

----------------------------------------------------------------
-- All values defined in ovirt-engine project:
-- backend/manager/modules/common/src/main/java/org/ovirt/engine/core/common/businessentities/storage/StorageType.java
----------------------------------------------------------------
INSERT INTO storage_type_temp VALUES
    (0, 'UNKNOWN'),
    (1, 'NFS'),
    (2, 'FCP'),
    (3, 'ISCSI'),
    (4, 'LOCALFS'),
    (6, 'POSIXFS'),
    (7, 'GLUSTERFS'),
    (8, 'GLANCE'),
    (9, 'CINDER');

CREATE table storage_domain_type_temp (
    id NUMERIC, text varchar
);

----------------------------------------------------------------
-- All values defined in ovirt-engine project:
-- backend/manager/modules/common/src/main/java/org/ovirt/engine/core/common/businessentities/StorageDomainType.java
----------------------------------------------------------------
INSERT into storage_domain_type_temp VALUES
    (0, 'Master'),
    (1, 'Data'),
    (2, 'ISO'),
    (3, 'ImportExport'),
    (4, 'Image'),
    (5, 'Volume'),
    (6, 'Unknown');
