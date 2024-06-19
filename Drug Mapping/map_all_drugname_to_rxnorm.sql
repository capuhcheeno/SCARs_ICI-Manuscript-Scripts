-- Optimized Script for Mapping Drug Names to RxNorm Vocabulary

-- Set schema and create index on concept table
SET search_path = cdmv5;
DROP INDEX IF EXISTS vocab_concept_name_ix;
CREATE INDEX vocab_concept_name_ix ON concept(vocabulary_id, standard_concept, UPPER(concept_name), concept_id);
ANALYZE VERBOSE concept;
DO $$ BEGIN RAISE NOTICE 'Index on concept table created.'; END $$;

SET search_path = faers;

-- Create mapping table and clean up drug names
DROP TABLE IF EXISTS drug_regex_mapping;
CREATE TABLE drug_regex_mapping AS
SELECT DISTINCT drugname AS drug_name_original, UPPER(drugname) AS drug_name_clean, NULL::INTEGER AS concept_id, NULL AS update_method
FROM (
  SELECT drugname FROM drug INNER JOIN unique_all_case ON drug.primaryid = unique_all_case.primaryid WHERE unique_all_case.isr IS NULL
  UNION
  SELECT drugname FROM drug_legacy INNER JOIN unique_all_case ON drug_legacy.isr = unique_all_case.isr WHERE unique_all_case.isr IS NOT NULL
) aa;
DO $$ BEGIN RAISE NOTICE 'Mapping table drug_regex_mapping created.'; END $$;

-- Create index on the mapping table
DROP INDEX IF EXISTS drug_name_clean_ix;
CREATE INDEX drug_name_clean_ix ON drug_regex_mapping(drug_name_clean);
DO $$ BEGIN RAISE NOTICE 'Index on drug_regex_mapping created.'; END $$;

-- Cleanup and map drug names
DO $$ 
DECLARE
  update_patterns TEXT[] := ARRAY[
    '((.*)(\W|^)\(TABLETS?\)|TABLETS?(\W|$))', 
    '((.*)(\W|^)\(CAPSULES?\)|CAPSULES?(\W|$))', 
    '(\(*(\y\d*\.*\d*\ *MG\,*\ *\/*\\*\ *\d*\.*\d*\ *(M2|ML)*\ *\,*\+*\ *\y)\)*)', 
    '(\(*(\y\d*\.*\d*\ *MILLIGRAMS?\,*\ *\/*\\*\ *\d*\.*\d*\ *(M2|MILLILITERS?)*\ *\,*\+*\ *\y)\)*)', 
    '((\y\ *(HCL|HYDROCHLORIDE)\y))', 
    '\((\y(FORMULATION|GENERIC|NOS)\y\)|\y(FORMULATION|GENERIC|NOS)\y)', 
    '[( \.\,]$', 
    '(\S) +', 
    ' +$', 
    '^ +', 
    '[''""]', 
    '[\*\^\$\?]', 
    '\\', 
    ' +\)', 
    '\((\ \yUNKNOWN|UNK\y)\)|\(\y(UNKNOWN|UNK)\y\)|\y(UNKNOWN|UNK)\y', 
    ' *blinded *', 
    '\/\d+\/\ *'
  ];
  update_methods TEXT[] := ARRAY[
    'regex remove keywords', 
    'regex EU drug name to active ingredient', 
    'regex EU drug name in parentheses to active ingredient', 
    'regex ingredient name in parentheses', 
    'regex upper', 
    'regex trailing space or period chars', 
    'regex remove multiple white space', 
    'regex remove trailing spaces', 
    'regex remove leading spaces', 
    'regex remove single quotes', 
    'regex remove ^*$? punctuation chars', 
    'regex change forward slash to back slash', 
    'regex remove spaces before closing parenthesis', 
    'regex vitamins', 
    'regex remove (unknown)', 
    'regex remove blinded', 
    'regex remove /nnnnn/'
  ];
BEGIN
  FOR i IN 1..array_length(update_patterns, 1) LOOP
    EXECUTE format('
      UPDATE drug_regex_mapping
      SET drug_name_clean = regexp_replace(drug_name_clean, %L, ''\1'', ''gi'')
      WHERE concept_id IS NULL AND drug_name_clean ~* %L;', update_patterns[i], update_patterns[i]);
    RAISE NOTICE 'Pattern % updated.', update_patterns[i];
  END LOOP;

  -- Map exact matches after keyword removal
  FOR i IN 1..array_length(update_methods, 1) LOOP
    EXECUTE format('
      UPDATE drug_regex_mapping a
      SET update_method = %L, concept_id = b.concept_id::INTEGER
      FROM cdmv5.concept b
      WHERE b.vocabulary_id = ''RxNorm'' AND UPPER(b.concept_name) = a.drug_name_clean
      AND a.concept_id IS NULL;', update_methods[i]);
    RAISE NOTICE 'Mapping method % applied.', update_methods[i];
  END LOOP;
END $$;

-- Map vitamins
UPDATE drug_regex_mapping a
SET drug_name_clean = 'MULTIVITAMIN PREPARATION'
WHERE drug_name_clean LIKE '%VITAMIN%' 
  AND NOT drug_name_clean LIKE ALL (ARRAY['%VITAMIN A%', '%VITAMIN B%', '%VITAMIN C%', '%VITAMIN K%', '%VITAMIN D%', '%VITAMIN E%'])
  AND concept_id IS NULL;
DO $$ BEGIN RAISE NOTICE 'Vitamin mappings applied.'; END $$;

-- Create mapping tables for multi-ingredient and single-ingredient drugs
DROP TABLE IF EXISTS drug_regex_mapping_words, rxnorm_mapping_multi_ingredient_list, drug_mapping_multi_ingredient_list, rxnorm_mapping_single_ingredient_list, drug_mapping_single_ingredient_list;
CREATE TABLE drug_regex_mapping_words AS
SELECT DISTINCT
  drug_name_original,
  concept_name,
  concept_id,
  update_method,
  word
FROM (
  SELECT 
    drug_name_original,
    concept_name,
    concept_id,
    update_method,
    unnest(regexp_split_to_array(UPPER(drug_name_original), E'[ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"''\?\<\>\&\!\*\_\+\=]+')) AS word
  FROM (
    SELECT 
      drugname AS drug_name_original,
      NULL::VARCHAR AS concept_name,
      NULL::INTEGER AS concept_id,
      NULL AS update_method
    FROM drug 
    INNER JOIN unique_all_case 
    ON drug.primaryid = unique_all_case.primaryid 
    WHERE unique_all_case.isr IS NULL
    UNION
    SELECT 
      drugname AS drug_name_original,
      NULL::VARCHAR AS concept_name,
      NULL::INTEGER AS concept_id,
      NULL AS update_method
    FROM drug_legacy 
    INNER JOIN unique_all_case 
    ON drug_legacy.isr = unique_all_case.isr 
    WHERE unique_all_case.isr IS NOT NULL
  ) aa
) bb
WHERE word NOT IN ('', 'SYRUP', 'HCL', 'HYDROCHLORIDE', 'ACETIC', 'SODIUM', 'CALCIUM', 'SULPHATE', 'MONOHYDRATE') 
  AND word NOT IN (
    SELECT DISTINCT unnest(regexp_split_to_array(UPPER(concept_name), E'[ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"''\?\<\>\&\!\*\_\+\=]+'))
    FROM cdmv5.concept
    WHERE vocabulary_id = 'RxNorm' AND concept_class_id = 'Dose Form'
  );
DO $$ BEGIN RAISE NOTICE 'Mapping table drug_regex_mapping_words created.'; END $$;

-- Map multi-ingredient drugs
CREATE TABLE rxnorm_mapping_multi_ingredient_list AS
SELECT ingredient_list, MAX(concept_id) AS concept_id, MAX(concept_name) AS concept_name
FROM (
  SELECT concept_id, concept_name, string_agg(word, ' ' ORDER BY word) AS ingredient_list
  FROM (
    SELECT concept_id, concept_name, unnest(regexp_split_to_array(UPPER(concept_name), E'[ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"''\?\<\>\&\!\*\_\+\=]+')) AS word
    FROM cdmv5.concept
    WHERE vocabulary_id = 'RxNorm' AND concept_class_id = 'Clinical Drug Form' AND concept_name LIKE '%/%'
  ) aa
  WHERE word NOT IN ('')
    AND word NOT IN (
      SELECT DISTINCT unnest(regexp_split_to_array(UPPER(concept_name), E'[ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"''\?\<\>\&\!\*\_\+\=]+'))
      FROM cdmv5.concept WHERE vocabulary_id = 'RxNorm' AND concept_class_id = 'Dose Form'
    )
    AND word NOT IN ('-', ' ', 'A', 'AND', 'EX', '10A', '11A', '12F', '18C', '19F', '99M', 'G', 'G1', 'G2', 'G3', 'G4', 'H', 'I', 'IN', 'JELLY', 'LEAF', 'O', 'OF', 'OR', 'P', 'S', 'T', 'V', 'WITH', 'X', 'Y', 'Z')
    AND word !~ '^\d+$|\y\d+\-\d+\y|\y\d+\.\d+\y'
  GROUP BY concept_id, concept_name
) bb
GROUP BY ingredient_list;
DO $$ BEGIN RAISE NOTICE 'Mapping table rxnorm_mapping_multi_ingredient_list created.'; END $$;

CREATE TABLE drug_mapping_multi_ingredient_list AS
SELECT drug_name_original, ingredient_list, MAX(concept_id) AS concept_id, MAX(concept_name) AS concept_name
FROM (
  SELECT concept_id, drug_name_original, concept_name, string_agg(word, ' ' ORDER BY word) AS ingredient_list
  FROM (
    SELECT concept_id, drug_name_original, concept_name, unnest(regexp_split_to_array(UPPER(drug_name_original), E'[ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"''\?\<\>\&\!\*\_\+\=]+')) AS word
    FROM (
      SELECT drugname AS drug_name_original, NULL::VARCHAR AS concept_name, NULL::INTEGER AS concept_id, NULL AS update_method
      FROM drug INNER JOIN unique_all_case ON drug.primaryid = unique_all_case.primaryid WHERE unique_all_case.isr IS NULL
      UNION
      SELECT drugname AS drug_name_original, NULL::VARCHAR AS concept_name, NULL::INTEGER AS concept_id, NULL AS update_method
      FROM drug_legacy INNER JOIN unique_all_case ON drug_legacy.isr = unique_all_case.isr WHERE unique_all_case.isr IS NOT NULL
    ) aa
  ) bb
  WHERE word NOT IN ('')
    AND word NOT IN (
      SELECT DISTINCT unnest(regexp_split_to_array(UPPER(concept_name), E'[ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"''\?\<\>\&\!\*\_\+\=]+'))
      FROM cdmv5.concept WHERE vocabulary_id = 'RxNorm' AND concept_class_id = 'Dose Form'
    )
    AND word IN (
      SELECT word
      FROM (
        SELECT DISTINCT unnest(regexp_split_to_array(UPPER(concept_name), E'[ \,\(\)\{\}\\\\/\^\%\~\`\@\#\$\;\:\"''\?\<\>\&\!\*\_\+\=]+')) AS word
        FROM cdmv5.concept WHERE vocabulary_id = 'RxNorm' AND concept_class_id IN ('Clinical Drug Form')
      ) aa
      WHERE word NOT IN ('-', ' ', 'A', 'AND', 'EX', '10A', '11A', '12F', '18C', '19F', '99M', 'G', 'G1', 'G2', 'G3', 'G4', 'H', 'I', 'IN', 'JELLY', 'LEAF', 'O', 'OF', 'OR', 'P', 'S', 'T', 'V', 'WITH', 'X', 'Y', 'Z')
        AND word !~ '^\d+$|\y\d+\-\d+\y|\y\d+\.\d+\y'
      ORDER BY 1
    )
  GROUP BY concept_id, drug_name_original, concept_name
) cc
GROUP BY drug_name_original, ingredient_list;
DO $$ BEGIN RAISE NOTICE 'Mapping table drug_mapping_multi_ingredient_list created.'; END $$;

UPDATE drug_regex_mapping_words c
SET update_method = 'multiple ingredient match', concept_name = b.concept_name, concept_id = b.concept_id::INTEGER
FROM (
  SELECT a.drug_name_original, MAX(UPPER(b1.concept_name)) AS concept_name, MAX(b1.concept_id) AS concept_id
  FROM drug_mapping_multi_ingredient_list a
  INNER JOIN rxnorm_mapping_multi_ingredient_list b1 ON a.ingredient_list = b1.ingredient_list
  GROUP BY a.drug_name_original
) b
WHERE c.drug_name_original = b.drug_name_original AND c.concept_id IS NULL;
DO $$ BEGIN RAISE NOTICE 'Multi-ingredient mappings applied.'; END $$;

-- Map single-ingredient drugs
CREATE TABLE rxnorm_mapping_single_ingredient_list AS
SELECT ingredient_list, MAX(concept_id) AS concept_id, MAX(concept_name) AS concept_name
FROM (
  SELECT concept_id, concept_name, string_agg(word, ' ' ORDER BY word) AS ingredient_list
  FROM (
    SELECT concept_id, concept_name, unnest(regexp_split_to_array(UPPER(concept_name), E'[ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"''\?\<\>\&\!\*\_\+\=]+')) AS word
    FROM cdmv5.concept
    WHERE vocabulary_id = 'RxNorm' AND concept_class_id = 'Ingredient'
  ) aa
  WHERE word NOT IN ('')
    AND word NOT IN (
      SELECT DISTINCT unnest(regexp_split_to_array(UPPER(concept_name), E'[ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"''\?\<\>\&\!\*\_\+\=]+'))
      FROM cdmv5.concept WHERE vocabulary_id = 'RxNorm' AND concept_class_id = 'Dose Form'
    )
    AND word NOT IN ('-', ' ', 'A', 'AND', 'EX', '10A', '11A', '12F', '18C', '19F', '99M', 'G', 'G1', 'G2', 'G3', 'G4', 'H', 'I', 'IN', 'JELLY', 'LEAF', 'O', 'OF', 'OR', 'P', 'S', 'T', 'V', 'WITH', 'X', 'Y', 'Z')
    AND word !~ '^\d+$|\y\d+\-\d+\y|\y\d+\.\d+\y'
  GROUP BY concept_id, concept_name
) bb
GROUP BY ingredient_list;
DO $$ BEGIN RAISE NOTICE 'Mapping table rxnorm_mapping_single_ingredient_list created.'; END $$;

CREATE TABLE drug_mapping_single_ingredient_list AS
SELECT drug_name_original, ingredient_list, MAX(concept_id) AS concept_id, MAX(concept_name) AS concept_name
FROM (
  SELECT concept_id, drug_name_original, concept_name, string_agg(word, ' ' ORDER BY word) AS ingredient_list
  FROM (
    SELECT concept_id, drug_name_original, concept_name, unnest(regexp_split_to_array(UPPER(drug_name_original), E'[ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"''\?\<\>\&\!\*\_\+\=]+')) AS word
    FROM (
      SELECT drugname AS drug_name_original, NULL::VARCHAR AS concept_name, NULL::INTEGER AS concept_id, NULL AS update_method
      FROM drug INNER JOIN unique_all_case ON drug.primaryid = unique_all_case.primaryid WHERE unique_all_case.isr IS NULL AND drugname NOT LIKE '%/%' AND drugname NOT LIKE '% AND %' AND drugname NOT LIKE '% WITH %' AND drugname NOT LIKE '%+%'
      UNION
      SELECT drugname AS drug_name_original, NULL::VARCHAR AS concept_name, NULL::INTEGER AS concept_id, NULL AS update_method
      FROM drug_legacy INNER JOIN unique_all_case ON drug_legacy.isr = unique_all_case.isr WHERE unique_all_case.isr IS NOT NULL AND drugname NOT LIKE '%/%' AND drugname NOT LIKE '% AND %' AND drugname NOT LIKE '% WITH %' AND drugname NOT LIKE '%+%'
    ) aa
  ) bb
  WHERE word NOT IN ('')
    AND word NOT IN (
      SELECT DISTINCT unnest(regexp_split_to_array(UPPER(concept_name), E'[ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"''\?\<\>\&\!\*\_\+\=]+'))
      FROM cdmv5.concept WHERE vocabulary_id = 'RxNorm' AND concept_class_id = 'Dose Form'
    )
    AND word IN (
      SELECT word
      FROM (
        SELECT DISTINCT unnest(regexp_split_to_array(UPPER(concept_name), E'[ \,\(\)\{\}\\\\/\^\%\~\`\@\#\$\;\:\"''\?\<\>\&\!\*\_\+\=]+')) AS word
        FROM cdmv5.concept WHERE vocabulary_id = 'RxNorm' AND concept_class_id = 'Ingredient'
      ) aa
      WHERE word NOT IN ('-', ' ', 'A', 'AND', 'EX', '10A', '11A', '12F', '18C', '19F', '99M', 'G', 'G1', 'G2', 'G3', 'G4', 'H', 'I', 'IN', 'JELLY', 'LEAF', 'O', 'OF', 'OR', 'P', 'S', 'T', 'V', 'WITH', 'X', 'Y', 'Z')
        AND word !~ '^\d+$|\y\d+\-\d+\y|\y\d+\.\d+\y'
      ORDER BY 1
    )
  GROUP BY concept_id, drug_name_original, concept_name
) cc
GROUP BY drug_name_original, ingredient_list;
DO $$ BEGIN RAISE NOTICE 'Mapping table drug_mapping_single_ingredient_list created.'; END $$;

UPDATE drug_regex_mapping_words c
SET update_method = 'single ingredient match', concept_name = b.concept_name, concept_id = b.concept_id::INTEGER
FROM (
  SELECT a.drug_name_original, MAX(UPPER(b1.concept_name)) AS concept_name, MAX(b1.concept_id) AS concept_id
  FROM drug_mapping_single_ingredient_list a
  INNER JOIN rxnorm_mapping_single_ingredient_list b1 ON a.ingredient_list = b1.ingredient_list
  GROUP BY a.drug_name_original
) b
WHERE c.drug_name_original = b.drug_name_original 
  AND c.update_method IS NULL 
  AND b.concept_name NOT IN ('VITAMIN A', 'SODIUM', 'HYDROCHLORIDE', 'HCL', 'CALCIUM', 'COLD CREAM', 'VITAMIN B 12', 'MALEATE', 'TARTRATE', 'MESYLATE', 'MONOHYDRATE', 'SUCCINATE', 'CORN SYRUP', 'FACTOR X', 'PROTEIN S');
DO $$ BEGIN RAISE NOTICE 'Single-ingredient mappings applied.'; END $$;

-- Map brand names
DROP TABLE IF EXISTS rxnorm_mapping_brand_name_list;
CREATE TABLE rxnorm_mapping_brand_name_list AS
SELECT ingredient_list, MAX(concept_id) AS concept_id, MAX(concept_name) AS concept_name
FROM (
  SELECT concept_id, concept_name, string_agg(word, ' ' ORDER BY word) AS ingredient_list
  FROM (
    SELECT concept_id, concept_name, unnest(regexp_split_to_array(UPPER(concept_name), E'[ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"''\?\<\>\&\!\*\_\+\=]+')) AS word
    FROM cdmv5.concept
    WHERE vocabulary_id = 'RxNorm' AND concept_class_id = 'Brand Name'
  ) aa
  WHERE word NOT IN ('')
    AND word NOT IN (
      SELECT DISTINCT unnest(regexp_split_to_array(UPPER(concept_name), E'[ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"''\?\<\>\&\!\*\_\+\=]+'))
      FROM cdmv5.concept WHERE vocabulary_id = 'RxNorm' AND concept_class_id = 'Dose Form'
    )
    AND word NOT IN ('-', ' ', 'A', 'AND', 'EX', '10A', '11A', '12F', '18C', '19F', '99M', 'G', 'G1', 'G2', 'G3', 'G4', 'H', 'I', 'IN', 'JELLY', 'LEAF', 'O', 'OF', 'OR', 'P', 'S', 'T', 'V', 'WITH', 'X', 'Y', 'Z')
    AND word !~ '^\d+$|\y\d+\-\d+\y|\y\d+\.\d+\y'
  GROUP BY concept_id, concept_name
) bb
GROUP BY ingredient_list;
DO $$ BEGIN RAISE NOTICE 'Mapping table rxnorm_mapping_brand_name_list created.'; END $$;

DROP TABLE IF EXISTS drug_mapping_brand_name_list;
CREATE TABLE drug_mapping_brand_name_list AS
SELECT drug_name_original, ingredient_list, MAX(concept_id) AS concept_id, MAX(concept_name) AS concept_name
FROM (
  SELECT concept_id, drug_name_original, concept_name, string_agg(word, ' ' ORDER BY word) AS ingredient_list
  FROM (
    SELECT concept_id, drug_name_original, concept_name, unnest(regexp_split_to_array(UPPER(drug_name_original), E'[ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"''\?\<\>\&\!\*\_\+\=]+')) AS word
    FROM (
      SELECT drugname AS drug_name_original, NULL::VARCHAR AS concept_name, NULL::INTEGER AS concept_id, NULL AS update_method
      FROM drug INNER JOIN unique_all_case ON drug.primaryid = unique_all_case.primaryid WHERE unique_all_case.isr IS NULL AND drugname NOT LIKE '%/%' AND drugname NOT LIKE '% AND %' AND drugname NOT LIKE '% WITH %' AND drugname NOT LIKE '%+%'
      UNION
      SELECT drugname AS drug_name_original, NULL::VARCHAR AS concept_name, NULL::INTEGER AS concept_id, NULL AS update_method
      FROM drug_legacy INNER JOIN unique_all_case ON drug_legacy.isr = unique_all_case.isr WHERE unique_all_case.isr IS NOT NULL AND drugname NOT LIKE '%/%' AND drugname NOT LIKE '% AND %' AND drugname NOT LIKE '% WITH %' AND drugname NOT LIKE '%+%'
    ) aa
  ) bb
  WHERE word NOT IN ('')
    AND word NOT IN (
      SELECT DISTINCT unnest(regexp_split_to_array(UPPER(concept_name), E'[ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"''\?\<\>\&\!\*\_\+\=]+'))
      FROM cdmv5.concept WHERE vocabulary_id = 'RxNorm' AND concept_class_id = 'Dose Form'
    )
    AND word IN (
      SELECT word
      FROM (
        SELECT DISTINCT unnest(regexp_split_to_array(UPPER(concept_name), E'[ \,\(\)\{\}\\\\/\^\%\~\`\@\#\$\;\:\"''\?\<\>\&\!\*\_\+\=]+')) AS word
        FROM cdmv5.concept WHERE vocabulary_id = 'RxNorm' AND concept_class_id = 'Brand Name'
      ) aa
      WHERE word NOT IN ('-', ' ', 'A', 'AND', 'EX', '10A', '11A', '12F', '18C', '19F', '99M', 'G', 'G1', 'G2', 'G3', 'G4', 'H', 'I', 'IN', 'JELLY', 'LEAF', 'O', 'OF', 'OR', 'P', 'S', 'T', 'V', 'WITH', 'X', 'Y', 'Z')
        AND word !~ '^\d+$|\y\d+\-\d+\y|\y\d+\.\d+\y'
      ORDER BY 1
    )
  GROUP BY concept_id, drug_name_original, concept_name
) cc
GROUP BY drug_name_original, ingredient_list;
DO $$ BEGIN RAISE NOTICE 'Mapping table drug_mapping_brand_name_list created.'; END $$;

UPDATE drug_regex_mapping_words c
SET update_method = 'brand name match', concept_name = b.concept_name, concept_id = b.concept_id::INTEGER
FROM (
  SELECT a.drug_name_original, MAX(UPPER(b1.concept_name)) AS concept_name, MAX(b1.concept_id) AS concept_id
  FROM drug_mapping_brand_name_list a
  INNER JOIN rxnorm_mapping_brand_name_list b1 ON a.ingredient_list = b1.ingredient_list
  GROUP BY a.drug_name_original
) b
WHERE c.drug_name_original = b.drug_name_original
  AND c.update_method IS NULL
  AND b.concept_name NOT IN ('G.B.H. SHAMPOO', 'A.P.L.', 'C.P.M.', 'ALLERGY CREAM', 'MG 217', 'ACID JELLY', 'C/T/S', 'M.A.H.', 'I.D.A.', 'N.T.A.', 'FORMULA 21', 'PRO OTIC', 'E.S.P.', 'PREPARATION H CREAM', 'H 9600 SR', '12 HOUR COLD', 'GLYCERYL T', 'G BID', 'AT 10', 'COMPOUND 347', 'MS/S', 'HYDRO 40', 'HP 502', 'LIQUID PRED', 'ORAL PEROXIDE', 'BABY GAS', 'BC POWDER 742/38/222', 'COMFORT GEL', 'MAG 64', 'K EFFERVESCENT', 'NASAL LA', 'THERAPEUTIC SHAMPOO', 'CHEWABLE CALCIUM', 'PAIN RELIEF (EFFERVESCENT)', 'STRESS LIQUID', 'IRON 300', 'FS SHAMPOO', 'T/GEL CONDITIONER', 'EX DEC', 'DR.S CREAM', 'JOINT GEL', 'CP ORAL', 'OTIC CARE', 'DR.S CREAM', 'NASAL RELIEF', 'MEDICATED BLUE', 'FE 50', 'BIOTENE TOOTHPASTE', 'VITAMIN A', 'SODIUM', 'HYDROCHLORIDE', 'HCL', 'CALCIUM', 'LONG LASTING NASAL', 'TRIPLE PASTE', 'K + POTASSIUM', 'NASAL DECONGESTANT SYRUP', 'COLD CREAM', 'VITAMIN B 12', 'MALEATE', 'TARTRATE', 'MESYLATE', 'MONOHYDRATE', 'SUCCINATE', 'CORN SYRUP', 'FACTOR X', 'PROTEIN S');
DO $$ BEGIN RAISE NOTICE 'Brand name mappings applied.'; END $$;

-- Update original mapping table with mapped names
UPDATE drug_regex_mapping c
SET update_method = b.update_method, drug_name_clean = b.concept_name, concept_id = b.concept_id::INTEGER
FROM drug_regex_mapping_words b
WHERE c.drug_name_original = b.drug_name_original
  AND c.update_method IS NULL;
DO $$ BEGIN RAISE NOTICE 'Original mapping table updated with brand names, multi-ingredient, and single-ingredient names.'; END $$;

-- Create active ingredient mapping table
DROP TABLE IF EXISTS drug_ai_mapping;
CREATE TABLE drug_ai_mapping AS
SELECT DISTINCT drugname AS drug_name_original, prod_ai, NULL::INTEGER AS concept_id, NULL AS update_method
FROM drug INNER JOIN unique_all_case ON drug.primaryid = unique_all_case.primaryid WHERE unique_all_case.isr IS NULL;
DO $$ BEGIN RAISE NOTICE 'Mapping table drug_ai_mapping created.'; END $$;

CREATE INDEX IF NOT EXISTS prod_ai_ix ON drug_ai_mapping(prod_ai);

UPDATE drug_ai_mapping a
SET update_method = 'drug active ingredients', concept_id = b.concept_id::INTEGER
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
  AND UPPER(b.concept_name) = UPPER(a.prod_ai);
DO $$ BEGIN RAISE NOTICE 'Active ingredient mappings applied.'; END $$;

-- Create NDA mapping table
DROP TABLE IF EXISTS drug_nda_mapping;
CREATE TABLE drug_nda_mapping AS
SELECT DISTINCT drugname AS drug_name_original, nda_num, NULL::VARCHAR AS nda_ingredient, NULL::INTEGER AS concept_id, NULL AS update_method
FROM (
  SELECT drugname, nda_num FROM drug INNER JOIN unique_all_case ON drug.primaryid = unique_all_case.primaryid WHERE unique_all_case.isr IS NULL AND nda_num IS NOT NULL
  UNION
  SELECT drugname, nda_num FROM drug_legacy INNER JOIN unique_all_case ON drug_legacy.isr = unique_all_case.isr WHERE unique_all_case.isr IS NOT NULL AND nda_num IS NOT NULL
) aa;
DO $$ BEGIN RAISE NOTICE 'Mapping table drug_nda_mapping created.'; END $$;

CREATE INDEX IF NOT EXISTS nda_num_ix ON drug_nda_mapping(nda_num);

UPDATE drug_nda_mapping a
SET update_method = 'drug nda_num ingredients', nda_ingredient = nda_ingredient.ingredient, concept_id = b.concept_id::INTEGER
FROM cdmv5.concept b
INNER JOIN nda_ingredient ON UPPER(b.concept_name) = UPPER(nda_ingredient.ingredient)
WHERE b.vocabulary_id = 'RxNorm'
  AND nda_ingredient.appl_no = a.nda_num
  AND (
    (UPPER(a.drug_name_original) LIKE '%' || UPPER(nda_ingredient.ingredient) || '%') OR
    (UPPER(a.drug_name_original) LIKE '%' || UPPER(nda_ingredient.trade_name) || '%')
  );
DO $$ BEGIN RAISE NOTICE 'NDA mappings applied.'; END $$;

-- Combine all mappings into a single table
DROP TABLE IF EXISTS combined_drug_mapping;
CREATE TABLE combined_drug_mapping AS
SELECT DISTINCT primaryid, isr, drug_seq, role_cod, drug_name_original, lookup_value, concept_id, update_method
FROM (
  SELECT DISTINCT b.primaryid, b.isr, drug_seq, role_cod, drugname AS drug_name_original, CAST(NULL AS VARCHAR) AS lookup_value, CAST(NULL AS INTEGER) AS concept_id, CAST(NULL AS VARCHAR) AS update_method
  FROM drug a
  INNER JOIN unique_all_case b ON a.primaryid = b.primaryid
  WHERE b.isr IS NULL
  UNION
  SELECT DISTINCT b.primaryid AS primaryid, b.isr, drug_seq, role_cod, drugname AS drug_name_original, CAST(NULL AS VARCHAR) AS lookup_value, CAST(NULL AS INTEGER) AS concept_id, CAST(NULL AS VARCHAR) AS update_method
  FROM drug_legacy a
  INNER JOIN unique_all_case b ON a.isr = b.isr
  WHERE b.isr IS NOT NULL
) aa;
DO $$ BEGIN RAISE NOTICE 'Table combined_drug_mapping created.'; END $$;

-- Create index on the combined table
DROP INDEX IF EXISTS combined_drug_mapping_ix;
CREATE INDEX combined_drug_mapping_ix ON combined_drug_mapping(UPPER(drug_name_original));
DO $$ BEGIN RAISE NOTICE 'Index on combined_drug_mapping created.'; END $$;

-- Batch update combined_drug_mapping using drug_regex_mapping
DO $$
BEGIN
    RAISE NOTICE 'Updating combined_drug_mapping with drug_regex_mapping...';

    UPDATE combined_drug_mapping a
    SET update_method = b.update_method, lookup_value = b.drug_name_clean, concept_id = b.concept_id::INTEGER
    FROM drug_regex_mapping b
    WHERE UPPER(a.drug_name_original) = UPPER(b.drug_name_original)
      AND a.concept_id IS NULL
      AND b.concept_id IS NOT NULL;
      
    RAISE NOTICE 'Combined table updated with regex mappings.';
END $$;

-- Batch update combined_drug_mapping using drug_ai_mapping
DO $$
BEGIN
    RAISE NOTICE 'Updating combined_drug_mapping with drug_ai_mapping...';

    UPDATE combined_drug_mapping a
    SET update_method = b.update_method, lookup_value = b.prod_ai, concept_id = b.concept_id::INTEGER
    FROM drug_ai_mapping b
    WHERE UPPER(a.drug_name_original) = UPPER(b.drug_name_original)
      AND a.concept_id IS NULL
      AND b.concept_id IS NOT NULL;
      
    RAISE NOTICE 'Combined table updated with active ingredient mappings.';
END $$;

-- Batch update combined_drug_mapping using drug_nda_mapping
DO $$
BEGIN
    RAISE NOTICE 'Updating combined_drug_mapping with drug_nda_mapping...';

    UPDATE combined_drug_mapping a
    SET update_method = b.update_method, lookup_value = b.nda_ingredient, concept_id = b.concept_id::INTEGER
    FROM drug_nda_mapping b
    WHERE UPPER(a.drug_name_original) = UPPER(b.drug_name_original)
      AND a.concept_id IS NULL
      AND b.concept_id IS NOT NULL;
      
    RAISE NOTICE 'Combined table updated with NDA mappings.';
END $$;

-- Batch update combined_drug_mapping using drug_usagi_mapping
DO $$
BEGIN
    RAISE NOTICE 'Updating combined_drug_mapping with drug_usagi_mapping...';

    UPDATE combined_drug_mapping a
    SET update_method = b.update_method, lookup_value = b.concept_name, concept_id = b.concept_id::INTEGER
    FROM drug_usagi_mapping b
    WHERE UPPER(a.drug_name_original) = UPPER(b.drug_name_original)
      AND a.concept_id IS NULL
      AND b.concept_id IS NOT NULL;
      
    RAISE NOTICE 'Combined table updated with manual Usagi mappings.';
END $$;

-- Update unknown drugs
DO $$
BEGIN
    RAISE NOTICE 'Updating unknown drug names...';
    UPDATE combined_drug_mapping
    SET update_method = 'unknown drug'
    WHERE UPPER(drug_name_original) ~* '^UNKNOWN.*'
      AND update_method IS NULL;
    RAISE NOTICE 'Unknown drug names updated.';

    UPDATE combined_drug_mapping
    SET update_method = 'unknown drug'
    WHERE UPPER(drug_name_original) ~* '^OTHER.*'
      AND update_method IS NULL;
    RAISE NOTICE 'Other drug names updated.';

    UPDATE combined_drug_mapping
    SET update_method = 'unknown drug'
    WHERE UPPER(drug_name_original) ~* '^UNSPECIFIED.*'
      AND update_method IS NULL;
    RAISE NOTICE 'Unspecified drug names updated.';
END $$;
