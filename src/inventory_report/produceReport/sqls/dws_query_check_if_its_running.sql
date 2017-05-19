SELECT
(
    SELECT
        replace(replace(var_value::varchar,'1','Yes'),'0','No')
    FROM
        dwh_history_timekeeping
    WHERE
        var_name = 'DwhCurrentlyRunning'
) AS "DWH running",
(
    SELECT
        var_value
    FROM
        dwh_history_timekeeping
    WHERE
        var_name = 'dwhHostname'
) AS "Host Name"
