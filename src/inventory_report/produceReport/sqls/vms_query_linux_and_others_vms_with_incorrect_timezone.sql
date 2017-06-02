CREATE TABLE timezone_temp (
    area VARCHAR(40),
    zone VARCHAR(60)
);

-- Timezones for Linux and Others VMs are the same, only Windows OS contain different timezones
-- Values defined in ovirt-engine project:
-- backend/manager/modules/common/src/main/java/org/ovirt/engine/core/common/TimeZoneType.java

INSERT INTO timezone_temp VALUES
    ('Etc/GMT', '(GMT+00:00) GMT Standard Time'),
    ('Asia/Kabul', '(GMT+04:30) Afghanistan Standard Time'),
    ('America/Anchorage', '(GMT-09:00) Alaskan Standard Time'),
    ('Asia/Riyadh', '(GMT+03:00) Arab Standard Time'),
    ('Asia/Dubai', '(GMT+04:00) Arabian Standard Time'),
    ('Asia/Baghdad', '(GMT+03:00) Arabic Standard Time'),
    ('America/Halifax', '(GMT-04:00) Atlantic Standard Time'),
    ('Atlantic/Azores', '(GMT-10:00) Azores Standard Time'),
    ('America/Regina', '(GMT-06:00) Canada Central Standard Time'),
    ('Atlantic/Cape_Verde', '(GMT-01:00) Cape Verde Standard Time'),
    ('Asia/Yerevan', '(GMT+04:00) Caucasus Standard Time'),
    ('Australia/Adelaide', '(GMT+09:30) Cen. Australia Standard Time'),
    ('Australia/Darwin', '(GMT+09:30) Cen. Australia Standard Time'),
    ('America/Guatemala', '(GMT-06:00) Central America Standard Time'),
    ('Asia/Almaty', '(GMT+06:00) Central Asia Standard Time'),
    ('Europe/Budapest', '(GMT+01:00) Central Europe Standard Time'),
    ('Europe/Warsaw', '(GMT+01:00) Central European Standard Time'),
    ('Pacific/Guadalcanal', '(GMT+11:00) Central Pacific Standard Time'),
    ('America/Chicago', '(GMT-06:00) Central Standard Time'),
    ('America/Mexico_City', '(GMT-06:00) Central Standard Time (Mexico)'),
    ('Asia/Shanghai', '(GMT+08:00) China Standard Time'),
    ('Etc/GMT+12', '(GMT-12:00) Dateline Standard Time'),
    ('Africa/Nairobi', '(GMT+03:00) E. Africa Standard Time'),
    ('Australia/Brisbane', '(GMT+10:00) E. Australia Standard Time'),
    ('Asia/Nicosia', '(GMT+02:00) E. Europe Standard Time'),
    ('America/Sao_Paulo', '(GMT-03:00) E. South America Standard Time'),
    ('America/New_York', '(GMT-05:00) Eastern Standard Time'),
    ('Africa/Cairo','(GMT+02:00) Egypt Standard Time'),
    ('Africa/Algiers', '(GMT+01:00) Algeria Standard Time'),
    ('Asia/Yekaterinburg', '(GMT+05:00) Ekaterinburg Standard Time'),
    ('Pacific/Fiji', '(GMT+12:00) Fiji Standard Time'),
    ('Europe/Kiev', '(GMT+02:00) FLE Standard Time'),
    ('Asia/Tbilisi', '(GMT+04:00) Georgian Standard Time'),
    ('Europe/London', '(GMT+00:00) London Standard Time'),
    ('America/Godthab', '(GMT-03:00) Greenland Standard Time'),
    ('Atlantic/Reykjavik', '(GMT+00:00) Iceland Standard Time'),
    ('Europe/Bucharest', '(GMT+02:00) GTB Standard Time'),
    ('Pacific/Honolulu', '(GMT-10:00) Hawaiian Standard Time'),
    ('Asia/Calcutta', '(GMT+05:30) India Standard Time'),
    ('Asia/Tehran', '(GMT+03:00) Iran Standard Time'),
    ('Asia/Jerusalem', '(GMT+02:00) Israel Standard Time'),
    ('Asia/Seoul', '(GMT+09:00) Korea Standard Time'),
    ('America/Denver', '(GMT-07:00) Mountain Standard Time'),
    ('Asia/Rangoon', '(GMT+06:30) Myanmar Standard Time'),
    ('Asia/Novosibirsk', '(GMT+06:00) N. Central Asia Standard Time'),
    ('Asia/Katmandu', '(GMT+05:45) Nepal Standard Time'),
    ('Pacific/Auckland', '(GMT+12:00) New Zealand Standard Time'),
    ('America/St_Johns', '(GMT-03:30) Newfoundland Standard Time'),
    ('Asia/Irkutsk', '(GMT+08:00) North Asia East Standard Time'),
    ('Asia/Krasnoyarsk', '(GMT+07:00) North Asia Standard Time'),
    ('America/Santiago', '(GMT+04:00) Pacific SA Standard Time'),
    ('America/Los_Angeles', '(GMT-08:00) Pacific Standard Time'),
    ('Europe/Paris', '(GMT+01:00) Romance Standard Time'),
    ('Europe/Moscow', '(GMT+03:00) Russian Standard Time'),
    ('America/Cayenne', '(GMT-03:00) SA Eastern Standard Time'),
    ('America/Bogota', '(GMT-05:00) SA Pacific Standard Time'),
    ('America/La_Paz', '(GMT-04:00) SA Western Standard Time'),
    ('Pacific/Apia', '(GMT-11:00) Samoa Standard Time'),
    ('Asia/Bangkok', '(GMT+07:00) SE Asia Standard Time'),
    ('Africa/Johannesburg', '(GMT+02:00) South Africa Standard Time'),
    ('Asia/Colombo', '(GMT+05:30) Sri Lanka Standard Time'),
    ('Asia/Taipei', '(GMT+08:00) Taipei Standard Time'),
    ('Australia/Hobart', '(GMT+10:00) Tasmania Standard Time'),
    ('Asia/Tokyo', '(GMT+09:00) Tokyo Standard Time'),
    ('Pacific/Tongatapu', '(GMT+13:00) Tonga Standard Time'),
    ('America/Indianapolis', '(GMT-05:00) US Eastern Standard Time (Indiana)'),
    ('America/Phoenix', '(GMT-07:00) US Mountain Standard Time (Arizona)'),
    ('Asia/Vladivostok', '(GMT+10:00) Vladivostok Standard Time'),
    ('Australia/Perth', '(GMT+08:00) W. Australia Standard Time'),
    ('Africa/Lagos', '(GMT+01:00) W. Central Africa Standard Time'),
    ('Europe/Berlin', '(GMT+01:00) W. Europe Standard Time'),
    ('Asia/Tashkent', '(GMT+05:00) West Asia Standard Time'),
    ('Pacific/Port_Moresby', '(GMT+10:00) West Pacific Standard Time'),
    ('Asia/Yakutsk', '(GMT+09:00) Yakutsk Standard Time'),
    ('America/Caracas', '(GMT-04:30) Venezuelan Standard Time')
;

-- Values defined in ovirt-engine project:
-- packaging/conf/osinfo-defaults.properties
--
-- 0 - OtherOS
-- 5 - OtherLinux
-- 7 - RHEL5
-- 8 - RHEL4
-- 9 - RHEL3
-- 13 - RHEL5x64
-- 14 - RHEL4x64
-- 15 - RHEL3x64
-- 18 - RHEL6
-- 19 - RHEL6x64
-- 24 - RHEL7x64
-- 28 - RHEL_ATOMIC7x64
-- 1193 - SUSE Linux Enterprise Server 11
-- 1252 - Ubuntu Precise Pangolin LTS
-- 1253 - Ubuntu Quantal Quetzal
-- 1254 - Ubuntu Raring Ringtails
-- 1255 - Ubuntu Saucy Salamander
-- 1256 - Ubuntu Trusty Tahr LTS
-- 1300 - Debian 7
-- 1500 - FreeBSD 9.2
-- 1501 - FreeBSD 9.2 x64
-- 1001 - OtherOS PPC64
-- 1002 - OtherLinux PPC64
-- 1003 - RHEL6 PPC64
-- 1004 - SUSE Linux Enterprise Server 11 PPC64
-- 1005 - Ubuntu Trusty Tahr LTS PPC64
-- 1006 - Red Hat Enterprise Linux 7.x PPC64

WITH vms_linux_and_other_timezone AS (
    SELECT
        vm_name, time_zone
    FROM
        vm_static
    WHERE
        os IN (
            0,
            5,
            7,
            8,
            9,
           13,
           14,
           15,
           18,
           19,
           24,
           28,
           1193,
           1252,
           1253,
           1254,
           1255,
           1256,
           1300,
           1500,
           1501,
           1001,
           1002,
           1003,
           1004,
           1005,
           1006
    )
)

SELECT
    vm_name AS "VM Name",
    time_zone AS "Time Zone"
FROM
    vms_linux_and_other_timezone
WHERE
    time_zone NOT IN
    (
    SELECT area FROM timezone_temp
    );

DROP TABLE timezone_temp;
