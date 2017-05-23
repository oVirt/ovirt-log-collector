SELECT
    option_id, option_name, option_value, version
FROM
    vdc_options
WHERE
    option_name ilike 'CheckMixedRhelVersions' AND
    option_value != 'true' AND
    version != 'general'
