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
--  Script to identiy hypervisor(s) with Power Management disabled,
--  address set and no power management user data.
--  More info see bz#1488630
--
CREATE OR REPLACE FUNCTION __temp_power_management_disable_address_set_with_no_user()
  RETURNS TABLE(hypervisor VARCHAR(255), address VARCHAR(255), username VARCHAR(50)) AS
$PROCEDURE$
BEGIN
    -- In recent dbs, there is no power management address
    -- on vds_static table.
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='vds' AND column_name='ip') THEN
        RETURN QUERY (
        SELECT
            vds_name AS "Hypervisor",
            ip AS "Power Management Address",
            pm_user AS "Power Management User"
        FROM
            vds_static
        WHERE
            ip IS NOT NULL AND pm_user is NULL
        );
    END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;

COPY (
    SELECT
        row_number() OVER (ORDER BY hypervisor NULLs last) AS "NO.",
        hypervisor AS "Hypervisor",
        address AS "Power Management Address",
        username AS "Power Management User"
    FROM
        __temp_power_management_disable_address_set_with_no_user()
    ORDER BY hypervisor
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;

DROP FUNCTION __temp_power_management_disable_address_set_with_no_user();
