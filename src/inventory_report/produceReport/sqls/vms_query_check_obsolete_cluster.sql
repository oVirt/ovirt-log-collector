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
CREATE OR REPLACE FUNCTION __temp_hosts_check_obsolete_cluster()
  RETURNS TABLE(vms bigint) AS
$PROCEDURE$
BEGIN
    -- new versions of database the vds_group_compatibility_version was
    -- renamed to cluster_compatibility_version, if we find it let's use it.
    IF EXISTS (SELECT column_name FROM information_schema.columns WHERE table_name='vms' and column_name='cluster_compatibility_version') THEN
         RETURN QUERY EXECUTE format('
             SELECT
                 COUNT(vm_name)
             FROM
                 vms
             WHERE
                 cluster_compatibility_version <> '''' and
                 cluster_compatibility_version < ''3.6''
         ');
    ELSE
         RETURN QUERY EXECUTE format('
             SELECT
                 COUNT(vm_name)
             FROM
                 vms
             WHERE
                 vds_group_compatibility_version <> '''' and
                 vds_group_compatibility_version < ''3.6''
         ');
    END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;

select __temp_hosts_check_obsolete_cluster();
drop function __temp_hosts_check_obsolete_cluster();
