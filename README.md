
# Instructions to Standardize FAERS Data

## System Requirements
- Operating System: Linux (Developed on Cygwin 3.5.3 on Windows)
- Python Client: PyCharm 2024.2.0.1 (with Python version 3.12)
- Database: PostgreSQL 16.3 (with PgAdmin IV)
- Mapping Tool: OHDSI Usagi
- Text Editor: Notepad++
- GitHub Repository: https://github.com/capuhcheeno/SCARs_ICI-Manuscript-Scripts

## Reference Data Preparation
**Scripts located in**: `SCARs_ICI-Manuscript-Scripts/Reference Data Prerequisites`

### Steps:
1. **Create a schema named `faers`.**
   - Load FDA Orange Book Data:
     - Download from the FDA Orange Book website (https://www.fda.gov/drugs/drug-approvals-and-databases/orange-book-data-files)
     - Execute `load_nda_table.sql`
   - Load reference tables:
     - **Country Codes**: Execute `load_country_code_table.sql` using `ISO_3166-1_country_codes.csv` file from `Reference Data Prerequisites`
     - **EU Drug Names and Ingredients**: Execute `load_eu_drug_name_active_ingredient.sql` using `EU_registered_drugs_by_active_ingredient_utf8.txt` file from `Reference Data Prerequisites`

2. **Create a schema named `cdmv5`.**
   - Load vocabulary tables:
     - Download from OHDSI Athena (https://athena.ohdsi.org/vocabulary/list)
     - Keep the pre-selected vocabularies and select the MedDRA vocabulary (MSSO)
       - Review the EULA link for MedDRA and request access
     - Download the `.env` and `requirements.txt` file from `Reference Data Prerequisites/Loading OHDSI CDMV5 Vocabulary Tables`
       - Fill in your credentials for SQL server in the `.env` file 
     - Execute `Creating Tables in cdmv5 Schema.py`
     - Execute `Loading Tables into PostgreSQL.py`
   - Create mapping table:
     - Execute `create_meddra_snomed_mapping_table.sql`

## FAERS Data Preparation
**Scripts located in**: `SCARs_ICI-Manuscript-Scripts/Load Data Files from FAERS Website`

### Steps:
1. **Download the current FAERS data.**
   - Execute `download_current_files_from_faers.sh`.
   - Combine current FAERS data files by executing all the following files:
     - `create_current_all_demo_data_files_with_filename_column.sh`
     - `create_current_all_drug_data_files_with_filename_column.sh`
     - `create_current_all_indi_data_file_with_filename_column.sh`
     - `create_current_all_outc_data_file_with_filename_column.sh`
     - `create_current_all_reac_data_files_with_filename_column.sh`
     - `create_current_all_rpsr_data_file_with_filename_column.sh`
     - `create_current_all_ther_data_file_with_filename_column.sh`
   - Load current FAERS data files by executing the following files:
     - `load_current_demo_table.sql`
     - `load_current_drug_table.sql`
     - `load_current_indi_table.sql`
     - `load_current_outc_table.sql`
     - `load_current_reac_table.sql`
     - `load_current_rpsr_table.sql`
     - `load_current_ther_table.sql`
       
   - **Troubleshooting possible formatting issues:**
     - Insert a `$` immediately before the column name `filename`
     - Keep only the first header row and delete any additional header rows in `all_version_A_demo_data_with_filename`, `all_version_A_drug_data_with_filename`, `all_version_A_reac_data_with_filename`
     - Replace every occurrence of `   /ascii` with a `$`
     - Run the script `Load Data Files from FAERS Website/UTF8 Solution.py` for `all_version_B_drug_data_with_filename` to re-encode

2. **Download and prepare the legacy FAERS data.**
   - Execute `download_legacy_files_from_faers.sh`.
   - Manually add in 2004 Q4 and 2005 Q3 into the `ascii` folder from https://fis.fda.gov/extensions/FPD-QDE-FAERS/FPD-QDE-FAERS.html.
   - Combine legacy FAERS data files by executing all the following files:
     - `create_legacy_all_demo_data_files_with_filename_column.sh`
       - Using Notepad++, open the file `all_version_B_demo_legacy_data_with_filename.txt`.
       - Replace `8129732$8401177$I$$8129732-9$20120126$20120206$20120210$EXP$JP-CUBIST-$E2B0000000182$CUBIST PHARMACEUTICALS, INC.$85$YR$M$Y$$$20120210$PH$$$$JAPAN$DEMO12Q1.TXT` with `8129732$8401177$I$$8129732-9$20120126$20120206$20120210$EXP$JP-CUBIST-E2B0000000182$CUBIST PHARMACEUTICALS, INC.$85$YR$M$Y$$$20120210$PH$$$$JAPAN$DEMO12Q1`.
     - Other scripts:
       - `create_legacy_all_drug_data_files_with_filename_column.sh`
       - `create_legacy_all_indi_data_file_with_filename_column.sh`
       - `create_legacy_all_outc_data_file_with_filename_column.sh`
       - `create_legacy_all_reac_data_file_with_filename_column.sh`
       - `create_legacy_all_rpsr_data_file_with_filename_column.sh`
       - `create_legacy_all_ther_data_file_with_filename_column.sh`
   - Load legacy FAERS data files by executing the following files:
     - `load_legacy_demo_table.sql`
     - `load_legacy_drug_table.sql`
     - `load_legacy_indi_table.sql`
     - `load_legacy_outc_table.sql`
     - `load_legacy_reac_table.sql`
     - `load_legacy_rpsr_table.sql`
     - `load_legacy_ther_table.sql`

## Processing Steps for Deduplication and Mapping
1. Execute `derive_unique_all_case.sql` from `SCARs_ICI-Manuscript-Scripts/De-duplicate Cases`.
2. Execute `create_drug_usagi_mapping_table.sql` from `SCARs_ICI-Manuscript-Scripts/Drug Mapping`.
3. Execute `map_all_drugname_to_rxnorm.sql` from `SCARs_ICI-Manuscript-Scripts/Drug Mapping`.

## Map Current Data Drug Name to RxNorm – USAGI
**Scripts located in**: `SCARs_ICI-Manuscript-Scripts/Drug Mapping`

### Steps:
1. Execute `create_usagi_import_table.sql`.
2. Execute `generate_drug_export_for_usagi.sql`.
3. Export the set of unmapped codes to a file using pgAdmin client export functionality.
4. Open the exported file of the unmapped codes in Notepad++ and remove the last empty line to prevent any errors.
5. Download from the USAGI file from the Github (https://ohdsi.github.io/Usagi/)
6. Load the vocabulary data files that were previously downloaded from Athena into USAGI to create an index.
7. Load the file with unmapped codes into the USAGI tool for manual mapping by clicking File > Import Codes.
8. Enter `source_code` and `source_code_description` into the appropriate boxes.
9. Avoid entering anything in the frequency field to prevent formatting issues.
10. Manually map drug names to RxNorm `concept_ids` prioritized by descending frequency of occurrence.
11. Export the mapped codes from USAGI to a file.
12. Rename the columns in the exported file accordingly: `source_code`, `source_concept_id`, `source_vocabulary_id`, `source_code_description`, `target_concept_id`, `target_vocabulary_id`, `valid_start_date`, `valid_end_date`, `invalid_reason`.
13. Delete other unnecessary columns.
14. Load the USAGI mapped codes file into the `usagi_import` table using pgAdmin client import functionality.
    -  If the above fails, execute the Python script: `loading USAGI table to USAGI_import.py`.
15. Execute `load_drug_usagi_mapping.sql`.

## Standardization and Producing Files for Analysis
**Scripts located in**: `SCARs_ICI-Manuscript-Scripts/Drug Mapping`

### Steps:
1. Execute the following scripts:
   - `standardize_combined_drug_mapping.sql`
   - `derive_standard_case_outcome.sql`


# Instructions to Analyze FAERS Data

## System Requirements
- Operating System: Windows
- R Client: RStudio 2024.12.0 Build 467 (with R version 4.4.2)
- GitHub Repository: https://github.com/capuhcheeno/SCARs_ICI-Manuscript-Scripts

## Reference Data Preparation
**Scripts located in**: `SCARs_ICI-Manuscript-Scripts/Analyses of FAERS Data`

### Steps:
1. Execute XXXXXXXXXXXXXXXXXXXXXX


# Instructions to Analyze the FAERS Data with Random Survival Forests

## System Requirements
- Operating System: Windows
- Python Client: PyCharm 2024.2.0.1 (with Python version 3.12)
- GitHub Repository: https://github.com/capuhcheeno/SCARs_ICI-Manuscript-Scripts

## Parameter Search
**Scripts located in**: `SCARs_ICI-Manuscript-Scripts/Random Survival Forest Analysis`

### Steps:
1. Execute the following scripts:
   - `Individual SCARs Parameter Search.py`
   - `All SCARs Parameter Search.py`

## Kaplan Meier Survival Curves and VIMP Production
**Scripts located in**: `SCARs_ICI-Manuscript-Scripts/Random Survival Forest Analysis`

### Steps:
1. Execute `Kaplan Meier Curves and VIMPs.py`
2. Extract all p-values from the Python console and execute `Benjamin Hochberg.py`


---

**Acknowledgments:**
Some of the scripts used in this process were adapted from [FAERS DB Stats](https://github.com/ltscomputingllc/faersdbstats).
