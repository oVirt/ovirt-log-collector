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
--  Search for possible issues in the past 15 days
--
COPY (
   SELECT
        log_time AS "Log time",
        message AS "Message"
    FROM
        audit_log
    WHERE message ILIKE ANY(ARRAY['%error%', '%failed%']) AND log_time >= current_date - interval '15' day AND log_type_name != 'USER_VDC_LOGIN_FAILED' ORDER BY log_time DESC
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;
