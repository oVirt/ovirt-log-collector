COPY (
    SELECT
        bookmark_name AS "Bookmark Name",
        bookmark_value AS "Bookmark Value"
    FROM
        bookmarks
) TO STDOUT WITH CSV DELIMITER E'\|' HEADER;
