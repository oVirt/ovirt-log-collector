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
CREATE OR REPLACE FUNCTION __temp_hosts_show_all()
  RETURNS TABLE(
      name VARCHAR(255),
      spm text,
      host_type varchar,
      cluster_name varchar(40),
      datacenter_name varchar(40),
      agent_address varchar(256),
      fqdn_ip varchar(256),
      vdsm text,
      kvm varchar(4000),
      libvirt text,
      spice varchar(4000),
      kernel varchar(4000),
      status varchar,
      host_os varchar(4000),
      vm_count integer,
      mem_available_mb bigint,
      mem_percent integer,
      cpu_percent integer,
      iscsi_initiator_name varchar(4000),
      selinux_enforce_mode text
) AS
$PROCEDURE$
BEGIN

    -- We might have cases where engine db's like 3.2, 3.3, 3.4, 3.5 have
    -- vds table with column ip and 3.6 or later with column agent_ip.
    --
    -- To avoid a second SQL query when going to compat mode let's
    -- change the column name in our own local temp. db.
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='vds' and column_name='ip') THEN
        ALTER TABLE vds RENAME COLUMN ip TO agent_ip;
    END IF;

    -- In the Engine db 4.0, vds_groups has been renamed
    -- to cluster.
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='cluster') THEN
        RETURN QUERY (
        SELECT
            v.vds_name AS "Name of Host",
            CASE WHEN sp.spm_vds_id=v.vds_id THEN 'SPM' ELSE 'Normal' END AS "SPM",
            coalesce(htt.text, 'Unknown (id='||v.vds_type||')') AS "Host Type",
            c.name AS "Cluster",
            sp.name AS "Data Center",
            v.agent_ip AS "Agent IP",
            v.host_name AS "FQDN or IP",
            regexp_replace(v.rpm_version, '[a-z]+.', '') AS "vdsm",
            v.kvm_version AS "qemu-kvm",
            regexp_replace(v.libvirt_version, '[a-z]+.', '') AS "libvirt",
            v.spice_version AS "spice",
            v.kernel_version AS "kernel",
            hst.text AS "Status",
            v.host_os AS "Operating System",
            v.vm_count AS "VM Count",
            v.mem_available AS "Available memory (MB)",
            v.usage_mem_percent AS "Used memory %",
            v.usage_cpu_percent AS "CPU load %",
            v.iscsi_initiator_name AS "ISCSI Initiator Name",
            -- selinux_enforce_mode
            COALESCE(
                CASE WHEN to_json(v)->>'selinux_enforce_mode'='0' THEN 'Permissive'
                     WHEN to_json(v)->>'selinux_enforce_mode'='1' THEN 'Enforcing'
                     WHEN to_json(v)->>'selinux_enforce_mode'='-1' THEN 'Disabled'
                END
                , 'Not Available'
            ) AS "SELinux"
            -- selinux_enforce_mode
        FROM
            vds v
        JOIN cluster c ON c.cluster_id=v.cluster_id
        LEFT OUTER JOIN storage_pool sp ON c.storage_pool_id = sp.id
        LEFT OUTER JOIN host_status_temp hst ON hst.id = v.status
        LEFT OUTER JOIN host_type_temp htt ON htt.id = v.vds_type
        ORDER BY c.name, v.vds_name
        );
    ELSE
        -- Compat mode, engine database < 4.0
        RETURN QUERY (
            SELECT
                v.vds_name AS "Name of Host",
                CASE WHEN sp.spm_vds_id=v.vds_id THEN 'SPM' ELSE 'Normal' END AS "SPM",
                coalesce(htt.text, 'Unknown (id='||v.vds_type||')') AS "Host Type",
                c.name AS "Cluster",
                sp.name AS "Data Center",
                v.agent_ip AS "Agent IP",
                v.host_name AS "FQDN or IP",
                regexp_replace(v.rpm_version, '[a-z]+.', '') AS "vdsm",
                v.kvm_version AS "qemu-kvm",
                regexp_replace(v.libvirt_version, '[a-z]+.', '') AS "libvirt",
                v.spice_version AS "spice",
                v.kernel_version AS "kernel",
                hst.text AS "Status",
                v.host_os AS "Operating System",
                v.vm_count AS "VM Count",
                v.mem_available AS "Available memory (MB)",
                v.usage_mem_percent AS "Used memory %",
                v.usage_cpu_percent AS "CPU load %",
                v.iscsi_initiator_name AS "ISCSI Initiator Name",
                -- selinux_enforce_mode
                COALESCE(
                    CASE WHEN to_json(v)->>'selinux_enforce_mode'='0' THEN 'Permissive'
                         WHEN to_json(v)->>'selinux_enforce_mode'='1' THEN 'Enforcing'
                         WHEN to_json(v)->>'selinux_enforce_mode'='-1' THEN 'Disabled'
                    END
                    , 'Not Available'
                ) AS "SELinux"
                -- selinux_enforce_mode
            FROM
                vds v
            JOIN vds_groups c ON c.vds_group_id=v.vds_group_id
            LEFT OUTER JOIN storage_pool sp ON c.storage_pool_id = sp.id
            LEFT OUTER JOIN host_status_temp hst ON hst.id = v.status
            LEFT OUTER JOIN host_type_temp htt ON htt.id = v.vds_type
            ORDER BY c.name, v.vds_name
            );
    END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;

COPY (
    SELECT
        row_number() OVER (ORDER BY name NULLs last) AS "NO.",
        spm AS "SPM",
        host_type AS "Host Type",
        cluster_name AS "Cluster",
        datacenter_name AS "Data Center",
        agent_address AS "Agent IP",
        fqdn_ip AS "FQDN or IP",
        vdsm AS "vdsm",
        kvm AS "qemu-kvm",
        libvirt AS "libvirt",
        spice AS "spice",
        kernel AS "kernel",
        status AS "Status",
        host_os AS "Operating System",
        vm_count AS "VM Count",
        mem_available_mb AS "Available memory (MB)",
        mem_percent AS "Used memory %",
        cpu_percent AS "CPU load %",
        iscsi_initiator_name AS "ISCSI Initiator Name",
        selinux_enforce_mode AS "SELinux"
    FROM
        __temp_hosts_show_all()
    ORDER BY name
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;

DROP FUNCTION __temp_hosts_show_all();
