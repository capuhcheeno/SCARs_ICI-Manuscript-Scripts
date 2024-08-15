import pandas as pd
from sqlalchemy import create_engine

# Replace these with your actual database connection details
db_username = '[USERNAME]'
db_password = '[PASSWORD]'
db_host = '[HOST]'
db_port = '5432'
db_name = '[DB NAME]'

# Create a connection to the database
engine = create_engine(f'postgresql+psycopg2://{db_username}:{db_password}@{db_host}:{db_port}/{db_name}')

# Load the CSV file
csv_file_path = r'[FILE PATH]'
df = pd.read_csv(csv_file_path)

# Select only the required columns
df = df[['source_code', 'source_concept_id', 'source_vocabulary_id', 'source_code_description', 'target_concept_id', 'target_vocabulary_id', 'valid_start_date','valid_end_date','invalid_reason',]]

# Insert the data into the SQL table in chunks
chunk_size = 1000
for start in range(0, len(df), chunk_size):
    end = start + chunk_size
    df_chunk = df[start:end]
    df_chunk.to_sql('usagi_import', con=engine, schema='faers', if_exists='append', index=False)
