set search_path = faers;

drop table if exists demo_legacy_staging_version_a;
create table demo_legacy_staging_version_a
(
ISR varchar,
"CASE" varchar,
I_F_COD varchar,
FOLL_SEQ varchar,
IMAGE varchar,
EVENT_DT varchar,
MFR_DT varchar,
FDA_DT varchar,
REPT_COD varchar,
MFR_NUM varchar,
MFR_SNDR varchar,
AGE varchar,
AGE_COD varchar,
GNDR_COD varchar,
E_SUB varchar,
WT varchar,
WT_COD varchar,
REPT_DT varchar,
OCCP_COD varchar,
DEATH_DT varchar,
TO_MFR varchar,
CONFID varchar,
REPORTER_COUNTRY varchar,
FILENAME varchar
);
truncate demo_legacy_staging_version_a;

COPY demo_legacy_staging_version_a FROM 'D:\Legacy\all_version_A_demo_legacy_data_with_filename.txt' WITH DELIMITER E'$' CSV HEADER QUOTE E'\b' ;
select distinct filename from demo_legacy_staging_version_a order by 1 limit 10;

drop table if exists demo_legacy_staging_version_b;
create table demo_legacy_staging_version_b
(
ISR varchar,
"CASE" varchar,
I_F_COD varchar,
FOLL_SEQ varchar,
IMAGE varchar,
EVENT_DT varchar,
MFR_DT varchar,
FDA_DT varchar,
REPT_COD varchar,
MFR_NUM varchar,
MFR_SNDR varchar,
AGE varchar,
AGE_COD varchar,
GNDR_COD varchar,
E_SUB varchar,
WT varchar,
WT_COD varchar,
REPT_DT varchar,
OCCP_COD varchar,
DEATH_DT varchar,
TO_MFR varchar,
CONFID varchar,
REPORTER_COUNTRY varchar,
FILENAME varchar
);
truncate demo_legacy_staging_version_b;

COPY demo_legacy_staging_version_b FROM 'D:\Legacy\all_version_B_demo_legacy_data_with_filename.txt' WITH DELIMITER E'$' CSV HEADER QUOTE E'\b' ;
select distinct filename from demo_legacy_staging_version_b order by 1 ;

drop table if exists demo_legacy ;
create table demo_legacy as
select
ISR,
"CASE",
I_F_COD,
FOLL_SEQ,
IMAGE,
EVENT_DT,
MFR_DT,
FDA_DT,
REPT_COD,
MFR_NUM,
MFR_SNDR,
AGE,
AGE_COD,
GNDR_COD,
E_SUB,
WT,
WT_COD,
REPT_DT,
OCCP_COD,
DEATH_DT,
TO_MFR,
CONFID,
null as REPORTER_COUNTRY,
FILENAME
from demo_legacy_staging_version_a
union all
select * from demo_legacy_staging_version_b;
