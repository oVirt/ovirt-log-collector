CREATE OR REPLACE FUNCTION __temp_mac_pools()
  RETURNS TABLE(cluster_name VARCHAR(40),mac_name VARCHAR(255), mac_desc VARCHAR(4000), mac_dup boolean, mac_default_pool boolean, range text) AS
$PROCEDURE$
BEGIN
    -- In the Engine db 3.6 (or higher), mac_pools has been added
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='mac_pools') THEN
        IF EXISTS (SELECT column_name
                   FROM information_schema.columns
                   WHERE table_name='cluster') THEN
            RETURN QUERY (
            SELECT
                cluster.name AS "Cluster",
                mac_pools.name AS "Name",
                mac_pools.description AS "Description",
                mac_pools.allow_duplicate_mac_addresses AS "Allow Duplicate MAC Address",
                mac_pools.default_pool AS "Default Pool",
                (SELECT string_agg('('||mpr.from_mac||'—'||mpr.to_mac||')', ', ') FROM mac_pool_ranges mpr WHERE mpr.mac_pool_id=mac_pools.id) AS "MAC Pool Ranges"
            FROM
                mac_pools
            -- In recent db, mac_pool_id is not a column in storage_pool
            INNER JOIN cluster ON cluster.mac_pool_id=mac_pools.id ORDER BY cluster.name
            );
        ELSE
            -- Compat mode, engine db < 4
            RETURN QUERY (
            SELECT
                vds_groups.name AS "Cluster",
                mac_pools.name AS "Name",
                mac_pools.description AS "Description",
                mac_pools.allow_duplicate_mac_addresses AS "Allow Duplicate MAC Address",
                mac_pools.default_pool AS "Default Pool",
                (SELECT string_agg('('||mpr.from_mac||'—'||mpr.to_mac||')', ', ') FROM mac_pool_ranges mpr WHERE mpr.mac_pool_id=mac_pools.id) AS "MAC Pool Ranges"
            FROM
                mac_pools
            INNER JOIN storage_pool ON storage_pool.mac_pool_id=mac_pools.id
            INNER JOIN vds_groups ON vds_groups.storage_pool_id=storage_pool.id
            INNER JOIN mac_pool_ranges ON mac_pool_ranges.mac_pool_id=mac_pools.id ORDER BY vds_groups.name
            );

        END IF;
    END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;

COPY (
  SELECT
      row_number() OVER (ORDER BY cluster_name NULLs last) AS "NO.",
      cluster_name AS "Cluster",
      mac_name AS "Name",
      mac_desc AS "Description",
      CASE WHEN mac_dup THEN 'Yes' ELSE 'No' END AS "Allow Duplicate MAC Addresses",
      CASE WHEN mac_default_pool THEN 'Yes' ELSE 'No' END AS "Default Pool",
      range AS "MAC Pool Ranges"
  FROM
      __temp_mac_pools()
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;

DROP FUNCTION __temp_mac_pools();
