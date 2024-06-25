-- Create the table 
drop table if exists usagi_import;
CREATE TABLE usagi_import
(
  source_code character varying,
  source_concept_id character varying,
  source_vocabulary_id character varying,
  source_code_description character varying,
  target_concept_id character varying,
  target_vocabulary_id character varying,
  valid_start_date character varying,
  valid_end_date character varying,
  invalid_reason character varying
); 
-- Import data from CSV 
COPY usagi_import(source_code, source_concept_id, source_code_description, target_concept_id, target_vocabulary_id, valid_start_date, valid_end_date, invalid_reason) 
FROM 'D:\Mapped Usagi Codes (Non RxNorm).csv' 
DELIMITER ',' 
CSV HEADER; 
