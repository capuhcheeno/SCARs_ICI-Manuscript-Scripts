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
        concept_id CHAR,
        concept_name CHAR,
        domain_id CHAR,
        vocabulary_id CHAR,
        concept_class_id CHAR,
        standard_concept CHAR,
        concept_code CHAR,
        valid_start_date TIMESTAMP WITHOUT TIME ZONE,
        valid_end_date TIMESTAMP WITHOUT TIME ZONE,
        invalid_reason CHAR
    )
    """,
    """
    CREATE TABLE cdmv5.vocabulary (
        vocabulary_id CHAR,
        vocabulary_name CHAR,
        vocabulary_reference CHAR,
        vocabulary_version CHAR,
        vocabulary_concept_id CHAR
    )
    """,
    """
    CREATE TABLE cdmv5.concept_ancestor (
        ancestor_concept_id CHAR,
        descendant_concept_id CHAR,
        min_levels_of_separation CHAR,
        max_levels_of_separation CHAR
    )
    """,
    """
    CREATE TABLE cdmv5.concept_relationship (
        concept_id_1 CHAR,
        concept_id_2 CHAR,
        relationship_id CHAR,
        valid_start_date TIMESTAMP WITHOUT TIME ZONE,
        valid_end_date TIMESTAMP WITHOUT TIME ZONE,
        invalid_reason CHAR
    )
    """,
    """
    CREATE TABLE cdmv5.relationship (
        relationship_id CHAR,
        relationship_name CHAR,
        is_hierarchical CHAR,
        defines_ancestry CHAR,
        reverse_relationship_id CHAR,
        relationship_concept_id CHAR
    )
    """,
    """
    CREATE TABLE cdmv5.concept_synonym (
        concept_id CHAR,
        concept_synonym_name CHAR,
        language_concept_id CHAR
    )
    """,
    """
    CREATE TABLE cdmv5.domain (
        domain_id CHAR,
        domain_name CHAR,
        domain_concept_id CHAR
    )
    """,
    """
    CREATE TABLE cdmv5.concept_class (
        concept_class_id CHAR,
        concept_class_name CHAR,
        concept_class_concept_id CHAR
    )
    """,
    """
    CREATE TABLE cdmv5.drug_strength (
        drug_concept_id CHAR,
        ingredient_concept_id CHAR,
        amount_value VARCHAR,
        amount_unit_concept_id VARCHAR,
        numerator_value VARCHAR,
        numerator_unit_concept_id VARCHAR,
        denominator_value VARCHAR,
        denominator_unit_concept_id VARCHAR,
        box_size VARCHAR,
        valid_start_date TIMESTAMP WITHOUT TIME ZONE,
        valid_end_date TIMESTAMP WITHOUT TIME ZONE,
        invalid_reason CHAR
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