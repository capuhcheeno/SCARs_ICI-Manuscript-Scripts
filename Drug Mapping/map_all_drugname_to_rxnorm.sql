NOTICE:  identifier "]', '', 'gi')
where concept_id is null;

UPDATE drug_regex_mapping a
SET update_method = 'regex remove single quotes', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Remove ^*$? characters
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, '[\\*\\^\\$\\?]', '', 'gi')
where concept_id is null;

UPDATE drug_regex_mapping a
SET update_method = 'regex remove ^*$? punctuation chars', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Change backslash to forward slash
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, '\\\\', '/', 'gi')
where concept_id is null;

UPDATE drug_regex_mapping a
SET update_method = 'regex change backslash to forward slash', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Remove spaces before closing parenthesis
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, ' +\\)', ')', 'gi')
where concept_id is null;

UPDATE drug_regex_mapping a
SET update_method = 'regex remove spaces before closing parenthesis', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Remove UNKNOWN or UNK except at the start of the drug name
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, '\\b(UNKNOWN|UNK)\\b', '', 'gi')
where concept_id is null
and drug_name_clean ~* '\\b(UNKNOWN|UNK)\\b';

UPDATE drug_regex_mapping a
SET update_method = 'regex remove (unknown)', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Remove BLINDED
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, '\\bBLINDED\\b', '', 'gi')
where concept_id is null;

UPDATE drug_regex_mapping a
SET update_method = 'regex remove blinded', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Remove /nnnnn/ pattern
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, '\\/\\d+\\/', '', 'gi')
where concept_id is null
and drug_name_original ~* '.*\\/\\d+\\/.*';

-- Remove trailing spaces
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, ' +$', '', 'gi')
where concept_id is null;

UPDATE drug_regex_mapping a
SET update_method = 'regex remove /nnnnn/', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Map vitamins where only brand name or generic description is provided
update drug_regex_mapping
set drug_name_clean = 'MULTIVITAMIN PREPARATION'
where drug_name_clean like '%VITAMIN%' and drug_name_clean not like '%VITAMIN A%' and drug_name_clean not like '%VITAMIN B%'
and drug_name_clean not like '%VITAMIN C%' and drug_name_clean not like '%VITAMIN K%' and drug_name_clean not like '%VITAMIN D%' 
and drug_name_clean not like '%VITAMIN E%' and concept_id is null;

UPDATE drug_regex_mapping a
SET update_method = 'regex vitamins', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Map RxNorm concepts for multi-ingredient drugs and complex names

-- Create table for the combined mapping of single and multiple ingredients and brand names
drop table if exists drug_regex_mapping_words;
create table drug_regex_mapping_words as
select distinct *
from (
    select drug_name_original, concept_name, concept_id, update_method, unnest(word_list::text[]) as word
    from (
        select drug_name_original, concept_name, concept_id, update_method, regexp_split_to_array(upper(drug_name_original), E'[ \\,,\\(,\\),\\{,\\},\\\\,/,\\^,%,\\.,~,`,@,#,$,;,\\:,\" will be truncated to "]', '', 'gi')
where concept_id is null;

UPDATE drug_regex_mapp"

ERROR:  syntax error at or near ""]', '', 'gi')
where concept_id is null;

UPDATE drug_regex_mapping a
SET update_method = 'regex remove single quotes', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Remove ^*$? characters
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, '[\\*\\^\\$\\?]', '', 'gi')
where concept_id is null;

UPDATE drug_regex_mapping a
SET update_method = 'regex remove ^*$? punctuation chars', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Change backslash to forward slash
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, '\\\\', '/', 'gi')
where concept_id is null;

UPDATE drug_regex_mapping a
SET update_method = 'regex change backslash to forward slash', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Remove spaces before closing parenthesis
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, ' +\\)', ')', 'gi')
where concept_id is null;

UPDATE drug_regex_mapping a
SET update_method = 'regex remove spaces before closing parenthesis', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Remove UNKNOWN or UNK except at the start of the drug name
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, '\\b(UNKNOWN|UNK)\\b', '', 'gi')
where concept_id is null
and drug_name_clean ~* '\\b(UNKNOWN|UNK)\\b';

UPDATE drug_regex_mapping a
SET update_method = 'regex remove (unknown)', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Remove BLINDED
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, '\\bBLINDED\\b', '', 'gi')
where concept_id is null;

UPDATE drug_regex_mapping a
SET update_method = 'regex remove blinded', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Remove /nnnnn/ pattern
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, '\\/\\d+\\/', '', 'gi')
where concept_id is null
and drug_name_original ~* '.*\\/\\d+\\/.*';

-- Remove trailing spaces
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, ' +$', '', 'gi')
where concept_id is null;

UPDATE drug_regex_mapping a
SET update_method = 'regex remove /nnnnn/', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Map vitamins where only brand name or generic description is provided
update drug_regex_mapping
set drug_name_clean = 'MULTIVITAMIN PREPARATION'
where drug_name_clean like '%VITAMIN%' and drug_name_clean not like '%VITAMIN A%' and drug_name_clean not like '%VITAMIN B%'
and drug_name_clean not like '%VITAMIN C%' and drug_name_clean not like '%VITAMIN K%' and drug_name_clean not like '%VITAMIN D%' 
and drug_name_clean not like '%VITAMIN E%' and concept_id is null;

UPDATE drug_regex_mapping a
SET update_method = 'regex vitamins', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Map RxNorm concepts for multi-ingredient drugs and complex names

-- Create table for the combined mapping of single and multiple ingredients and brand names
drop table if exists drug_regex_mapping_words;
create table drug_regex_mapping_words as
select distinct *
from (
    select drug_name_original, concept_name, concept_id, update_method, unnest(word_list::text[]) as word
    from (
        select drug_name_original, concept_name, concept_id, update_method, regexp_split_to_array(upper(drug_name_original), E'[ \\,,\\(,\\),\\{,\\},\\\\,/,\\^,%,\\.,~,`,@,#,$,;,\\:,\""
LINE 25: ..._name_clean = regexp_replace(drug_name_clean, '[\'"]', '', '...
                                                              ^ 

SQL state: 42601
Character: 985
    
-- Setting the search path
set search_path = faers;

-- Create a table for the drug name mappings
drop table if exists drug_regex_mapping;
create table drug_regex_mapping as
select distinct drugname as drug_name_original, upper(drugname) as drug_name_clean, cast(null as integer) as concept_id, null as update_method
from drug a
inner join unique_all_case b on a.primaryid = b.primaryid
where b.isr is null
union
select distinct drugname as drug_name_original, upper(drugname) as drug_name_clean, cast(null as integer) as concept_id, null as update_method
from drug_legacy a
inner join unique_all_case b on a.isr = b.isr
where b.isr is not null;

-- Create an index for performance improvement
drop index if exists drug_name_clean_ix;
create index drug_name_clean_ix on drug_regex_mapping(drug_name_clean);

-- Define a series of updates and exact mappings

-- Remove single quotes and double quotes
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, '[\'"]', '', 'gi')
where concept_id is null;

UPDATE drug_regex_mapping a
SET update_method = 'regex remove single quotes', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Remove ^*$? characters
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, '[\\*\\^\\$\\?]', '', 'gi')
where concept_id is null;

UPDATE drug_regex_mapping a
SET update_method = 'regex remove ^*$? punctuation chars', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Change backslash to forward slash
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, '\\\\', '/', 'gi')
where concept_id is null;

UPDATE drug_regex_mapping a
SET update_method = 'regex change backslash to forward slash', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Remove spaces before closing parenthesis
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, ' +\\)', ')', 'gi')
where concept_id is null;

UPDATE drug_regex_mapping a
SET update_method = 'regex remove spaces before closing parenthesis', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Remove UNKNOWN or UNK except at the start of the drug name
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, '\\b(UNKNOWN|UNK)\\b', '', 'gi')
where concept_id is null
and drug_name_clean ~* '\\b(UNKNOWN|UNK)\\b';

UPDATE drug_regex_mapping a
SET update_method = 'regex remove (unknown)', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Remove BLINDED
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, '\\bBLINDED\\b', '', 'gi')
where concept_id is null;

UPDATE drug_regex_mapping a
SET update_method = 'regex remove blinded', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Remove /nnnnn/ pattern
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, '\\/\\d+\\/', '', 'gi')
where concept_id is null
and drug_name_original ~* '.*\\/\\d+\\/.*';

-- Remove trailing spaces
update drug_regex_mapping
set drug_name_clean = regexp_replace(drug_name_clean, ' +$', '', 'gi')
where concept_id is null;

UPDATE drug_regex_mapping a
SET update_method = 'regex remove /nnnnn/', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Map vitamins where only brand name or generic description is provided
update drug_regex_mapping
set drug_name_clean = 'MULTIVITAMIN PREPARATION'
where drug_name_clean like '%VITAMIN%' and drug_name_clean not like '%VITAMIN A%' and drug_name_clean not like '%VITAMIN B%'
and drug_name_clean not like '%VITAMIN C%' and drug_name_clean not like '%VITAMIN K%' and drug_name_clean not like '%VITAMIN D%' 
and drug_name_clean not like '%VITAMIN E%' and concept_id is null;

UPDATE drug_regex_mapping a
SET update_method = 'regex vitamins', concept_id = CAST(b.concept_id AS integer)
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.drug_name_clean
and a.concept_id is null;

-- Map RxNorm concepts for multi-ingredient drugs and complex names

-- Create table for the combined mapping of single and multiple ingredients and brand names
drop table if exists drug_regex_mapping_words;
create table drug_regex_mapping_words as
select distinct *
from (
    select drug_name_original, concept_name, concept_id, update_method, unnest(word_list::text[]) as word
    from (
        select drug_name_original, concept_name, concept_id, update_method, regexp_split_to_array(upper(drug_name_original), E'[ \\,,\\(,\\),\\{,\\},\\\\,/,\\^,%,\\.,~,`,@,#,$,;,\\:,\"\'\\?<>\\&\\^!\\*_+=]+') as word_list
        from (
            select distinct drugname as drug_name_original, cast(null as varchar) as concept_name, cast(null as integer) as concept_id, null as update_method
            from drug a
            inner join unique_all_case b on a.primaryid = b.primaryid
            where b.isr is null
            union
            select distinct drugname as drug_name_original, cast(null as varchar) as concept_name, cast(null as integer) as concept_id, null as update_method
            from drug_legacy a
            inner join unique_all_case b on a.isr = b.isr
            where b.isr is not null
        ) aa
    ) bb
) cc 
where word NOT IN ('','SYRUP','HCL','HYDROCHLORIDE', 'ACETIC','SODIUM','CALCIUM','SULPHATE','MONOHYDRATE');

-- Create a target mapping table of multi-ingredient drug names
drop table if exists rxnorm_mapping_multi_ingredient_list;
create table rxnorm_mapping_multi_ingredient_list as
select ingredient_list, max(concept_id) as concept_id, max(concept_name) as concept_name
from (
    select concept_id, concept_name, string_agg(word, ' ' order by word) as ingredient_list
    from (
        select concept_id, concept_name, unnest(word_list::text[]) as word
        from (
            select concept_id, concept_name, regexp_split_to_array(upper(concept_name), E'[ \\,,\\(,\\),\\{,\\},\\\\,/,\\^,%,\\.,~,`,@,#,$,;,\\:,\"\'\\?<>\\&\\^!\\*_+=]+') as word_list
            from (
                select upper(concept_name) as concept_name, concept_id
                from cdmv5.concept b
                where b.vocabulary_id = 'RxNorm'
                and b.concept_class_id = 'Clinical Drug Form'
                and concept_name like '%/%'
            ) aa
        ) bb
    ) cc
    where word not in ('')
    and word not in (select distinct unnest(regexp_split_to_array(upper(concept_name), E'[ \\,,\\(,\\),\\{,\\},\\\\,/,\\^,%,\\.,~,`,@,#,$,;,\\:,\"\'\\?<>\\&\\^!\\*_+=]+'))
        from cdmv5.concept b
        where b.vocabulary_id = 'RxNorm'
        and b.concept_class_id = 'Dose Form')
    and word not in ('','-', ' ', 'A', 'AND', 'EX', 'OF', 'WITH')
    group by concept_id, concept_name
) dd
group by ingredient_list;

-- Create a source multi-ingredient drug mapping table
drop table if exists drug_mapping_multi_ingredient_list;
create table drug_mapping_multi_ingredient_list as
select drug_name_original, ingredient_list, max(concept_id) as concept_id, max(concept_name) as concept_name
from (
    select concept_id, drug_name_original, concept_name, string_agg(word, ' ' order by word) as ingredient_list
    from (
        select distinct concept_id, drug_name_original, concept_name, unnest(word_list::text[]) as word
        from (
            select concept_id, drug_name_original, concept_name, regexp_split_to_array(upper(drug_name_original), E'[ \\,,\\(,\\),\\{,\\},\\\\,/,\\^,%,\\.,~,`,@,#,$,;,\\:,\"\'\\?<>\\&\\^!\\*_+=]+') as word_list
            from (
                select distinct drugname as drug_name_original, cast(null as varchar) as concept_name, cast(null as integer) as concept_id, null as update_method
                from drug a
                inner join unique_all_case b on a.primaryid = b.primaryid
                where b.isr is null
                union
                select distinct drugname as drug_name_original, cast(null as varchar) as concept_name, cast(null as integer) as concept_id, null as update_method
                from drug_legacy a
                inner join unique_all_case b on a.isr = b.isr
                where b.isr is not null
            ) aa
        ) bb
    ) cc
    where word not in ('')
    and word not in (select distinct unnest(regexp_split_to_array(upper(concept_name), E'[ \\,,\\(,\\),\\{,\\},\\\\,/,\\^,%,\\.,~,`,@,#,$,;,\\:,\"\'\\?<>\\&\\^!\\*_+=]+'))
        from cdmv5.concept b
        where b.vocabulary_id = 'RxNorm'
        and b.concept_class_id = 'Dose Form')
    and word in (select distinct unnest(regexp_split_to_array(upper(concept_name), E'[ \\,,\\(,\\),\\{,\\},\\\\,/,\\^,%,\\.,~,`,@,#,$,;,\\:,\"\'\\?<>\\&\\^!\\*_+=]+'))
        from cdmv5.concept b
        where b.vocabulary_id = 'RxNorm'
        and b.concept_class_id in ('Clinical Drug Form')
        and b.concept_name like '%/%')
    group by concept_id, drug_name_original, concept_name
) dd
group by drug_name_original, ingredient_list;

-- Map multi-ingredient drug names to clinical drug form
update drug_regex_mapping_words c
SET update_method = 'multiple ingredient match', concept_name = b.concept_name, concept_id = b.concept_id
from (
    select distinct a.drug_name_original, max(upper(b1.concept_name)) as concept_name, max(b1.concept_id) as concept_id
    from drug_mapping_multi_ingredient_list a
    inner join rxnorm_mapping_multi_ingredient_list b1
    on a.ingredient_list = b1.ingredient_list
    group by a.drug_name_original
) b
where c.drug_name_original = b.drug_name_original
and c.concept_id is null;

-- Create a target mapping table of single ingredient drug names
drop table if exists rxnorm_mapping_single_ingredient_list;
create table rxnorm_mapping_single_ingredient_list as
select ingredient_list, max(concept_id) as concept_id, max(concept_name) as concept_name
from (
    select concept_id, concept_name, string_agg(word, ' ' order by word) as ingredient_list
    from (
        select concept_id, concept_name, unnest(word_list::text[]) as word
        from (
            select concept_id, concept_name, regexp_split_to_array(upper(concept_name), E'[ \\,,\\(,\\),\\{,\\},\\\\,/,\\^,%,\\.,~,`,@,#,$,;,\\:,\"\'\\?<>\\&\\^!\\*_+=]+') as word_list
            from (
                select upper(concept_name) as concept_name, concept_id
                from cdmv5.concept b
                where b.vocabulary_id = 'RxNorm'
                and b.concept_class_id = 'Ingredient'
            ) aa
        ) bb
    ) cc
    where word not in ('')
    and word not in (select distinct unnest(regexp_split_to_array(upper(concept_name), E'[ \\,,\\(,\\),\\{,\\},\\\\,/,\\^,%,\\.,~,`,@,#,$,;,\\:,\"\'\\?<>\\&\\^!\\*_+=]+'))
        from cdmv5.concept b
        where b.vocabulary_id = 'RxNorm'
        and b.concept_class_id = 'Dose Form')
    and word not in ('','-', ' ', 'A', 'AND', 'EX', 'OF', 'WITH')
    group by concept_id, concept_name
) dd
group by ingredient_list;

-- Create a source single-ingredient drug mapping table
drop table if exists drug_mapping_single_ingredient_list;
create table drug_mapping_single_ingredient_list as
select drug_name_original, ingredient_list, max(concept_id) as concept_id, max(concept_name) as concept_name
from (
    select concept_id, drug_name_original, concept_name, string_agg(word, ' ' order by word) as ingredient_list
    from (
        select distinct concept_id, drug_name_original, concept_name, unnest(word_list::text[]) as word
        from (
            select concept_id, drug_name_original, concept_name, regexp_split_to_array(upper(drug_name_original), E'[ \\,,\\(,\\),\\{,\\},\\\\,/,\\^,%,\\.,~,`,@,#,$,;,\\:,\"\'\\?<>\\&\\^!\\*_+=]+') as word_list
            from (
                select distinct drugname as drug_name_original, cast(null as varchar) as concept_name, cast(null as integer) as concept_id, null as update_method
                from drug a
                inner join unique_all_case b on a.primaryid = b.primaryid
                where b.isr is null and drugname not like '%/%' and drugname not like '% AND %' and drugname not like '% WITH %' and drugname not like '%+%'
                union
                select distinct drugname as drug_name_original, cast(null as varchar) as concept_name, cast(null as integer) as concept_id, null as update_method
                from drug_legacy a
                inner join unique_all_case b on a.isr = b.isr
                where b.isr is not null and drugname not like '%/%' and drugname not like '% AND %' and drugname not like '% WITH %' and drugname not like '%+%'
            ) aa
        ) bb
    ) cc
    where word not in ('')
    and word not in (select distinct unnest(regexp_split_to_array(upper(concept_name), E'[ \\,,\\(,\\),\\{,\\},\\\\,/,\\^,%,\\.,~,`,@,#,$,;,\\:,\"\'\\?<>\\&\\^!\\*_+=]+'))
        from cdmv5.concept b
        where b.vocabulary_id = 'RxNorm'
        and b.concept_class_id = 'Dose Form')
    and word in (select distinct unnest(regexp_split_to_array(upper(concept_name), E'[ \\,,\\(,\\),\\{,\\},\\\\,/,\\^,%,\\.,~,`,@,#,$,;,\\:,\"\'\\?<>\\&\\^!\\*_+=]+'))
        from cdmv5.concept b
        where b.vocabulary_id = 'RxNorm'
        and b.concept_class_id in ('Ingredient'))
    group by concept_id, drug_name_original, concept_name
) dd
group by drug_name_original, ingredient_list;

-- Map single-ingredient drug names to ingredient concepts
update drug_regex_mapping_words c
SET update_method = 'single ingredient match', concept_name = b.concept_name, concept_id = b.concept_id
from (
    select distinct a.drug_name_original, max(upper(b1.concept_name)) as concept_name, max(b1.concept_id) as concept_id
    from drug_mapping_single_ingredient_list a
    inner join rxnorm_mapping_single_ingredient_list b1
    on a.ingredient_list = b1.ingredient_list
    group by a.drug_name_original
) b
where c.drug_name_original = b.drug_name_original
and c.update_method is null and b.concept_name not in ('VITAMIN A','SODIUM','HYDROCHLORIDE','HCL','CALCIUM','COLD CREAM','VITAMIN B 12','MALEATE','TARTRATE','MESYLATE','MONOHYDRATE','SUCCINATE','CORN SYRUP','FACTOR X','PROTEIN S');

-- Create a target mapping table of brand names
drop table if exists rxnorm_mapping_brand_name_list;
create table rxnorm_mapping_brand_name_list as
select ingredient_list, max(concept_id) as concept_id, max(concept_name) as concept_name
from (
    select concept_id, concept_name, string_agg(word, ' ' order by word) as ingredient_list
    from (
        select concept_id, concept_name, unnest(word_list::text[]) as word
        from (
            select concept_id, concept_name, regexp_split_to_array(upper(concept_name), E'[\\ \\,,\\(,\\),\\{,\\},\\\\,/,\\^,%,\\.,~,`,@,#,$,;,\\:,\"\'\\?<>\\&\\^!\\*_+=]+') as word_list
            from (
                select upper(concept_name) as concept_name, concept_id
                from cdmv5.concept b
                where b.vocabulary_id = 'RxNorm'
                and b.concept_class_id = 'Brand Name'
            ) aa
        ) bb
    ) cc
    where word not in ('')
    and word not in (select distinct unnest(regexp_split_to_array(upper(concept_name), E'[\\ \\,,\\(,\\),\\{,\\},\\\\,/,\\^,%,\\.,~,`,@,#,$,;,\\:,\"\'\\?<>\\&\\^!\\*_+=]+'))
        from cdmv5.concept b
        where b.vocabulary_id = 'RxNorm'
        and b.concept_class_id = 'Dose Form')
    and word not in ('','-', ' ', 'A', 'AND', 'EX', 'OF', 'WITH')
    group by concept_id, concept_name
) dd
group by ingredient_list;

-- Create a source brand name drug mapping table
drop table if exists drug_mapping_brand_name_list;
create table drug_mapping_brand_name_list as
select drug_name_original, ingredient_list, max(concept_id) as concept_id, max(concept_name) as concept_name
from (
    select concept_id, drug_name_original, concept_name, string_agg(word, ' ' order by word) as ingredient_list
    from (
        select distinct concept_id, drug_name_original, concept_name, unnest(word_list::text[]) as word
        from (
            select concept_id, drug_name_original, concept_name, regexp_split_to_array(upper(drug_name_original), E'[\\ \\,,\\(,\\),\\{,\\},\\\\,/,\\^,%,\\.,~,`,@,#,$,;,\\:,\"\'\\?<>\\&\\^!\\*_+=]+') as word_list
            from (
                select distinct drugname as drug_name_original, cast(null as varchar) as concept_name, cast(null as integer) as concept_id, null as update_method
                from drug a
                inner join unique_all_case b on a.primaryid = b.primaryid
                where b.isr is null and drugname not like '%/%' and drugname not like '% AND %' and drugname not like '% WITH %' and drugname not like '%+%'
                union
                select distinct drugname as drug_name_original, cast(null as varchar) as concept_name, cast(null as integer) as concept_id, null as update_method
                from drug_legacy a
                inner join unique_all_case b on a.isr = b.isr
                where b.isr is not null and drugname not like '%/%' and drugname not like '% AND %' and drugname not like '% WITH %' and drugname not like '%+%'
            ) aa
        ) bb
    ) cc
    where word not in ('')
    and word not in (select distinct unnest(regexp_split_to_array(upper(concept_name), E'[\\ \\,,\\(,\\),\\{,\\},\\\\,/,\\^,%,\\.,~,`,@,#,$,;,\\:,\"\'\\?<>\\&\\^!\\*_+=]+'))
        from cdmv5.concept b
        where b.vocabulary_id = 'RxNorm'
        and b.concept_class_id = 'Dose Form')
    and word in (select distinct unnest(regexp_split_to_array(upper(concept_name), E'[\\ \\,,\\(,\\),\\{,\\},\\\\,/,\\^,%,\\.,~,`,@,#,$,;,\\:,\"\'\\?<>\\&\\^!\\*_+=]+'))
        from cdmv5.concept b
        where b.vocabulary_id = 'RxNorm'
        and b.concept_class_id in ('Brand Name'))
    group by concept_id, drug_name_original, concept_name
) dd
group by drug_name_original, ingredient_list;

-- Map brand name drug names to brand name concepts
update drug_regex_mapping_words c
SET update_method = 'brand name match', concept_name = b.concept_name, concept_id = b.concept_id
from (
    select distinct a.drug_name_original, max(upper(b1.concept_name)) as concept_name, max(b1.concept_id) as concept_id
    from drug_mapping_brand_name_list a
    inner join rxnorm_mapping_brand_name_list b1
    on a.ingredient_list = b1.ingredient_list
    group by a.drug_name_original
) b
where c.drug_name_original = b.drug_name_original
and c.update_method is null and b.concept_name not in ('G.B.H. SHAMPOO', 'A.P.L.', 'C.P.M.', 'ALLERGY CREAM', 'MG 217', 'ACID JELLY', 'C/T/S', 'M.A.H.', 'I.D.A.', 'N.T.A.', 'FORMULA 21', 'PRO OTIC', 'E.S.P.', 'PREPARATION H CREAM', 'H 9600 SR', '12 HOUR COLD', 'GLYCERYL T', 'G BID', 'AT 10', 'COMPOUND 347', 'MS/S', 'HYDRO 40', 'HP 502', 'LIQUID PRED', 'ORAL PEROXIDE', 'BABY GAS', 'BC POWDER 742/38/222', 'COMFORT GEL', 'MAG 64', 'K EFFERVESCENT', 'NASAL LA', 'THERAPEUTIC SHAMPOO', 'CHEWABLE CALCIUM', 'PAIN RELIEF (EFFERVESCENT)', 'STRESS LIQUID', 'IRON 300', 'FS SHAMPOO', 'T/GEL CONDITIONER', 'EX DEC', 'DR.S CREAM', 'JOINT GEL', 'CP ORAL', 'OTIC CARE', 'DR.S CREAM', 'NASAL RELIEF', 'MEDICATED BLUE', 'FE 50', 'BIOTENE TOOTHPASTE', 'VITAMIN A', 'SODIUM', 'HYDROCHLORIDE', 'HCL', 'CALCIUM', 'LONG LASTING NASAL', 'TRIPLE PASTE', 'K + POTASSIUM', 'NASAL DECONGESTANT SYRUP', 'COLD CREAM', 'VITAMIN B 12', 'MALEATE', 'TARTRATE', 'MESYLATE', 'MONOHYDRATE', 'SUCCINATE', 'CORN SYRUP', 'FACTOR X', 'PROTEIN S');

-- Update the original drug regex mapping table with the brand names, multiple and single ingredient drug names
update drug_regex_mapping c
SET update_method = b.update_method, drug_name_clean = b.concept_name, concept_id = b.concept_id
from (
    select distinct drug_name_original, concept_name, concept_id, update_method from drug_regex_mapping_words where concept_id is not null
) b
where c.drug_name_original = b.drug_name_original
and c.update_method is null;

-- Create active ingredient mapping table
drop table if exists drug_ai_mapping;
create table drug_ai_mapping as
select distinct drugname as drug_name_original, prod_ai, cast(null as integer) as concept_id, null as update_method
from drug a
inner join unique_all_case b on a.primaryid = b.primaryid where b.isr is null;

drop index if exists prod_ai_ix;
create index prod_ai_ix on drug_ai_mapping(prod_ai);

-- Find exact mapping using the active ingredient provided in the drug table
UPDATE drug_ai_mapping a
SET update_method = 'drug active ingredients', concept_id = b.concept_id::integer
FROM cdmv5.concept b
WHERE b.vocabulary_id = 'RxNorm'
AND upper(b.concept_name) = a.prod_ai;

-- Create NDA (new drug application) number mapping table
drop table if exists drug_nda_mapping;
create table drug_nda_mapping as
select distinct drug_name_original, nda_num, cast(null as integer) as concept_id, null as update_method
from (
    select distinct drugname as drug_name_original, nda_num, cast(null as integer) as concept_id, null as update_method
    from drug a
    inner join unique_all_case b on a.primaryid = b.primaryid
    where b.isr is null and nda_num is not null
    union
    select distinct drugname as drug_name_original, nda_num, cast(null as integer) as concept_id, null as update_method
    from drug_legacy a
    inner join unique_all_case b on a.isr = b.isr
    where b.isr is not null and nda_num is not null
) aa;

drop index if exists nda_num_ix;
create index nda_num_ix on drug_nda_mapping(nda_num);

-- Find exact mapping using the drug table nda_num
UPDATE drug_nda_mapping a
SET update_method = 'drug nda_num ingredients', concept_id = b.concept_id::integer
FROM cdmv5.concept b
INNER JOIN nda_ingredient
ON upper(b.concept_name) = upper(nda_ingredient.ingredient)
WHERE b.vocabulary_id = 'RxNorm'
AND nda_ingredient.appl_no = a.nda_num;

-- Combine all the different types of mapping into a single combined drug mapping table across legacy LAERS data and current FAERS data
drop table if exists combined_drug_mapping;
create table combined_drug_mapping as
select distinct primaryid, isr, drug_seq, role_cod, drug_name_original, lookup_value, concept_id, update_method
from (
    select distinct b.primaryid, b.isr, drug_seq, role_cod, drugname as drug_name_original, cast(null as varchar) as lookup_value, cast(null as integer) as concept_id, cast(null as varchar) as update_method
    from drug a
    inner join unique_all_case b on a.primaryid = b.primaryid
    where b.isr is null
    union
    select distinct b.primaryid, b.isr, drug_seq, role_cod, drugname as drug_name_original, cast(null as varchar) as lookup_value, cast(null as integer) as concept_id, cast(null as varchar) as update_method
    from drug_legacy a
    inner join unique_all_case b on a.isr = b.isr
    where b.isr is not null
) aa ;

drop index if exists combined_drug_mapping_ix;
create index combined_drug_mapping_ix on combined_drug_mapping(upper(drug_name_original));

-- Update using drug_regex_mapping
UPDATE combined_drug_mapping a
SET update_method = b.update_method, lookup_value = drug_name_clean, concept_id = b.concept_id::integer
FROM drug_regex_mapping b
WHERE upper(a.drug_name_original) = upper(b.drug_name_original)
AND a.concept_id IS NULL
AND b.concept_id IS NOT NULL;

-- Update using drug_ai_mapping
UPDATE combined_drug_mapping a
SET update_method = b.update_method, lookup_value = prod_ai, concept_id = b.concept_id::integer
FROM drug_ai_mapping b
WHERE upper(a.drug_name_original) = upper(b.drug_name_original)
AND a.concept_id IS NULL
AND b.concept_id IS NOT NULL;

-- Update using drug_nda_mapping
UPDATE combined_drug_mapping a
SET update_method = b.update_method, lookup_value = nda_ingredient, concept_id = b.concept_id::integer
FROM drug_nda_mapping b
WHERE upper(a.drug_name_original) = upper(b.drug_name_original)
AND a.concept_id IS NULL
AND b.concept_id IS NOT NULL;

-- Update using drug_usagi_mapping (manually curated drug mappings)
UPDATE combined_drug_mapping a
SET update_method = b.update_method, lookup_value = b.concept_name, concept_id = b.concept_id::integer
FROM drug_usagi_mapping b
WHERE upper(a.drug_name_original) = upper(b.drug_name_original)
AND a.concept_id IS NULL
AND b.concept_id IS NOT NULL;

-- Update unknown drugs where drug name starts with UNKNOWN, OTHER, or UNSPECIFIED
update combined_drug_mapping 
set update_method = 'unknown drug'
where upper(drug_name_original) ~* '^UNKNOWN.*' 
or upper(drug_name_original) ~* '^OTHER.*'
or upper(drug_name_original) ~* '^UNSPECIFIED.*'
and update_method is null;
