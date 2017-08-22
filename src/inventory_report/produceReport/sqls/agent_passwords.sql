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
-- translates vds_id to cluster_name and host_name, adds third projection 'password' orders tuples by first two
-- projections, filter out tuples with empty password, converts everything to csv output.
  SELECT
    row_number() OVER (ORDER BY map.cluster_name, map.vds_name NULLs last) AS "NO.",
    map.cluster_name AS "Cluster Name",
    map.vds_name AS "Vds Name",
    foo.password AS "Password"
  FROM
    __temp_encrypted_fencing_passwords() AS foo
  JOIN
    __temp_cluster_id_to_name_map() map ON map.vds_id = foo.vds_id
  WHERE
    foo.password IS NOT NULL AND
    foo.password <> ''
  ORDER BY
    map.cluster_name,
    map.vds_name
