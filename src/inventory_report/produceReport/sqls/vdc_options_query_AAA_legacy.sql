--- Based on: https://github.com/oVirt/ovirt-engine/blob/d1d0d67265313906dc85186ad4a9974b46abffdb/packaging/setup/plugins/ovirt-engine-setup/ovirt-engine/config/aaakerbldap.py#L64
COPY (
    SELECT
        option_value AS "Domain Name"
    FROM
        vdc_options
    WHERE
        option_name='DomainName'
    AND
        option_value <> ''
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;
