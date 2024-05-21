select row_number() over () as source_code, 
upper(drug_name_original) as source_code_description, 
count(*) as frequency -- (case frequency)
from combined_drug_mapping where concept_id is null
group by upper(drug_name_original)
order by count(*) desc
