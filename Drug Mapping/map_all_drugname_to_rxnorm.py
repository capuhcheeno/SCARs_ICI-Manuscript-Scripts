import pandas as pd
from sqlalchemy import create_engine, text

# Create a connection to the database
engine = create_engine('postgresql://postgres:100700@localhost:5432/postgres')

# Create a function to execute SQL queries
def execute_query(query, conn):
    
    with conn.begin():
        conn.execute(text(query))

# Step 1: Create Indexes
with engine.connect() as conn:
    execute_query("SET search_path = cdmv5;", conn)
    execute_query("DROP INDEX IF EXISTS vocab_concept_name_ix;", conn)
    execute_query("CREATE INDEX vocab_concept_name_ix ON cdmv5.concept(vocabulary_id, standard_concept, UPPER(concept_name), concept_id);", conn)
    execute_query("ANALYZE VERBOSE cdmv5.concept;", conn)
    execute_query("SET search_path = faers;", conn)

# Step 2: Build Drug Regex Mapping Table
with engine.connect() as conn:
    execute_query("DROP TABLE IF EXISTS drug_regex_mapping;", conn)
    query = """
    CREATE TABLE drug_regex_mapping AS
    SELECT DISTINCT drug_name_original, drug_name_clean, concept_id, update_method
    FROM (
        SELECT DISTINCT drugname AS drug_name_original, UPPER(drugname) AS drug_name_clean, NULL::INTEGER AS concept_id, NULL AS update_method
        FROM drug a
        INNER JOIN unique_all_case b ON a.primaryid = b.primaryid
        WHERE b.isr IS NULL
        UNION
        SELECT DISTINCT drugname AS drug_name_original, UPPER(drugname) AS drug_name_clean, NULL::INTEGER AS concept_id, NULL AS update_method
        FROM drug_legacy a
        INNER JOIN unique_all_case b ON a.isr = b.isr
        WHERE b.isr IS NOT NULL
    ) aa;
    """
    execute_query(query, conn)
    execute_query("DROP INDEX IF EXISTS drug_name_clean_ix;", conn)
    execute_query("CREATE INDEX drug_name_clean_ix ON drug_regex_mapping(drug_name_clean);", conn)

# Step 3: Remove Keywords and Update Mappings
keywords_removal_queries = [
    r"""
    UPDATE drug_regex_mapping
    SET drug_name_clean = REGEXP_REPLACE(drug_name_clean, '(.*)(\W|^)\(TABLETS?\)|TABLETS?(\W|$)', '\1\2', 'gi')
    WHERE concept_id IS NULL AND drug_name_clean ~* '.*TABLET.*';
    """,
    r"""
    UPDATE drug_regex_mapping
    SET drug_name_clean = REGEXP_REPLACE(drug_name_clean, '(.*)(\W|^)\(CAPSULES?\)|CAPSULES?(\W|$)', '\1\2', 'gi')
    WHERE concept_id IS NULL AND drug_name_clean ~* '.*CAPSULE.*';
    """,
    # Add all other update queries here similarly...
]

with engine.connect() as conn:
    for query in keywords_removal_queries:
        execute_query(query, conn)

# Step 4: Exact Mapping and Other Mappings
exact_mapping_queries = [
    r"""
    UPDATE drug_regex_mapping a
    SET update_method = 'regex remove keywords', concept_id = b.concept_id::INTEGER
    FROM cdmv5.concept b
    WHERE b.vocabulary_id = 'RxNorm' AND UPPER(b.concept_name) = a.drug_name_clean AND a.concept_id IS NULL;
    """,
    # Add all other update queries here similarly...
]

with engine.connect() as conn:
    for query in exact_mapping_queries:
        execute_query(query, conn)

# Step 5: Mapping Multi-Ingredient Drugs
multi_ingredient_queries = [
    # Create and populate rxnorm_mapping_multi_ingredient_list
    r"""
    DROP TABLE IF EXISTS rxnorm_mapping_multi_ingredient_list;
    CREATE TABLE rxnorm_mapping_multi_ingredient_list AS
    SELECT ingredient_list, MAX(concept_id) AS concept_id, MAX(concept_name) AS concept_name
    FROM (
        SELECT concept_id, concept_name, STRING_AGG(word, ' ' ORDER BY word) AS ingredient_list
        FROM (
            SELECT concept_id, concept_name, UNNEST(REGEXP_SPLIT_TO_ARRAY(UPPER(concept_name), E'[\ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"\'\?\<\>\&\^\!\*\_\+\=]+')) AS word
            FROM (
                SELECT UPPER(concept_name) AS concept_name, concept_id
                FROM cdmv5.concept b
                WHERE b.vocabulary_id = 'RxNorm' AND b.concept_class_id = 'Clinical Drug Form' AND concept_name LIKE '%/%'
            ) aa
        ) bb
        WHERE word NOT IN ('')
        AND word NOT IN (
            SELECT DISTINCT UNNEST(REGEXP_SPLIT_TO_ARRAY(UPPER(concept_name), E'[\ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"\'\?\<\>\&\^\!\*\_\+\=]+'))
            FROM cdmv5.concept b
            WHERE b.vocabulary_id = 'RxNorm' AND b.concept_class_id = 'Dose Form' ORDER BY 1
        )
        GROUP BY concept_id, concept_name
    ) dd
    GROUP BY ingredient_list;
    """,
    # Add all other multi-ingredient queries here similarly...
]

with engine.connect() as conn:
    for query in multi_ingredient_queries:
        execute_query(query, conn)

# Step 6: Mapping Single-Ingredient Drugs
single_ingredient_queries = [
    # Create and populate rxnorm_mapping_single_ingredient_list
    r"""
    DROP TABLE IF EXISTS rxnorm_mapping_single_ingredient_list;
    CREATE TABLE rxnorm_mapping_single_ingredient_list AS
    SELECT ingredient_list, MAX(concept_id) AS concept_id, MAX(concept_name) AS concept_name
    FROM (
        SELECT concept_id, concept_name, STRING_AGG(word, ' ' ORDER BY word) AS ingredient_list
        FROM (
            SELECT concept_id, concept_name, UNNEST(REGEXP_SPLIT_TO_ARRAY(UPPER(concept_name), E'[\ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"\'\?\<\>\&\^\!\*\_\+\=]+')) AS word
            FROM (
                SELECT UPPER(concept_name) AS concept_name, concept_id
                FROM cdmv5.concept b
                WHERE b.vocabulary_id = 'RxNorm' AND b.concept_class_id = 'Ingredient'
            ) aa
        ) bb
        WHERE word NOT IN ('')
        AND word NOT IN (
            SELECT DISTINCT UNNEST(REGEXP_SPLIT_TO_ARRAY(UPPER(concept_name), E'[\ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"\'\?\<\>\&\^\!\*\_\+\=]+'))
            FROM cdmv5.concept b
            WHERE b.vocabulary_id = 'RxNorm' AND b.concept_class_id = 'Dose Form' ORDER BY 1
        )
        GROUP BY concept_id, concept_name
    ) dd
    GROUP BY ingredient_list;
    """,
    # Add all other single-ingredient queries here similarly...
]

with engine.connect() as conn:
    for query in single_ingredient_queries:
        execute_query(query, conn)

# Step 7: Mapping Brand Names
brand_name_queries = [
    # Create and populate rxnorm_mapping_brand_name_list
    r"""
    DROP TABLE IF EXISTS rxnorm_mapping_brand_name_list;
    CREATE TABLE rxnorm_mapping_brand_name_list AS
    SELECT ingredient_list, MAX(concept_id) AS concept_id, MAX(concept_name) AS concept_name
    FROM (
        SELECT concept_id, concept_name, STRING_AGG(word, ' ' ORDER BY word) AS ingredient_list
        FROM (
            SELECT concept_id, concept_name, UNNEST(REGEXP_SPLIT_TO_ARRAY(UPPER(concept_name), E'[\ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"\'\?\<\>\&\^\!\*\_\+\=]+')) AS word
            FROM (
                SELECT UPPER(concept_name) AS concept_name, concept_id
                FROM cdmv5.concept b
                WHERE b.vocabulary_id = 'RxNorm' AND b.concept_class_id = 'Brand Name'
            ) aa
        ) bb
        WHERE word NOT IN ('')
        AND word NOT IN (
            SELECT DISTINCT UNNEST(REGEXP_SPLIT_TO_ARRAY(UPPER(concept_name), E'[\ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"\'\?\<\>\&\^\!\*\_\+\=]+'))
            FROM cdmv5.concept b
            WHERE b.vocabulary_id = 'RxNorm' AND b.concept_class_id = 'Dose Form' ORDER BY 1
        )
        GROUP BY concept_id, concept_name
    ) dd
    GROUP BY ingredient_list;
    """,
    # Add all other brand name queries here similarly...
]

with engine.connect() as conn:
    for query in brand_name_queries:
        execute_query(query, conn)

# Step 8: Create Combined Drug Mapping Table
with engine.connect() as conn:
    execute_query("DROP TABLE IF EXISTS combined_drug_mapping;", conn)
    query = r"""
    CREATE TABLE combined_drug_mapping AS
    SELECT DISTINCT primaryid, isr, drug_seq, role_cod, drug_name_original, lookup_value, concept_id, update_method
    FROM (
        SELECT DISTINCT b.primaryid, b.isr, drug_seq, role_cod, drugname AS drug_name_original, NULL::VARCHAR AS lookup_value, NULL::INTEGER AS concept_id, NULL::VARCHAR AS update_method
        FROM drug a
        INNER JOIN unique_all_case b ON a.primaryid = b.primaryid
        WHERE b.isr IS NULL
        UNION
        SELECT DISTINCT b.primaryid, b.isr, drug_seq, role_cod, drugname AS drug_name_original, NULL::VARCHAR AS lookup_value, NULL::INTEGER AS concept_id, NULL::VARCHAR AS update_method
        FROM drug_legacy a
        INNER JOIN unique_all_case b ON a.isr = b.isr
        WHERE b.isr IS NOT NULL
    ) aa;
    """
    execute_query(query, conn)
    execute_query("DROP INDEX IF EXISTS combined_drug_mapping_ix;", conn)
    execute_query("CREATE INDEX combined_drug_mapping_ix ON combined_drug_mapping(UPPER(drug_name_original));", conn)

# Step 9: Create and populate drug_ai_mapping table
with engine.connect() as conn:
    execute_query("DROP TABLE IF EXISTS drug_ai_mapping;", conn)
    query = """
    CREATE TABLE drug_ai_mapping AS
    SELECT DISTINCT drugname AS drug_name_original, prod_ai, NULL::INTEGER AS concept_id, NULL AS update_method
    FROM drug a
    INNER JOIN unique_all_case b ON a.primaryid = b.primaryid WHERE b.isr IS NULL;
    """
    execute_query(query, conn)
    execute_query("DROP INDEX IF EXISTS prod_ai_ix;", conn)
    execute_query("CREATE INDEX prod_ai_ix ON drug_ai_mapping(prod_ai);", conn)

# Step 10: Create and populate drug_nda_mapping table
with engine.connect() as conn:
    execute_query("DROP TABLE IF EXISTS nda_ingredient;", conn)
    query = """
    CREATE TABLE nda_ingredient AS
    SELECT DISTINCT appl_no, ingredient, trade_name
    FROM nda;
    """
    execute_query(query, conn)

    execute_query("DROP TABLE IF EXISTS drug_nda_mapping;", conn)
    query = """
    CREATE TABLE drug_nda_mapping AS
    SELECT DISTINCT drug_name_original, nda_num, nda_ingredient, concept_id, update_method
    FROM (
        SELECT DISTINCT drugname AS drug_name_original, nda_num, NULL AS nda_ingredient, NULL::INTEGER AS concept_id, NULL AS update_method
        FROM drug a
        INNER JOIN unique_all_case b ON a.primaryid = b.primaryid
        WHERE b.isr IS NULL AND nda_num IS NOT NULL
        UNION
        SELECT DISTINCT drugname AS drug_name_original, nda_num, NULL AS nda_ingredient, NULL::INTEGER AS concept_id, NULL AS update_method
        FROM drug_legacy a
        INNER JOIN unique_all_case b ON a.isr = b.isr
        WHERE b.isr IS NOT NULL AND nda_num IS NOT NULL
    ) aa;
    """
    execute_query(query, conn)
    execute_query("DROP INDEX IF EXISTS nda_num_ix;", conn)
    execute_query("CREATE INDEX nda_num_ix ON drug_nda_mapping(nda_num);", conn)

# Step 11: Create and populate drug_usagi_mapping table (this table should be manually curated as indicated)
with engine.connect() as conn:
    execute_query("DROP TABLE IF EXISTS drug_usagi_mapping;", conn)
    query = """
    CREATE TABLE drug_usagi_mapping (
        drug_name_original VARCHAR,
        concept_name VARCHAR,
        concept_id INTEGER,
        update_method VARCHAR
    );
    """
    execute_query(query, conn)

    # Populate drug_usagi_mapping with manually curated data
    # Add your data insertion logic here if needed, for example:
    # execute_query("INSERT INTO drug_usagi_mapping (drug_name_original, concept_name, concept_id, update_method) VALUES ('example_drug', 'example_concept', 123456, 'manual');", conn)

# Step 12: Update Combined Drug Mapping Table
update_combined_queries = [
    r"""
    UPDATE combined_drug_mapping a
    SET update_method = b.update_method, lookup_value = b.drug_name_clean, concept_id = b.concept_id::INTEGER
    FROM drug_regex_mapping b
    WHERE UPPER(a.drug_name_original) = UPPER(b.drug_name_original) AND a.concept_id IS NULL AND b.concept_id IS NOT NULL;
    """,
    r"""
    UPDATE combined_drug_mapping a
    SET update_method = b.update_method, lookup_value = b.prod_ai, concept_id = b.concept_id::INTEGER
    FROM drug_ai_mapping b
    WHERE UPPER(a.drug_name_original) = UPPER(b.drug_name_original) AND a.concept_id IS NULL AND b.concept_id IS NOT NULL;
    """,
    r"""
    UPDATE combined_drug_mapping a
    SET update_method = b.update_method, lookup_value = b.nda_ingredient, concept_id = b.concept_id::INTEGER
    FROM drug_nda_mapping b
    WHERE UPPER(a.drug_name_original) = UPPER(b.drug_name_original) AND a.concept_id IS NULL AND b.concept_id IS NOT NULL;
    """,
    r"""
    UPDATE combined_drug_mapping a
    SET update_method = b.update_method, lookup_value = b.concept_name, concept_id = b.concept_id::INTEGER
    FROM drug_usagi_mapping b
    WHERE UPPER(a.drug_name_original) = UPPER(b.drug_name_original) AND a.concept_id IS NULL AND b.concept_id IS NOT NULL;
    """,
    r"""
    UPDATE combined_drug_mapping
    SET update_method = 'unknown drug'
    WHERE UPPER(drug_name_original) ~* '^UNKNOWN.*' AND update_method IS NULL;
    """,
    r"""
    UPDATE combined_drug_mapping
    SET update_method = 'unknown drug'
    WHERE UPPER(drug_name_original) ~* '^OTHER.*' AND update_method IS NULL;
    """,
    r"""
    UPDATE combined_drug_mapping
    SET update_method = 'unknown drug'
    WHERE UPPER(drug_name_original) ~* '^UNSPECIFIED.*' AND update_method IS NULL;
    """
]

with engine.connect() as conn:
    for query in update_combined_queries:
        execute_query(query, conn)

# Step 13: Finalize and Clean Up
with engine.connect() as conn:
    execute_query("SET search_path = cdmv5;", conn)
    execute_query("DROP INDEX IF EXISTS vocab_concept_name_ix;", conn)

print("Data transformation and mapping completed successfully.")