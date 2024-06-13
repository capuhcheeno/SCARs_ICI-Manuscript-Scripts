set search_path = faers;

drop table if exists standard_drug_outcome_statistics;
create table standard_drug_outcome_statistics as
select 
drug_concept_id, outcome_concept_id, cast(null as integer) as snomed_outcome_concept_id,
count_a as case_count,
round((count_a / (count_a + count_b)) / (count_c / (count_c + count_d)),5) as prr,
round(exp(ln((count_a / (count_a + count_b)) / (count_c / (count_c + count_d)))+1.96*sqrt((1.0/count_a)-(1.0/(count_a+count_b))+(1.0/count_c)-(1.0/(count_c+count_d)))),5) as prr_95_percent_upper_confidence_limit,
round(exp(ln((count_a / (count_a + count_b)) / (count_c / (count_c + count_d)))-1.96*sqrt((1.0/count_a)-(1.0/(count_a+count_b))+(1.0/count_c)-(1.0/(count_c+count_d)))),5) as prr_95_percent_lower_confidence_limit,
round(((count_a / count_c) / (count_b / count_d)),5) as ror,
round(exp((ln((count_a / count_c) / (count_b / count_d)))+1.96*sqrt((1.0/count_a)+(1.0/count_b)+(1.0/count_c)+(1.0/count_d))),5) as ror_95_percent_upper_confidence_limit,
round(exp((ln((count_a / count_c) / (count_b / count_d)))-1.96*sqrt((1.0/count_a)+(1.0/count_b)+(1.0/count_c)+(1.0/count_d))),5) as ror_95_percent_lower_confidence_limit
from standard_drug_outcome_contingency_table;
