-- This SQL script derives the SNOMED-CT concept codes for the legacy LARES and current FAERS outcome (categories) in a new table called standard_case_outcome_category
-- limited to just the unique cases.
set search_path = faers;

drop table if exists standard_case_outcome_category;
create table standard_case_outcome_category as
with cte1 as (
    select distinct a.primaryid, a.isr, coalesce(b.outc_code, b2.outc_cod) as outc_code
    from unique_all_case a
    left join outc b on a.primaryid = b.primaryid and a.isr is null
    left join outc_legacy b2 on a.isr = b2.isr and a.isr is not null
),
cte2 as (
    select primaryid, isr, outc_code,
        case outc_code
            when 'CA' then 4029540  -- SNOMED concept: "Congenital anomaly", OHDSI concept_id = 4029540
            when 'DE' then 4306655  -- SNOMED concept: "Death", OHDSI concept_id = 4306655
            when 'DS' then 4052648  -- SNOMED concept: "Disability", OHDSI concept_id = 4052648
            when 'HO' then 8715     -- SNOMED concept: "Hospital admission", OHDSI concept_id = 8715
            when 'LT' then 40483553 -- SNOMED concept: "Life threatening severity", OHDSI concept_id = 40483553
            when 'OT' then 4001594  -- SNOMED concept: "Non-specific", OHDSI concept_id = 4001594
            when 'RI' then 4191370  -- SNOMED concept: "Treatment required for", OHDSI concept_id = 4191370
        end as snomed_concept_id
    from cte1
)
select * from cte2;
