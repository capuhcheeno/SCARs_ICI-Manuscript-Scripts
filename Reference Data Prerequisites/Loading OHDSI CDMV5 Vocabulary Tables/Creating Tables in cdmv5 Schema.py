import psycopg2

# Connection parameters
conn_params = {
    'dbname': 'your_database_name',
    'user': 'your_username',
    'password': 'your_password',
    'host': 'your_host',
    'port': 'your_port'
}

# SQL statements to create tables
create_table_statements = [
    """
    CREATE TABLE cdmv5.concept (
        concept_id TEXT,
        concept_name TEXT,
        domain_id TEXT,
        vocabulary_id TEXT,
        concept_class_id TEXT,
        standard_concept TEXT,
        concept_code TEXT,
        valid_start_date TIMESTAMP WITHOUT TIME ZONE,
        valid_end_date TIMESTAMP WITHOUT TIME ZONE,
        invalid_reason TEXT
    )
    """,
    """
    CREATE TABLE cdmv5.vocabulary (
        vocabulary_id TEXT,
        vocabulary_name TEXT,
        vocabulary_reference TEXT,
        vocabulary_version TEXT,
        vocabulary_concept_id TEXT
    )
    """,
    """
    CREATE TABLE cdmv5.concept_ancestor (
        ancestor_concept_id TEXT,
        descendant_concept_id TEXT,
        min_levels_of_separation TEXT,
        max_levels_of_separation TEXT
    )
    """,
    """
    CREATE TABLE cdmv5.concept_relationship (
        concept_id_1 TEXT,
        concept_id_2 TEXT,
        relationship_id TEXT,
        valid_start_date TIMESTAMP WITHOUT TIME ZONE,
        valid_end_date TIMESTAMP WITHOUT TIME ZONE,
        invalid_reason TEXT
    )
    """,
    """
    CREATE TABLE cdmv5.relationship (
        relationship_id TEXT,
        relationship_name TEXT,
        is_hierarchical TEXT,
        defines_ancestry TEXT,
        reverse_relationship_id TEXT,
        relationship_concept_id TEXT
    )
    """,
    """
    CREATE TABLE cdmv5.concept_synonym (
        concept_id TEXT,
        concept_synonym_name TEXT,
        language_concept_id TEXT
    )
    """,
    """
    CREATE TABLE cdmv5.domain (
        domain_id TEXT,
        domain_name TEXT,
        domain_concept_id TEXT
    )
    """,
    """
    CREATE TABLE cdmv5.concept_class (
        concept_class_id TEXT,
        concept_class_name TEXT,
        concept_class_concept_id TEXT
    )
    """,
    """
    CREATE TABLE cdmv5.drug_strength (
        drug_concept_id TEXT,
        ingredient_concept_id TEXT,
        amount_value TEXT,
        amount_unit_concept_id TEXT,
        numerator_value TEXT,
        numerator_unit_concept_id TEXT,
        denominator_value TEXT,
        denominator_unit_concept_id TEXT,
        box_size TEXT,
        valid_start_date TIMESTAMP WITHOUT TIME ZONE,
        valid_end_date TIMESTAMP WITHOUT TIME ZONE,
        invalid_reason TEXT
    )
    """
]

def create_tables():
    try:
        # Connect to the PostgreSQL server
        conn = psycopg2.connect(**conn_params)
        cur = conn.cursor()

        # Execute each create table statement
        for statement in create_table_statements:
            cur.execute(statement)

        # Commit the changes
        conn.commit()

        # Close the communication with the PostgreSQL database server
        cur.close()
        conn.close()
        print("Tables created successfully")

    except (Exception, psycopg2.DatabaseError) as error:
        print(error)

if __name__ == "__main__":
    create_tables()
