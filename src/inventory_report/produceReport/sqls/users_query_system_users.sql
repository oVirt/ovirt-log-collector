COPY (
    SELECT
        row_number() OVER (ORDER BY surname, name NULLs last) AS "NO.",
        name AS "First Name",
        surname AS "Last Name",
        username AS "User name",
        email AS "E-mail"
    FROM
        users
    ORDER BY surname, name
) TO STDOUT With CSV DELIMITER E'\|' HEADER;
