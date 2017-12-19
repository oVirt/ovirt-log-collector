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

CREATE OR REPLACE FUNCTION __temp_network_using_network_attachments()
    RETURNS TABLE(net_name VARCHAR(256),vds_name VARCHAR(255),vdsm_name unknown,sp_name VARCHAR(40),nic_name VARCHAR(50),
                  attached_to_nic_type text,related_mac_addresses text,na_address VARCHAR(50),net_vlan_id integer,net_mtu integer,
                  net_description VARCHAR(4000),net_subnet VARCHAR(20),net_gateway VARCHAR(20)) AS
    $PROCEDURE$
    BEGIN
        -- network.vdsm_name added in 4.1.7
        IF EXISTS (SELECT column_name
                   FROM information_schema.columns
                   WHERE table_name='network' AND column_name='vdsm_name') THEN
            RETURN QUERY (
                SELECT
                    n.name,
                    vs.vds_name,
                    n.vdsm_name,
                    sp.name,
                    nic.name,
                    CASE
                        WHEN nic.is_bond THEN (
                            SELECT 'Bond(slaves: '||string_agg(slave.name, ', ')||')'
                            FROM vds_interface slave
                            WHERE slave.bond_name = nic.name AND slave.vds_id=nic.vds_id)
                        WHEN n.vlan_id IS NOT NULL THEN 'VLAN' ELSE 'Regular NIC'
                    END,

                    ARRAY_TO_STRING(
                        ARRAY[nic.mac_addr,
                        (SELECT STRING_AGG(slave.mac_addr, ', ') FROM vds_interface slave WHERE slave.bond_name = nic.name AND slave.vds_id=nic.vds_id)],
                        ', '
                    ),

                    na.address,
                    n.vlan_id,
                    n.mtu,
                    n.description,
                    n.subnet,
                    n.gateway
                FROM
                    network n
                LEFT OUTER JOIN storage_pool sp on n.storage_pool_id = sp.id
                LEFT OUTER JOIN network_attachments na on n.id = na.network_id
                LEFT OUTER JOIN vds_interface nic on na.nic_id = nic.id
                LEFT OUTER JOIN vds_static vs on nic.vds_id = vs.vds_id
                ORDER BY vs.vds_name, n.name
            );
        ELSE
            RETURN QUERY (
                SELECT
                    n.name,
                    vs.vds_name,
                    'NA',
                    sp.name,
                    nic.name,
                    CASE
                        WHEN nic.is_bond THEN (
                            SELECT 'Bond(slaves: '||string_agg(slave.name, ', ')||')'
                            FROM vds_interface slave
                            WHERE slave.bond_name = nic.name AND slave.vds_id=nic.vds_id)
                        WHEN n.vlan_id IS NOT NULL THEN 'VLAN' ELSE 'Regular NIC'
                    END,

                    ARRAY_TO_STRING(
                        ARRAY[nic.mac_addr,
                        (SELECT STRING_AGG(slave.mac_addr, ', ') FROM vds_interface slave WHERE slave.bond_name = nic.name AND slave.vds_id=nic.vds_id)],
                        ', '
                    ),

                    na.address,
                    n.vlan_id,
                    n.mtu,
                    n.description,
                    n.subnet,
                    n.gateway
                FROM
                    network n
                LEFT OUTER JOIN storage_pool sp on n.storage_pool_id = sp.id
                LEFT OUTER JOIN network_attachments na on n.id = na.network_id
                LEFT OUTER JOIN vds_interface nic on na.nic_id = nic.id
                LEFT OUTER JOIN vds_static vs on nic.vds_id = vs.vds_id
                ORDER BY vs.vds_name, n.name
            );

    END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;

COPY (
    SELECT
        row_number() OVER (ORDER BY vds_name, net_name NULLs last) AS "NO.",
        net_name AS "Network",
        vds_name AS "Host Name",
        vdsm_name AS "VDSM Name",
        sp_name AS "Data Center",
        nic_name AS "NIC Name",
        attached_to_nic_type AS "Attached to NIC Type",
        related_mac_addresses AS "Related MAC addresses",
        na_address AS "IPV4 Address",
        net_vlan_id AS "VLAN ID",
        net_mtu AS "MTU",
        net_description AS "Description",
        net_subnet AS "Subnet",
        net_gateway AS "Gateway"
    FROM
        __temp_network_using_network_attachments()
    ORDER BY vds_name, net_name
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;
DROP FUNCTION __temp_network_using_network_attachments();
