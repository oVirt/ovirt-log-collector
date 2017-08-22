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
--
-- This script takes all records from schema_version, and groups them 'according' to time, when their execution ended.
-- But grouping would create I record per group, which is not desirable. Therefore we 'round' their execution end time
-- to 30 minutes intervals, and group records using this time. From each such group we extract version column having
-- 'maximum value'. Value of this column is numbers separated by underscore so ordering should be ok. Version field
-- contains major and minor numbers as first two, followed by script number. Only major and minor version is reported.
SELECT
  regexp_replace(max(version), '^(0(\d{1})|(\d{2}))(0(\d{1})|(\d{2})).*$', '\2\3.\5\6')
FROM
  schema_version
GROUP BY
  round(extract (EPOCH FROM ended_at)/60/30)
ORDER BY
  round(extract (EPOCH FROM ended_at)/60/30);
