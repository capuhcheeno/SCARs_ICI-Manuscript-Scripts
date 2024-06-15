-- Set the search path to cdmv5
set search_path = cdmv5;

-- Drop and create index on the concept table
drop index if exists vocab_concept_name_ix;
create index vocab_concept_name_ix on concept(vocabulary_id, standard_concept, upper(concept_name), concept_id);
analyze verbose concept;

-- Set the search path to faers
set search_path = faers;

-- Drop the existing table and create a new one for drug regex mapping
drop table if exists drug_regex_mapping;
create table drug_regex_mapping as
select distinct
    drugname as drug_name_original,
    upper(drugname) as drug_name_clean,
    null::integer as concept_id,
    null::text as update_method
from drug a
inner join unique_all_case b on a.primaryid = b.primaryid
where b.isr is null
union
select distinct
    drugname as drug_name_original,
    upper(drugname) as drug_name_clean,
    null::integer as concept_id,
    null::text as update_method
from drug_legacy a
inner join unique_all_case b on a.isr = b.isr
where b.isr is not null;

-- Create index on drug_name_clean column
drop index if exists drug_name_clean_ix;
create index drug_name_clean_ix on drug_regex_mapping(drug_name_clean);

-- Remove the word tablet or "(tablet)" or the plural forms from drug name
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, '(\W|^)TABLETS?(\W|$)', '\1\2', 'gi')
where concept_id is null
and drug_name_clean ~* 'TABLET';

-- Remove the word capsule or (capsule) or the plural forms from drug name
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, '(\W|^)CAPSULES?(\W|$)', '\1\2', 'gi')
where concept_id is null
and drug_name_clean ~* 'CAPSULE';

-- Fix invalid regular expression for drug strength in MG or MG/MG or MG\MG or MG / MG and their plural forms
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, '\b\d+(\.\d+)?\s*MG\b', '', 'gi')
where concept_id is null
and drug_name_clean ~* '\b\d+(\.\d+)?\s*MG\b';

-- Fix invalid regular expression for drug strength in MILLIGRAMS or MILLIGRAMS/MILLILITERS or MILLIGRAMS\MILLIGRAM and their plural forms
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, '\b\d+(\.\d+)?\s*MILLIGRAMS?\b', '', 'gi')
where concept_id is null
and drug_name_clean ~* '\b\d+(\.\d+)?\s*MILLIGRAMS?\b';

-- Remove HYDROCHLORIDE and HCL
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, '\b(HCL|HYDROCHLORIDE)\b', '', 'gi')
where concept_id is null
and drug_name_clean ~* '\b(HCL|HYDROCHLORIDE)\b';

-- Find exact mapping for drug name after we have removed the above keywords
UPDATE drug_regex_mapping a
SET update_method = 'regex remove keywords', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
AND a.concept_id IS NULL;

-- Continue with similar updates for other keywords and patterns

-- Create the active ingredient mapping table for FAERS current data
drop table if exists drug_ai_mapping;
create table drug_ai_mapping as
select distinct drugname as drug_name_original, prod_ai, null::integer as concept_id, null::text as update_method
from drug a
inner join unique_all_case b on a.primaryid = b.primaryid where b.isr is null;

-- Create index on prod_ai column
drop index if exists prod_ai_ix;
create index prod_ai_ix on drug_ai_mapping(prod_ai);

-- Find exact mapping using the active ingredient provided in the drug table
UPDATE drug_ai_mapping a
SET update_method = 'drug active ingredients', concept_id = b.concept_id::integer
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = upper(a.prod_ai);

-- Create the NDA (new drug application) number mapping table
drop table if exists nda_ingredient;
create table nda_ingredient as
select distinct appl_no, ingredient, trade_name
from nda;

drop table if exists drug_nda_mapping;
create table drug_nda_mapping as
select distinct drug_name_original, nda_num, null as nda_ingredient, null::integer as concept_id, null::text as update_method
from (
    select distinct drugname as drug_name_original, nda_num
    from drug a
    inner join unique_all_case b on a.primaryid = b.primaryid
    where b.isr is null and nda_num is not null
    union
    select distinct drugname as drug_name_original, nda_num
    from drug_legacy a
    inner join unique_all_case b on a.isr = b.isr
    where b.isr is not null and nda_num is not null
) aa;

-- Create index on nda_num column
drop index if exists nda_num_ix;
create index nda_num_ix on drug_nda_mapping(nda_num);

-- Find exact mapping using the drug table nda_num, NDA to ingredient lookup
UPDATE drug_nda_mapping a
SET update_method = 'drug nda_num ingredients', nda_ingredient = nda_ingredient.ingredient, concept_id = b.concept_id::integer
FROM cdmv5.concept b
INNER JOIN nda_ingredient
ON upper(b.concept_name) = nda_ingredient.ingredient
WHERE b.vocabulary_id = 'RxNorm'
AND nda_ingredient.appl_no = a.nda_num
AND (
    upper(a.drug_name_original) LIKE '%' || upper(nda_ingredient.ingredient) || '%'
    OR upper(a.drug_name_original) LIKE '%' || upper(nda_ingredient.trade_name) || '%'
);

-- Combine all the different types of mapping into a single combined drug mapping table across legacy LAERS data and current FAERS data
drop table if exists combined_drug_mapping;
create table combined_drug_mapping as
select distinct
    primaryid,
    isr,
    drug_seq,
    role_cod,
    drug_name_original,
    lookup_value,
    concept_id,
    update_method
from (
    select distinct
        b.primaryid,
        b.isr,
        drug_seq,
        role_cod,
        drugname as drug_name_original,
        null::text as lookup_value,
        null::integer as concept_id,
        null::text as update_method
    from drug a
    inner join unique_all_case b on a.primaryid = b.primaryid
    where b.isr is null
    union
    select distinct
        b.primaryid,
        b.isr,
        drug_seq,
        role_cod,
        drugname as drug_name_original,
        null::text as lookup_value,
        null::integer as concept_id,
        null::text as update_method
    from drug_legacy a
    inner join unique_all_case b on a.isr = b.isr
    where b.isr is not null
) aa;

-- Create index on combined_drug_mapping
drop index if exists combined_drug_mapping_ix;
create index combined_drug_mapping_ix on combined_drug_mapping(upper(drug_name_original));

-- Update using drug_regex_mapping
UPDATE combined_drug_mapping a
SET update_method = b.update_method, lookup_value = b.drug_name_clean, concept_id = b.concept_id::integer
FROM drug_regex_mapping b
WHERE upper(a.drug_name_original) = upper(b.drug_name_original)
AND a.concept_id IS NULL
AND b.concept_id IS NOT NULL;

-- Update using drug_ai_mapping
UPDATE combined_drug_mapping a
SET update_method = b.update_method, lookup_value = b.prod_ai, concept_id = b.concept_id::integer
FROM drug_ai_mapping b
WHERE upper(a.drug_name_original) = upper(b.drug_name_original)
AND a.concept_id IS NULL
AND b.concept_id IS NOT NULL;

-- Update using drug_nda_mapping
UPDATE combined_drug_mapping a
SET update_method = b.update_method, lookup_value = b.nda_ingredient, concept_id = b.concept_id::integer
FROM drug_nda_mapping b
WHERE upper(a.drug_name_original) = upper(b.drug_name_original)
AND a.concept_id IS NULL
AND b.concept_id IS NOT NULL;

-- Manually curated drug mappings
UPDATE combined_drug_mapping a
SET update_method = b.update_method, lookup_value = b.concept_name, concept_id = b.concept_id::integer
FROM drug_usagi_mapping b
WHERE upper(a.drug_name_original) = upper(b.drug_name_original)
AND a.concept_id IS NULL
AND b.concept_id IS NOT NULL;

-- Update unknown drugs where drug name starts with UNKNOWN, OTHER, or UNSPECIFIED
update combined_drug_mapping
set update_method = 'unknown drug'
where upper(drug_name_original) ~* '^(UNKNOWN|OTHER|UNSPECIFIED).*'
and update_method is null;
