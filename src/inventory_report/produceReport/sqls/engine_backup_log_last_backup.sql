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
        scope AS "Scope",
        done_at AS "Done At",
        CASE WHEN is_passed THEN 'Yes' ELSE 'No' END AS "Passed",
        output_message AS "Message",
        fqdn AS "FQDN",
        log_path AS "Log Path"
    FROM
        engine_backup_log ORDER BY done_at DESC LIMIT 4
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;
