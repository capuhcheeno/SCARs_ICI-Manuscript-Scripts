insert into faers.drug_usagi_mapping
select a.source_code_description as drug_name_original , 
b.concept_name, b.concept_class_id, cast(a.target_concept_id as integer) as concept_id, cast ('usagi' as text) as update_method
from faers.usagi_import a
inner join cdmv5.concept b
on cast(a.target_concept_id as integer) = b.concept_id::integer
