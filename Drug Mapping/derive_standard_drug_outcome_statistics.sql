SET search_path = faers;

DROP TABLE IF EXISTS standard_drug_outcome_statistics;
CREATE TABLE standard_drug_outcome_statistics AS
SELECT 
    drug_concept_id, 
    outcome_concept_id, 
    CAST(NULL AS INTEGER) AS snomed_outcome_concept_id,
    count_a AS case_count,
    ROUND(
        CASE 
            WHEN (count_a + count_b) = 0 OR (count_c + count_d) = 0 THEN NULL
            ELSE (count_a / (count_a + count_b)) / (count_c / (count_c + count_d)) 
        END, 
    5) AS prr,
    ROUND(
        CASE 
            WHEN (count_a + count_b) = 0 OR (count_c + count_d) = 0 OR count_a = 0 THEN NULL
            ELSE EXP(LN((count_a / (count_a + count_b)) / (count_c / (count_c + count_d))) + 1.96 * SQRT((1.0 / count_a) - (1.0 / (count_a + count_b)) + (1.0 / count_c) - (1.0 / (count_c + count_d)))) 
        END, 
    5) AS prr_95_percent_upper_confidence_limit,
    ROUND(
        CASE 
            WHEN (count_a + count_b) = 0 OR (count_c + count_d) = 0 OR count_a = 0 THEN NULL
            ELSE EXP(LN((count_a / (count_a + count_b)) / (count_c / (count_c + count_d))) - 1.96 * SQRT((1.0 / count_a) - (1.0 / (count_a + count_b)) + (1.0 / count_c) - (1.0 / (count_c + count_d)))) 
        END, 
    5) AS prr_95_percent_lower_confidence_limit,
    ROUND(
        CASE 
            WHEN count_c = 0 OR count_d = 0 THEN NULL
            ELSE (count_a / count_c) / (count_b / count_d) 
        END, 
    5) AS ror,
    ROUND(
        CASE 
            WHEN count_c = 0 OR count_d = 0 OR count_a = 0 OR count_b = 0 THEN NULL
            ELSE EXP(LN((count_a / count_c) / (count_b / count_d)) + 1.96 * SQRT((1.0 / count_a) + (1.0 / count_b) + (1.0 / count_c) + (1.0 / count_d))) 
        END, 
    5) AS ror_95_percent_upper_confidence_limit,
    ROUND(
        CASE 
            WHEN count_c = 0 OR count_d = 0 OR count_a = 0 OR count_b = 0 THEN NULL
            ELSE EXP(LN((count_a / count_c) / (count_b / count_d)) - 1.96 * SQRT((1.0 / count_a) + (1.0 / count_b) + (1.0 / count_c) + (1.0 / count_d))) 
        END, 
    5) AS ror_95_percent_lower_confidence_limit
FROM 
    standard_drug_outcome_contingency_table
WHERE 
    count_a > 0 
    AND count_b > 0 
    AND count_c > 0 
    AND count_d > 0 
    AND (count_a + count_b) > 0 
    AND (count_c + count_d) > 0;
