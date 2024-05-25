SET search_path TO faers;

-- Optimize index creation by creating the indexes only once
DO $$
BEGIN
	IF NOT EXISTS (
		SELECT 1 FROM pg_class c 
		JOIN pg_namespace n ON n.oid = c.relnamespace 
		WHERE c.relname = 'standard_drug_outcome_count_ix' AND n.nspname = 'faers'
	) THEN
		CREATE INDEX standard_drug_outcome_count_ix 
		ON standard_drug_outcome_count(drug_concept_id, outcome_concept_id);
	END IF;

	IF NOT EXISTS (
		SELECT 1 FROM pg_class c 
		JOIN pg_namespace n ON n.oid = c.relnamespace 
		WHERE c.relname = 'standard_drug_outcome_count_2_ix' AND n.nspname = 'faers'
	) THEN
		CREATE INDEX standard_drug_outcome_count_2_ix 
		ON standard_drug_outcome_count(drug_concept_id);
	END IF;

	IF NOT EXISTS (
		SELECT 1 FROM pg_class c 
		JOIN pg_namespace n ON n.oid = c.relnamespace 
		WHERE c.relname = 'standard_drug_outcome_count_3_ix' AND n.nspname = 'faers'
	) THEN
		CREATE INDEX standard_drug_outcome_count_3_ix 
		ON standard_drug_outcome_count(outcome_concept_id);
	END IF;

	IF NOT EXISTS (
		SELECT 1 FROM pg_class c 
		JOIN pg_namespace n ON n.oid = c.relnamespace 
		WHERE c.relname = 'standard_drug_outcome_count_4_ix' AND n.nspname = 'faers'
	) THEN
		CREATE INDEX standard_drug_outcome_count_4_ix 
		ON standard_drug_outcome_count(drug_outcome_pair_count);
	END IF;
END $$;

-- Analyze the table for better query performance
ANALYZE VERBOSE standard_drug_outcome_count;

-- Combine all counts into a single query with CTEs
DROP TABLE IF EXISTS standard_drug_outcome_contingency_table;
CREATE TABLE standard_drug_outcome_contingency_table AS
WITH
cte_d1 AS (
	SELECT SUM(drug_outcome_pair_count) AS count_d1 
	FROM standard_drug_outcome_count
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
JOIN cte_d1 d1 ON TRUE
JOIN cte_d2 d2 
ON ab.drug_concept_id = d2.drug_concept_id AND ab.outcome_concept_id = d2.outcome_concept_id;
