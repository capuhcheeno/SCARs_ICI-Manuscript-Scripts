set search_path = faers;

-- ====================== find active OMOP CDM vocabulary standard RxNorm codes ==============================

-- Create a combined drug mapping table with OHDSI vocabulary standard concept codes assigned to it

drop table if exists standard_combined_drug_mapping;

create table standard_combined_drug_mapping as
select a.*, cast(concept_id as integer) as standard_concept_id 
from combined_drug_mapping a;

DO $$
BEGIN
    RAISE NOTICE 'Step 1: Created standard_combined_drug_mapping table';
END $$;

-- Ensure proper indexing before running the query
DO $$
BEGIN
    RAISE NOTICE 'Step 0: Ensuring proper indexing';
    PERFORM
        'CREATE INDEX IF NOT EXISTS idx_scdm_standard_concept_id ON standard_combined_drug_mapping (standard_concept_id)',
        'CREATE INDEX IF NOT EXISTS idx_cdmv5_concept_id ON cdmv5.concept (concept_id)',
        'CREATE INDEX IF NOT EXISTS idx_cdmv5_concept_vocabulary_id ON cdmv5.concept (vocabulary_id)',
        'CREATE INDEX IF NOT EXISTS idx_cdmv5_concept_class_id ON cdmv5.concept (concept_class_id)',
        'CREATE INDEX IF NOT EXISTS idx_cdmv5_concept_relationship_concept_id_1 ON cdmv5.concept_relationship (concept_id_1)',
        'CREATE INDEX IF NOT EXISTS idx_cdmv5_concept_relationship_concept_id_2 ON cdmv5.concept_relationship (concept_id_2)';
END $$;

-- Directly lookup the standard concept associated with the drug concepts derived from drug names
with combined_cte as (
    select distinct scdm.standard_concept_id, c.concept_class_id, c.invalid_reason
    from standard_combined_drug_mapping scdm
    join cdmv5.concept c on scdm.standard_concept_id = cast(c.concept_id as integer)
    where scdm.concept_id is not null
),
mapped_cte as (
    select cast(cr.concept_id_1 as integer) as concept_id_1, cast(cr.concept_id_2 as integer) as concept_id_2
    from cdmv5.concept_relationship cr
    join cdmv5.concept a on cast(cr.concept_id_1 as integer) = cast(a.concept_id as integer)
    join cdmv5.concept b on cast(cr.concept_id_2 as integer) = cast(b.concept_id as integer)
    where cr.invalid_reason is null
    and a.vocabulary_id = 'RxNorm'
    and b.vocabulary_id = 'RxNorm'
    and b.standard_concept = 'S'
    and b.concept_class_id in ('Ingredient','Clinical Drug Form')
)
update standard_combined_drug_mapping scdm
set standard_concept_id = mapped_cte.concept_id_2
from combined_cte cte
join mapped_cte on cte.standard_concept_id = mapped_cte.concept_id_1
where scdm.standard_concept_id = mapped_cte.concept_id_1
and cte.concept_class_id is null;

DO $$
BEGIN
    RAISE NOTICE 'Step 2: Updated standard_combined_drug_mapping with standard concepts';
END $$;

-- Convert standard branded drug form to standard ingredient or clinical drug form
with cte_branded as (
    select distinct scdm.standard_concept_id
    from standard_combined_drug_mapping scdm
    join cdmv5.concept c on scdm.standard_concept_id = cast(c.concept_id as integer)
    where scdm.concept_id is not null
    and c.concept_class_id = 'Branded Drug Form'
),
mapped_cte as (
    select cast(cr.concept_id_1 as integer) as concept_id_1, cast(cr.concept_id_2 as integer) as concept_id_2
    from cdmv5.concept_relationship cr
    join cdmv5.concept a on cast(cr.concept_id_1 as integer) = cast(a.concept_id as integer)
    join cdmv5.concept b on cast(cr.concept_id_2 as integer) = cast(b.concept_id as integer)
    where cr.invalid_reason is null
    and a.vocabulary_id = 'RxNorm'
    and b.vocabulary_id = 'RxNorm'
    and b.standard_concept = 'S'
    and b.concept_class_id in ('Ingredient','Clinical Drug Form')
)
update standard_combined_drug_mapping scdm
set standard_concept_id = mapped_cte.concept_id_2
from cte_branded
join mapped_cte on cte_branded.standard_concept_id = mapped_cte.concept_id_1
where scdm.standard_concept_id = mapped_cte.concept_id_1;

DO $$
BEGIN
    RAISE NOTICE 'Step 3: Converted Branded Drug Form to Ingredient or Clinical Drug Form';
END $$;

-- Step 4: Convert precise ingredient to standard ingredient or clinical drug form
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    RAISE NOTICE 'Step 4: Start mapping precise ingredients to standard ingredients or clinical drug forms';

    WITH cte_precise AS (
        SELECT DISTINCT scdm.standard_concept_id
        FROM standard_combined_drug_mapping scdm
        JOIN cdmv5.concept c ON scdm.standard_concept_id = cast(c.concept_id as integer)
        WHERE scdm.concept_id IS NOT NULL
        AND c.concept_class_id = 'Precise Ingredient'
    ),
    mapped_precise AS (
        SELECT cast(c1.concept_id as integer) AS concept_id_1, cast(c2.concept_id as integer) AS concept_id_2
        FROM cdmv5.concept c1
        JOIN cdmv5.concept c2 ON c2.concept_name = regexp_replace(c1.concept_name, ' decanoate$| hemihydrate$| aluminum$| tetrahydrate$| hexahydrate$| oxilate$| pivalate$| sulphonate$| anhydrous$| valerate$| dihydrate$| saccharate$| diacetate$| monosodium$| palmitate$| monophosphate$| stearate$| disodium$| propionate$| bitartrate$| pamoate$| dimesylate$| methylsulfate$| hydrobromide$| malate$| monohydrate$| silicate$| calcium$| magnesium$| tannate$| carbonate$| mesylate$| succinate$| potassium$| maleate$| benzoate$| nitrate$| citrate$| hydrate$| tartrate$| acetate$| phosphate$| dihydrochloride$| hydrochloride$| HCL$| chloride$| trihydrate$| besylate$| fumarate$| lactate$| gluconate$| bromide$| sulfate$| sodium$', '', 'i')
        WHERE c1.vocabulary_id = 'RxNorm'
        AND c1.concept_class_id = 'Precise Ingredient'
        AND c2.vocabulary_id = 'RxNorm'
        AND c2.standard_concept = 'S'
        AND c2.concept_class_id IN ('Ingredient','Clinical Drug Form')
    )
    UPDATE standard_combined_drug_mapping scdm
    SET standard_concept_id = mapped_precise.concept_id_2
    FROM cte_precise
    JOIN mapped_precise ON cte_precise.standard_concept_id = mapped_precise.concept_id_1
    WHERE scdm.standard_concept_id = cte_precise.standard_concept_id;

    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RAISE NOTICE 'Step 4: Mapped % precise ingredients to standard ingredients or clinical drug forms', updated_count;
END $$;

-- Convert brand name to standard ingredient or standard clinical drug form
with cte_brand_name as (
    select distinct scdm.standard_concept_id
    from standard_combined_drug_mapping scdm
    join cdmv5.concept c on scdm.standard_concept_id = cast(c.concept_id as integer)
    where scdm.concept_id is not null
    and c.concept_class_id = 'Brand Name'
    and c.invalid_reason is null
),
mapped_brand_name as (
    select cast(cr.concept_id_1 as integer) as concept_id_1, cast(cr.concept_id_2 as integer) as concept_id_2
    from cdmv5.concept_relationship cr
    join cdmv5.concept a on cast(cr.concept_id_1 as integer) = cast(a.concept_id as integer)
    join cdmv5.concept b on cast(cr.concept_id_2 as integer) = cast(b.concept_id as integer)
    where a.vocabulary_id = 'RxNorm'
    and b.vocabulary_id = 'RxNorm'
    and b.standard_concept = 'S'
    and b.concept_class_id in ('Ingredient','Clinical Drug Form')
    and cr.relationship_id = 'Tradename of'
)
update standard_combined_drug_mapping scdm
set standard_concept_id = mapped_brand_name.concept_id_2
from cte_brand_name
join mapped_brand_name on cte_brand_name.standard_concept_id = mapped_brand_name.concept_id_1
where scdm.standard_concept_id = mapped_brand_name.concept_id_1;

DO $$
BEGIN
    RAISE NOTICE 'Step 5: Converted Brand Name to Ingredient or Clinical Drug Form';
END $$;

-- Map to the standard ingredient for a single ingredient brand name that has been updated
with cte_brand_updated as (
    select distinct scdm.standard_concept_id
    from standard_combined_drug_mapping scdm
    join cdmv5.concept c on scdm.standard_concept_id = cast(c.concept_id as integer)
    where scdm.concept_id is not null
    and c.concept_class_id = 'Brand Name'
    and c.invalid_reason = 'U'
),
mapped_brand_updated as (
    select cast(cr.concept_id_1 as integer) as concept_id_1, cast(cr.concept_id_2 as integer) as concept_id_2
    from cdmv5.concept_relationship cr
    join cdmv5.concept b on cast(cr.concept_id_1 as integer) = cast(b.concept_id as integer)
    join cdmv5.concept c on cast(cr.concept_id_2 as integer) = cast(c.concept_id as integer)
    where b.vocabulary_id = 'RxNorm'
    and c.vocabulary_id = 'RxNorm'
    and cr.relationship_id = 'Concept replaced by'
),
single_ingredient as (
    select cast(cr.concept_id_1 as integer) as concept_id_1
    from mapped_brand_updated
    join cdmv5.concept_relationship cr on mapped_brand_updated.concept_id_2 = cast(cr.concept_id_1 as integer)
    join cdmv5.concept b on cast(cr.concept_id_2 as integer) = cast(b.concept_id as integer)
    where cr.relationship_id = 'Tradename of'
    and b.vocabulary_id = 'RxNorm'
    and b.standard_concept = 'S'
    and b.invalid_reason is null
    group by cr.concept_id_1
    having count(cr.concept_id_1) = 1
)
update standard_combined_drug_mapping scdm
set standard_concept_id = cast(b.concept_id as integer)
from single_ingredient
join mapped_brand_updated on mapped_brand_updated.concept_id_2 = single_ingredient.concept_id_1
join cdmv5.concept_relationship cr on mapped_brand_updated.concept_id_2 = cast(cr.concept_id_1 as integer)
join cdmv5.concept b on cast(cr.concept_id_2 as integer) = cast(b.concept_id as integer)
where cr.relationship_id = 'Tradename of'
and b.vocabulary_id = 'RxNorm'
and b.standard_concept = 'S'
and b.invalid_reason is null
and scdm.standard_concept_id = mapped_brand_updated.concept_id_1;

DO $$
BEGIN
    RAISE NOTICE 'Step 6: Mapped updated single ingredient brand name to standard ingredient';
END $$;

-- Map to the standard ingredient for a brand name that has been deleted
with cte_brand_deleted as (
    select distinct scdm.standard_concept_id
    from standard_combined_drug_mapping scdm
    join cdmv5.concept c on scdm.standard_concept_id = cast(c.concept_id as integer)
    where scdm.concept_id is not null
    and c.concept_class_id = 'Brand Name'
    and c.invalid_reason = 'D'
),
mapped_brand_deleted as (
    select cast(cr.concept_id_1 as integer) as concept_id_1, cast(cr.concept_id_2 as integer) as concept_id_2
    from cdmv5.concept_relationship cr
    join cdmv5.concept b on cast(cr.concept_id_1 as integer) = cast(b.concept_id as integer)
    join cdmv5.concept c on cast(cr.concept_id_2 as integer) = cast(c.concept_id as integer)
    where b.vocabulary_id = 'RxNorm'
    and c.vocabulary_id = 'RxNorm'
    and cr.relationship_id = 'Tradename of'
)
update standard_combined_drug_mapping scdm
set standard_concept_id = cast(b.concept_id as integer)
from mapped_brand_deleted
join cdmv5.concept_relationship cr on mapped_brand_deleted.concept_id_2 = cast(cr.concept_id_1 as integer)
join cdmv5.concept b on cast(cr.concept_id_2 as integer) = cast(b.concept_id as integer)
where cr.relationship_id = 'Form of'
and b.vocabulary_id = 'RxNorm'
and b.standard_concept = 'S'
and b.invalid_reason is null
and scdm.standard_concept_id = mapped_brand_deleted.concept_id_1;

DO $$
BEGIN
    RAISE NOTICE 'Step 7: Mapped deleted brand name to standard ingredient or clinical drug form';
END $$;

-- Convert U or D status concepts to standard ingredient or clinical drug form
with cte_invalid as (
    select distinct scdm.standard_concept_id
    from standard_combined_drug_mapping scdm
    join cdmv5.concept c on scdm.standard_concept_id = cast(c.concept_id as integer)
    where scdm.concept_id is not null
    and c.invalid_reason in ('U','D')
),
mapped_cte as (
    select cast(cr.concept_id_1 as integer) as concept_id_1, cast(cr.concept_id_2 as integer) as concept_id_2
    from cdmv5.concept_relationship cr
    join cdmv5.concept a on cast(cr.concept_id_1 as integer) = cast(a.concept_id as integer)
    join cdmv5.concept b on cast(cr.concept_id_2 as integer) = cast(b.concept_id as integer)
    where cr.invalid_reason is null
    and a.vocabulary_id = 'RxNorm'
    and b.vocabulary_id = 'RxNorm'
    and b.standard_concept = 'S'
    and b.concept_class_id in ('Ingredient','Clinical Drug Form')
)
update standard_combined_drug_mapping scdm
set standard_concept_id = mapped_cte.concept_id_2
from cte_invalid
join mapped_cte on cte_invalid.standard_concept_id = mapped_cte.concept_id_1
where scdm.standard_concept_id = mapped_cte.concept_id_1;

DO $$
BEGIN
    RAISE NOTICE 'Step 8: Converted U or D status concepts to standard ingredient or clinical drug form';
END $$;

-- Convert the standard clinical drug form concepts (that we derived in all the previous logic) with only a single ingredient, to standard ingredient
with cte_clinical_drug_form as (
    select distinct scdm.standard_concept_id
    from standard_combined_drug_mapping scdm
    join cdmv5.concept c on scdm.standard_concept_id = cast(c.concept_id as integer)
    where scdm.concept_id is not null
    and c.concept_class_id = 'Clinical Drug Form'
    and c.concept_name not like '%/%'
),
mapped_cte as (
    select cast(cr.concept_id_1 as integer) as concept_id_1, cast(cr.concept_id_2 as integer) as concept_id_2
    from cdmv5.concept_relationship cr
    join cdmv5.concept a on cast(cr.concept_id_1 as integer) = cast(a.concept_id as integer)
    join cdmv5.concept b on cast(cr.concept_id_2 as integer) = cast(b.concept_id as integer)
    where cr.invalid_reason is null
    and a.vocabulary_id = 'RxNorm'
    and b.vocabulary_id = 'RxNorm'
    and b.standard_concept = 'S'
    and b.concept_class_id in ('Ingredient','Clinical Drug Form')
)
update standard_combined_drug_mapping scdm
set standard_concept_id = mapped_cte.concept_id_2
from cte_clinical_drug_form
join mapped_cte on cte_clinical_drug_form.standard_concept_id = mapped_cte.concept_id_1
where scdm.standard_concept_id = mapped_cte.concept_id_1;

DO $$
BEGIN
    RAISE NOTICE 'Step 9: Converted single ingredient Clinical Drug Form to standard ingredient';
END $$;

-- These updates correct some edge cases around updated and deleted status concepts that are non-trivial to map directly using the concept_relationship table
update standard_combined_drug_mapping set standard_concept_id = 745466 where standard_concept_id = 40239960; -- map concept "Valproate sodium" to "Valproate"
update standard_combined_drug_mapping set standard_concept_id = 715997 where standard_concept_id = 40011116; -- map concept "Aricept" to "donepezil"
update standard_combined_drug_mapping set standard_concept_id = 911735 where standard_concept_id = 40077081; -- map concept "Rabeprazole Sodium" to "rabeprazole"
update standard_combined_drug_mapping set standard_concept_id = 1115008 where standard_concept_id = 40064300; -- map concept "Naprosyn" to "Naproxen"
update standard_combined_drug_mapping set standard_concept_id = 40077118 where standard_concept_id = 40091355; -- map concept "Tazocin" to "Piperacillin / tazobactam Injectable Solution"
update standard_combined_drug_mapping set standard_concept_id = 964339 where standard_concept_id = 40013106; -- map concept "Azulfidine EN-tabs" to "Sulfasalazine"
update standard_combined_drug_mapping set standard_concept_id = 745466 where standard_concept_id = 40086873; -- map concept "Valproic Acid Syrup" to "Valproate"
update standard_combined_drug_mapping set standard_concept_id = 745466 where standard_concept_id = 40086835; -- map concept "Valproic Acid 500 MG" to "Valproate"
update standard_combined_drug_mapping set standard_concept_id = 19086491 where standard_concept_id = 40080434; -- map concept "Senna" to "standardized senna concentrate"
update standard_combined_drug_mapping set standard_concept_id = 1707687 where standard_concept_id = 40086904; -- map concept "Vancocin HCl" to "Vancomycin"
update standard_combined_drug_mapping set standard_concept_id = 19028106 where standard_concept_id = 40126573; -- map concept "Isopropyl Alcohol" updated to different standard concept "Isopropyl Alcohol"
update standard_combined_drug_mapping set standard_concept_id = 1516800 where standard_concept_id = 40079926; -- map concept "Risedronate Sodium" to standard concept "Risedronate"
update standard_combined_drug_mapping set standard_concept_id = 40129571 where standard_concept_id = 40223264; -- map concept "Allegra D" to standard concept "fexofenadine / Pseudoephedrine Extended Release Oral Tablet"

DO $$
BEGIN
    RAISE NOTICE 'Step 10: Corrected edge cases around updated and deleted status concepts';
END $$;

-- Create final table with just the standard ingredient and clinical drug form of the drugs
drop table if exists standard_case_drug;

create table standard_case_drug as
select distinct a.primaryid, a.isr, a.drug_seq, a.role_cod, a.standard_concept_id
from standard_combined_drug_mapping a
join cdmv5.concept c on a.standard_concept_id = cast(c.concept_id as integer)
where c.concept_class_id in ('Ingredient','Clinical Drug Form')
and c.standard_concept = 'S';

DO $$
BEGIN
    RAISE NOTICE 'Step 11: Created final standard_case_drug table';
END $$;
