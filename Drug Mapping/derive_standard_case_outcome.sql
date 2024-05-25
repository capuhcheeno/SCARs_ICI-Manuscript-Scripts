-- Set the search path
set search_path = faers;

-- Create indexes on the reac table for improved performance
drop index if exists ix_reac_1;
drop index if exists ix_reac_2;
create index ix_reac_1 on reac (upper(pt));
create index ix_reac_2 on reac (primaryid);
analyze verbose reac;

-- Create indexes on the reac_legacy table for improved performance
drop index if exists ix_reac_legacy_1;
drop index if exists ix_reac_legacy_2;
create index ix_reac_legacy_1 on reac_legacy (upper(pt));
create index ix_reac_legacy_2 on reac_legacy (isr);
analyze verbose reac_legacy;

-- Drop the standard_case_outcome table if it exists
drop table if exists standard_case_outcome;

-- Create the standard_case_outcome table
create table standard_case_outcome as
with combined_cases as (
    select a.primaryid, a.isr, b.pt, upper(b.pt) as upper_pt
    from unique_all_case a
    join reac b on a.primaryid = b.primaryid
    where a.isr is null
    union
    select a.primaryid, a.isr, b.pt, upper(b.pt) as upper_pt
    from unique_all_case a
    join reac_legacy b on a.isr = b.isr
    where a.isr is not null
)
select distinct
    c.primaryid,
    c.isr,
    c.pt,
    concept.concept_id as outcome_concept_id,
    null::integer as snomed_outcome_concept_id
from combined_cases c
left join cdmv5.concept concept
on c.upper_pt = upper(concept.concept_name)
and concept.vocabulary_id = 'MedDRA';
