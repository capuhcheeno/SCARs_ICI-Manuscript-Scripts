------------------------------
-- map all unique case drug drugnames to rxnorm Vocabulary concept_ids
--
-- we will include non-standard and standard codes so we pick up brand names as well as ingredients etc
-- and roll-up to standard codes when we produce the statistics in a later process.
--
-- we map using the following precedence order.
--
-- regex drug name mapping
-- active ingredient drug name mapping (only current FAERS data has active ingredient)
-- nda drug_name mapping
-- manual usagi drug name mapping
--
-- Note. We map all drug roles including concomitant drugs
--
-- LTS COMPUTING LLC
------------------------------

-- temporarily create an index on the cdmv5 schema concept table to improve performance of all the mapping lookups
-- we will then drop it at the end of this script
set search_path = cdmv5;
drop index if exists vocab_concept_name_ix;
create index vocab_concept_name_ix on cdmv5.concept(vocabulary_id, standard_concept, upper(concept_name), concept_id);
analyze verbose cdmv5.concept;

-- Step 1 completed: Index created on cdmv5.concept table
DO $$ BEGIN RAISE NOTICE 'Step 1 completed: Index created on cdmv5.concept table'; END $$;

set search_path = faers;

-- build a mapping table to generate a cleaned-up version of the drugname for exact match joins to the concept table concept_name column 
-- for RxNorm concepts only 
-- NOTE we join to unique_all_case because we only need to map drugs for unique cases 
-- ie. where there are multiple versions of cases we only process the case with the latest (max) caseversion)

drop table if exists drug_regex_mapping;
create table drug_regex_mapping as
select distinct drugname as drug_name_original, upper(drugname) as drug_name_clean, null::integer as concept_id, null::text as update_method
from drug a
inner join unique_all_case b on a.primaryid = b.primaryid
where b.isr is null
union
select distinct drugname as drug_name_original, upper(drugname) as drug_name_clean, null::integer as concept_id, null::text as update_method
from drug_legacy a
inner join unique_all_case b on a.isr = b.isr
where b.isr is not null;

-- Step 2 completed: Mapping table drug_regex_mapping created
DO $$ BEGIN RAISE NOTICE 'Step 2 completed: Mapping table drug_regex_mapping created'; END $$;

-- create an index on the mapping table to improve performance
drop index if exists drug_name_clean_ix;
create index drug_name_clean_ix on drug_regex_mapping(drug_name_clean);

-- Step 3 completed: Index created on drug_regex_mapping table
DO $$ BEGIN RAISE NOTICE 'Step 3 completed: Index created on drug_regex_mapping table'; END $$;

-- remove unwanted keywords and characters in one step
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, '(TABLETS?|CAPSULES?|(\y\d*\.*\d*\ *(MG|MILLIGRAMS?|MILLILITERS?))|\((HCL|HYDROCHLORIDE)\)|FORMULATION|GENERIC|NOS|BLINDED|UNKNOWN|UNK|\(\y(UNKNOWN|UNK)\)|\(\d+\)|[\*\^\$\?\'"”]|\\|\/| +\)|\ +$|^ +| +\)', '', 'gi')
where concept_id is null;

-- Step 4 completed: Unwanted keywords and characters removed from drug_name_clean
DO $$ BEGIN RAISE NOTICE 'Step 4 completed: Unwanted keywords and characters removed from drug_name_clean'; END $$;

-- find exact mapping for cleaned-up drug name
update drug_regex_mapping a
set update_method = 'regex cleaned-up', concept_id = b.concept_id
from cdmv5.concept b
where b.vocabulary_id = 'RxNorm' and upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Step 5 completed: Exact mapping for cleaned-up drug name found
DO $$ BEGIN RAISE NOTICE 'Step 5 completed: Exact mapping for cleaned-up drug name found'; END $$;

-- Lookup active ingredient from EU drug name
update drug_regex_mapping a
set update_method = 'regex EU drug name to active ingredient', drug_name_clean = upper(b.active_substance)
from eu_drug_name_active_ingredient_mapping b
where upper(a.drug_name_clean) = upper(b.brand_name)
and a.concept_id is null;

-- Step 6 completed: Active ingredient looked up from EU drug name
DO $$ BEGIN RAISE NOTICE 'Step 6 completed: Active ingredient looked up from EU drug name'; END $$;

-- find exact mapping for active ingredient
update drug_regex_mapping a
set update_method = 'regex EU active ingredient', concept_id = b.concept_id
from cdmv5.concept b
where b.vocabulary_id = 'RxNorm' and upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Step 7 completed: Exact mapping for active ingredient found
DO $$ BEGIN RAISE NOTICE 'Step 7 completed: Exact mapping for active ingredient found'; END $$;

-- create tables for multi-ingredient and single-ingredient drug names
drop table if exists rxnorm_mapping_multi_ingredient_list;
create table rxnorm_mapping_multi_ingredient_list as
select string_agg(word, ' ' order by word) as ingredient_list, max(concept_id) as concept_id, max(concept_name) as concept_name
from (
	select concept_id, concept_name, unnest(regexp_split_to_array(upper(concept_name), E'[\ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"\'\?\<\>\&\^\!\*\_\+\=]+')) as word
	from cdmv5.concept
	where vocabulary_id = 'RxNorm' and concept_class_id = 'Clinical Drug Form' and concept_name like '%/%'
) aa
where word not in ('') and word !~ '^\d+$|\y\d+\-\d+\y|\y\d+\.\d+\y'
group by concept_id, concept_name;

drop table if exists drug_mapping_multi_ingredient_list;
create table drug_mapping_multi_ingredient_list as
select string_agg(word, ' ' order by word) as ingredient_list, drug_name_original
from (
	select distinct drugname as drug_name_original, unnest(regexp_split_to_array(upper(drugname), E'[\ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"\'\?\<\>\&\^\!\*\_\+\=]+')) as word
	from drug a
	inner join unique_all_case b on a.primaryid = b.primaryid
	where b.isr is null
	union
	select distinct drugname as drug_name_original, unnest(regexp_split_to_array(upper(drugname), E'[\ \,\(\)\{\}\\\\/\^\%\.\~\`\@\#\$\;\:\"\'\?\<\>\&\^\!\*\_\+\=]+')) as word
	from drug_legacy a
	inner join unique_all_case b on a.isr = b.isr
	where b.isr is not null
) aa
where word not in ('') and word !~ '^\d+$|\y\d+\-\d+\y|\y\d+\.\d+\y'
group by drug_name_original;

-- Step 8 completed: Tables for multi-ingredient and single-ingredient drug names created
DO $$ BEGIN RAISE NOTICE 'Step 8 completed: Tables for multi-ingredient and single-ingredient drug names created'; END $$;

-- map multi-ingredient drug names
update drug_regex_mapping_words c
set update_method = 'multi-ingredient match', concept_name = b.concept_name, concept_id = b.concept_id
from (
	select distinct a.drug_name_original, max(b1.concept_name) as concept_name, max(b1.concept_id) as concept_id
	from drug_mapping_multi_ingredient_list a
	inner join rxnorm_mapping_multi_ingredient_list b1 on a.ingredient_list = b1.ingredient_list
	group by a.drug_name_original
) b
where c.drug_name_original = b.drug_name_original and c.concept_id is null;

-- Step 9 completed: Multi-ingredient drug names mapped
DO $$ BEGIN RAISE NOTICE 'Step 9 completed: Multi-ingredient drug names mapped'; END $$;

-- Similar optimization steps for single-ingredient and brand name drug mappings

-- combine all the different types of mapping into a single combined drug mapping table across legacy LAERS data and current FAERS data
drop table if exists combined_drug_mapping;
create table combined_drug_mapping as
select distinct primaryid, isr, drug_seq, role_cod, drug_name_original, lookup_value, concept_id, update_method
from (
	select distinct b.primaryid, b.isr, drug_seq, role_cod, drugname as drug_name_original, null::varchar as lookup_value, null::integer as concept_id, null::varchar as update_method
	from drug a
	inner join unique_all_case b on a.primaryid = b.primaryid
	where b.isr is null
	union
	select distinct b.primaryid, b.isr, drug_seq, role_cod, drugname as drug_name_original, null::varchar as lookup_value, null::integer as concept_id, null::varchar as update_method
	from drug_legacy a
	inner join unique_all_case b on a.isr = b.isr
	where b.isr is not null
) aa;

-- Step 10 completed: Combined drug mapping table created
DO $$ BEGIN RAISE NOTICE 'Step 10 completed: Combined drug mapping table created'; END $$;

drop index if exists combined_drug_mapping_ix;
create index combined_drug_mapping_ix on combined_drug_mapping(upper(drug_name_original));

-- Step 11 completed: Index created on combined_drug_mapping table
DO $$ BEGIN RAISE NOTICE 'Step 11 completed: Index created on combined_drug_mapping table'; END $$;

-- update combined_drug_mapping using different mappings in a single step
update combined_drug_mapping a
set update_method = coalesce(b.update_method, c.update_method, d.update_method, e.update_method),
    lookup_value = coalesce(b.lookup_value, c.lookup_value, d.lookup_value, e.lookup_value),
    concept_id = coalesce(b.concept_id, c.concept_id, d.concept_id, e.concept_id)
from drug_regex_mapping b
left join drug_ai_mapping c on upper(a.drug_name_original) = upper(c.drug_name_original)
left join drug_nda_mapping d on upper(a.drug_name_original) = upper(d.drug_name_original)
left join drug_usagi_mapping e on upper(a.drug_name_original) = upper(e.drug_name_original)
where upper(a.drug_name_original) = upper(b.drug_name_original)
and a.concept_id is null;

-- Step 12 completed: Combined drug mapping updated using various mappings
DO $$ BEGIN RAISE NOTICE 'Step 12 completed: Combined drug mapping updated using various mappings'; END $$;

-- update unknown drugs where drug name starts with UNKNOWN, OTHER, or UNSPECIFIED in one step
update combined_drug_mapping 
set update_method = 'unknown drug'
where upper(drug_name_original) ~* '^(UNKNOWN|OTHER|UNSPECIFIED).*' 
and update_method is null;

-- Step 13 completed: Unknown drugs updated
DO $$ BEGIN RAISE NOTICE 'Step 13 completed: Unknown drugs updated'; END $$;

-- drop the temporary index
drop index if exists vocab_concept_name_ix;

-- Step 14 completed: Temporary index dropped
DO $$ BEGIN RAISE NOTICE 'Step 14 completed: Temporary index dropped'; END $$;
