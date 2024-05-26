SET search_path = faers;

DROP TABLE IF EXISTS standard_drug_outcome_statistics;
CREATE TABLE standard_drug_outcome_statistics AS
SELECT 
    drug_concept_id, 
    outcome_concept_id, 
    CAST(NULL AS INTEGER) AS snomed_outcome_concept_id,
    count_a AS case_count,
    CASE 
        WHEN (count_c = 0 OR (count_a + count_b) = 0 OR (count_c + count_d) = 0 OR count_a <= 0 OR count_b <= 0 OR count_c <= 0 OR count_d <= 0) THEN NULL 
        ELSE ROUND(((count_a::float / (count_a + count_b)) / (count_c::float / (count_c + count_d)))::numeric, 5) 
    END AS prr,
    CASE 
        WHEN (count_c = 0 OR (count_a + count_b) = 0 OR (count_c + count_d) = 0 OR count_a <= 0 OR count_b <= 0 OR count_c <= 0 OR count_d <= 0) THEN NULL 
        ELSE ROUND(EXP(LN(((count_a::float / (count_a + count_b)) / (count_c::float / (count_c + count_d)))) + 1.96 * SQRT((1.0 / count_a) - (1.0 / (count_a + count_b)) + (1.0 / count_c) - (1.0 / (count_c + count_d))))::numeric, 5)
    END AS prr_95_percent_upper_confidence_limit,
    CASE 
        WHEN (count_c = 0 OR (count_a + count_b) = 0 OR (count_c + count_d) = 0 OR count_a <= 0 OR count_b <= 0 OR count_c <= 0 OR count_d <= 0) THEN NULL 
        ELSE ROUND(EXP(LN(((count_a::float / (count_a + count_b)) / (count_c::float / (count_c + count_d)))) - 1.96 * SQRT((1.0 / count_a) - (1.0 / (count_a + count_b)) + (1.0 / count_c) - (1.0 / (count_c + count_d))))::numeric, 5)
    END AS prr_95_percent_lower_confidence_limit,
    CASE 
        WHEN (count_c = 0 OR count_d = 0 OR count_b = 0 OR count_a = 0 OR count_a <= 0 OR count_b <= 0 OR count_c <= 0 OR count_d <= 0) THEN NULL 
        ELSE ROUND(((count_a::float / count_c) / (count_b::float / count_d))::numeric, 5)
    END AS ror,
    CASE 
        WHEN (count_c = 0 OR count_d = 0 OR count_b = 0 OR count_a = 0 OR count_a <= 0 OR count_b <= 0 OR count_c <= 0 OR count_d <= 0) THEN NULL 
        ELSE ROUND(EXP(LN(((count_a::float / count_c) / (count_b::float / count_d))) + 1.96 * SQRT((1.0 / count_a) + (1.0 / count_b) + (1.0 / count_c) + (1.0 / count_d)))::numeric, 5)
    END AS ror_95_percent_upper_confidence_limit,
    CASE 
        WHEN (count_c = 0 OR count_d = 0 OR count_b = 0 OR count_a = 0 OR count_a <= 0 OR count_b <= 0 OR count_c <= 0 OR count_d <= 0) THEN NULL 
        ELSE ROUND(EXP(LN(((count_a::float / count_c) / (count_b::float / count_d))) - 1.96 * SQRT((1.0 / count_a) + (1.0 / count_b) + (1.0 / count_c) + (1.0 / count_d)))::numeric, 5)
    END AS ror_95_percent_lower_confidence_limit
FROM 
    standard_drug_outcome_contingency_table;
