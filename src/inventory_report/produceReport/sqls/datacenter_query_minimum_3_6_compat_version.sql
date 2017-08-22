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
        row_number() OVER (ORDER BY name NULLs last) AS "NO.",
        name AS "Data Center",
        compatibility_version AS "Compatibility version"
    FROM
        storage_pool
    WHERE
        compatibility_version <> '' AND
        compatibility_version < '3.6'
) To STDOUT With CSV DELIMITER E'\|' HEADER;
