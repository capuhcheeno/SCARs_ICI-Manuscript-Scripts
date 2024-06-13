--============= On a 4+ CPU postgresql server, run the following 3 queries in 3 different postgresql sessions so they run concurrently!
-- get count_a and count_b 
set search_path = faers;
drop table if exists standard_drug_outcome_count_a_count_b;
create table standard_drug_outcome_count_a_count_b as
select drug_concept_id, outcome_concept_id, 
drug_outcome_pair_count as count_a, -- count of drug P and outcome R
(
	select sum(drug_outcome_pair_count)
	from standard_drug_outcome_count b
	where b.drug_concept_id = a.drug_concept_id and b.outcome_concept_id <> a.outcome_concept_id 
) as count_b -- count of drug P and not(outcome R)
from standard_drug_outcome_count a;

-- get count_c 
set search_path = faers;
drop table if exists standard_drug_outcome_count_c;
create table standard_drug_outcome_count_c as
select drug_concept_id, outcome_concept_id, 
(
	select sum(drug_outcome_pair_count) 
	from standard_drug_outcome_count c
	where c.drug_concept_id <> a.drug_concept_id and c.outcome_concept_id = a.outcome_concept_id 
) as count_c -- count of not(drug P) and outcome R
from standard_drug_outcome_count a; 

-- get count d2 
set search_path = faers;
drop table if exists standard_drug_outcome_count_d2;
create table standard_drug_outcome_count_d2 as
select drug_concept_id, outcome_concept_id, 
(
	select sum(drug_outcome_pair_count)
	from standard_drug_outcome_count d2
	where (d2.drug_concept_id = a.drug_concept_id) or (d2.outcome_concept_id = a.outcome_concept_id)
) as count_d2 -- count of all cases where drug P or outcome R 
from standard_drug_outcome_count a;
