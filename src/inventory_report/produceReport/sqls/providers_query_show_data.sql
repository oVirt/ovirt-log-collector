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
CREATE OR REPLACE FUNCTION __temp_providers()
  RETURNS TABLE(provider_name VARCHAR(40), provider_description VARCHAR(4000), provider_url VARCHAR(512), type_provider VARCHAR(32), provider_auth_required boolean, provider_auth_username VARCHAR(64), provider_auth_password text) AS
$PROCEDURE$
BEGIN
    -- In the Engine db 4.0, vds_groups has been renamed
    -- to cluster.
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='providers') THEN
        RETURN QUERY (
        SELECT
            name AS "Name",
            description AS "Description",
            url AS "URL",
            provider_type AS "Provider Type",
            auth_required AS "Auth Required",
            auth_username AS "Auth username",
            auth_password AS "Auth Password"
        FROM
            providers
        );
    END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;

COPY (
    SELECT
        row_number() OVER (ORDER BY provider_name NULLs last) AS "NO.",
        provider_name AS "Name",
        provider_description AS "Description",
        provider_url AS "URL",
        type_provider AS "Provider Type",
        CASE WHEN provider_auth_required THEN 'Yes' ELSE 'No' END AS "Auth Required",
        provider_auth_username AS "Auth username",
        provider_auth_password AS "Auth Password"
    FROM
        __temp_providers()
    ORDER BY provider_name
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;

DROP FUNCTION __temp_providers();
