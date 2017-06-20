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
