SET search_path = faers;

DROP TABLE IF EXISTS meddra_snomed_mapping;

CREATE TABLE meddra_snomed_mapping AS
SELECT 
    z.SNOMED_CONCEPT_ID, 
    z.SNOMED_CONCEPT_NAME, 
    z.SNOMED_CONCEPT_CODE, 
    z.MEDDRA_CONCEPT_ID, 
    z.MEDDRA_CONCEPT_NAME, 
    z.MEDDRA_CONCEPT_CODE, 
    z.MEDDRA_CLASS_ID
FROM (
    SELECT 
        ca.max_levels_of_separation, 
        ca.min_levels_of_separation, 
        c.concept_id AS MEDDRA_CONCEPT_ID,
        c.concept_code AS MEDDRA_CONCEPT_CODE, 
        c.concept_name AS MEDDRA_CONCEPT_NAME, 
        c.concept_class_id AS MEDDRA_CLASS_ID,
        c2.concept_id AS SNOMED_CONCEPT_ID, 
        c2.concept_name AS SNOMED_CONCEPT_NAME, 
        c2.concept_code AS SNOMED_CONCEPT_CODE,
        ROW_NUMBER() OVER (
            PARTITION BY c.concept_id 
            ORDER BY ca.min_levels_of_separation, ca.max_levels_of_separation
        ) AS ROW_NUM
    FROM 
        cdmv5.concept c 
        JOIN cdmv5.concept_ancestor ca ON ca.ancestor_concept_id = c.concept_id
        JOIN cdmv5.concept c2 ON c2.concept_id = ca.descendant_concept_id
    WHERE 
        c.vocabulary_id = 'MedDRA'
        AND c.invalid_reason IS NULL
        AND c2.vocabulary_id = 'SNOMED'
        AND c2.concept_class_id = 'Clinical Finding'
        AND c2.invalid_reason IS NULL
) z
WHERE 
    z.ROW_NUM = 1;
