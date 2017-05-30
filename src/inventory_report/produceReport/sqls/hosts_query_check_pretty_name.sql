CREATE OR REPLACE FUNCTION __temp_hosts_check_pretty_name()
  RETURNS TABLE(vds_name VARCHAR(255)) AS
$PROCEDURE$
BEGIN
    /*
    This function finds if a host lacks the pretty name field value
    We are checking for 3 conditions
    1) Empty or NULL pretty_name value
    2) Host type is RHEL
    3) VDSM version is > 4.17.38
       such hosts are suspicious as NGN, but we cannot tell. To be sure, we need to reinstall them.

    The procedure converts the software_version field into integer
    It consider 3 possible version formats
    a) X.Y.Z
    b) X.Y.Z.W
    c) X.Y.Z-W

    where {X,Y,Z.W} are numbers
    */
    IF EXISTS (SELECT column_name
               FROM information_schema.columns
               WHERE table_name='vds_dynamic'
                   AND column_name='pretty_name')
               THEN
                   RETURN QUERY EXECUTE format('
                   SELECT
                       a.vds_name
                   FROM
                       vds_static a, vds_dynamic b
                   WHERE
                       a.vds_id = b.vds_id
                   AND cast(
                           replace(
                               replace(substring(b.software_version
                                   FROM ''[0-9]+[.][0-9]+[.][0-9]+[.-]*[0-9]*''), ''.'',''''
                               ),
                               ''-'',''''
                           )
                       as integer)  > 41738
                   AND (
                       b.pretty_name ISNULL
                       OR b.pretty_name = '''')
                   ');
    END IF;
END; $PROCEDURE$
LANGUAGE plpgsql;
SELECT __temp_hosts_check_pretty_name();
DROP FUNCTION __temp_hosts_check_pretty_name();
