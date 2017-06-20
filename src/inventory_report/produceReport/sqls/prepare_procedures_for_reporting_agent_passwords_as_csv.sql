-- creates mapping id to name, both was taken from cluster or vds_groups table.
CREATE OR REPLACE FUNCTION __temp_cluster_id_to_name_map()
  RETURNS TABLE(vds_id uuid, vds_name VARCHAR(255), cluster_name VARCHAR(40)) AS
$PROCEDURE$
BEGIN

IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='cluster') THEN
  RETURN QUERY(
    SELECT
      vs.vds_id,
      vs.vds_name,
      c.name
    FROM
      vds_static vs
    JOIN
      cluster c ON c.cluster_id = vs.cluster_id
  );
ELSE
  RETURN QUERY(
    SELECT
      vs.vds_id,
      vs.vds_name,
      vg.name
    FROM
      vds_static vs
    JOIN
      vds_groups vg ON vg.vds_group_id = vs.vds_group_id
  );
END IF;

END; $PROCEDURE$
LANGUAGE plpgsql;

--reports mapping vds_id to password
CREATE OR REPLACE FUNCTION __temp_encrypted_fencing_passwords()
  RETURNS TABLE(vds_id uuid, password TEXT) AS
$PROCEDURE$
BEGIN
  -- for versions: <3.2, 3.5>
  IF EXISTS (SELECT column_name FROM information_schema.columns WHERE table_name = 'vds_static' AND column_name = 'pm_secondary_password') THEN
    RETURN QUERY (
      SELECT
        vs.vds_id,
        vs.pm_password
      FROM
        vds_static vs

      UNION

      SELECT
        vs.vds_id,
        vs.pm_secondary_password
      FROM
        vds_static vs
    );
  ELSE
    -- for versions: (…, 3.2)
    IF EXISTS (SELECT column_name FROM information_schema.columns WHERE table_name = 'vds_static' AND column_name = 'pm_password') THEN
      RETURN QUERY (
        SELECT
          vs.vds_id,
          vs.pm_password
        FROM
          vds_static vs
      );

    -- for versions: <3.6, …)
    ELSE
      RETURN QUERY (
          SELECT
            fa.vds_id,
            fa.agent_password
          FROM
            fence_agents fa
        );
    END IF;
  END IF;

END; $PROCEDURE$
LANGUAGE plpgsql;
