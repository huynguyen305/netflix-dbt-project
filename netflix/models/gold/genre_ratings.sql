-- ====================================================
-- Analysis: Rating Distribution Across Genres
-- ====================================================
SELECT
    g.value::string AS genre,
    AVG(r.rating) AS average_rating,
    COUNT(DISTINCT m.movie_id) AS total_movies
FROM {{ ref('fct_ratings') }} r
JOIN {{ ref('dim_movies') }} m 
    ON r.movie_id = m.movie_id,
    LATERAL FLATTEN(input => m.genre_array) g
GROUP BY genre
ORDER BY average_rating DESC
