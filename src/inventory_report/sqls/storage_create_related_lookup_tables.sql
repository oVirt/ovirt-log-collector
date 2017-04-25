CREATE table storage_type_temp (
    id NUMERIC, text varchar
);

INSERT INTO storage_type_temp VALUES
    (0, 'UNKNOWN'),
    (1, 'NFS'),
    (2, 'FCP'),
    (3, 'ISCSI'),
    (4, 'LOCALFS'),
    (6, 'POSIXFS'),
    (7, 'GLUSTERFS'),
    (8, 'GLANCE'),
    (9, 'CINDER');

CREATE table storage_domain_type_temp (
    id NUMERIC, text varchar
);

INSERT into storage_domain_type_temp VALUES
    (0, 'Master'),
    (1, 'Data'),
    (2, 'ISO'),
    (3, 'ImportExport'),
    (4, 'Image'),
    (5, 'Volume'),
    (6, 'Unknown');
