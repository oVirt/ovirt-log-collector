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
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;
