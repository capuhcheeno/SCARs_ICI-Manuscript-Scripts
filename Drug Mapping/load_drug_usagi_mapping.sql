INSERT INTO faers.drug_usagi_mapping
SELECT 
    a.source_code_description AS drug_name_original, 
    b.concept_name, 
    b.concept_class_id, 
    CAST(a.target_concept_id AS INTEGER) AS concept_id, 
    CAST('usagi' AS TEXT) AS update_method
FROM 
    faers.usagi_import a
INNER JOIN 
    cdmv5.concept b
ON 
    CAST(a.target_concept_id AS INTEGER) = b.concept_id::text::integer
WHERE
    a.target_concept_id ~ '^[0-9]+$';
