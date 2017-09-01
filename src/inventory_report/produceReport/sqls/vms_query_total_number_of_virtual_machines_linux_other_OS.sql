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
SELECT
    COUNT(vm_name)
FROM
    vm_static
WHERE
    os IN (
        0,
        5,
        7,
        8,
        9,
        13,
        14,
        15,
        18,
        19,
        24,
        28,
        1193,
        1252,
        1253,
        1254,
        1255,
        1256,
        1300,
        1500,
        1501,
        1001,
        1002,
        1003,
        1004,
        1005,
        1006
    ) AND
    entity_type = 'VM'
