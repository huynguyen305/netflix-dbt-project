-- SELECT
--    movie_id,
--    tag_id,
--    relevance_score
-- FROM {{ ref('fct_genome_score') }}
-- WHERE relevance_score <= 0

{{ no_nulls_in_columns(ref('fct_genome_score'))}}