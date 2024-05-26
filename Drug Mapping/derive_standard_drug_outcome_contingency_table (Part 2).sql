SET search_path TO faers;

-- Drop the contingency table if it exists
DROP TABLE IF EXISTS standard_drug_outcome_contingency_table;

-- Create the contingency table with CTEs
CREATE TABLE standard_drug_outcome_contingency_table AS
WITH
cte_d1 AS (
	SELECT drug_concept_id, outcome_concept_id, SUM(drug_outcome_pair_count) AS count_d1 
	FROM standard_drug_outcome_count
	GROUP BY drug_concept_id, outcome_concept_id
),
cte_ab AS (
	SELECT
		a.drug_concept_id,
		a.outcome_concept_id,
		a.drug_outcome_pair_count AS count_a,
		COALESCE(SUM(b.drug_outcome_pair_count), 0) AS count_b
	FROM standard_drug_outcome_count a
	LEFT JOIN standard_drug_outcome_count b
	ON a.drug_concept_id = b.drug_concept_id AND a.outcome_concept_id <> b.outcome_concept_id
	GROUP BY a.drug_concept_id, a.outcome_concept_id, a.drug_outcome_pair_count
),
cte_c AS (
	SELECT
		a.drug_concept_id,
		a.outcome_concept_id,
		COALESCE(SUM(c.drug_outcome_pair_count), 0) AS count_c
	FROM standard_drug_outcome_count a
	LEFT JOIN standard_drug_outcome_count c
	ON a.outcome_concept_id = c.outcome_concept_id AND a.drug_concept_id <> c.drug_concept_id
	GROUP BY a.drug_concept_id, a.outcome_concept_id
),
cte_d2 AS (
	SELECT
		a.drug_concept_id,
		a.outcome_concept_id,
		COALESCE(SUM(d2.drug_outcome_pair_count), 0) AS count_d2
	FROM standard_drug_outcome_count a
	LEFT JOIN standard_drug_outcome_count d2
	ON a.drug_concept_id = d2.drug_concept_id OR a.outcome_concept_id = d2.outcome_concept_id
	GROUP BY a.drug_concept_id, a.outcome_concept_id
)
SELECT
	ab.drug_concept_id,
	ab.outcome_concept_id,
	ab.count_a,
	ab.count_b,
	c.count_c,
	(d1.count_d1 - d2.count_d2) AS count_d
FROM cte_ab ab
JOIN cte_c c 
ON ab.drug_concept_id = c.drug_concept_id AND ab.outcome_concept_id = c.outcome_concept_id
JOIN cte_d1 d1 
ON ab.drug_concept_id = d1.drug_concept_id AND ab.outcome_concept_id = d1.outcome_concept_id
JOIN cte_d2 d2 
ON ab.drug_concept_id = d2.drug_concept_id AND ab.outcome_concept_id = d2.outcome_concept_id;
