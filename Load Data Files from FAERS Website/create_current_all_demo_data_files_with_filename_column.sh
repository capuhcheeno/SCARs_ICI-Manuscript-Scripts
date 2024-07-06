#!/bin/sh
##########################################################################
# create the combined demographic files with the filename appended as the last column
# and output into version A and version B files separately.
# NOTE the demographic file formats are in two versions
# We will call the file format before 2014 Q3 version A and everything from 2014 Q3 onwards, version B
#
# LTS Computing LLC
##########################################################################

# Base directory for files
base_dir="ascii"

# Initialize arrays for Version A and B file prefixes
version_a_prefixes=( "demo12q4" "DEMO13Q1" "DEMO13Q2" "DEMO13Q3" "DEMO13Q4" "DEMO14Q1" "DEMO14Q2" )
version_b_prefixes=( "DEMO14Q3" "DEMO14Q4" "DEMO15Q1" "DEMO15Q2" "DEMO15Q3" "DEMO15Q4" "DEMO16Q1" "DEMO16Q2" "DEMO16Q3" "DEMO16Q4" )

# Temporary files for version A and B
temp_file_a="${base_dir}/temp_a.txt"
temp_file_b="${base_dir}/temp_b.txt"

# Ensure temporary files are empty
> "$temp_file_a"
> "$temp_file_b"

process_file() {
    thefilename="${base_dir}/${1}.txt"
    version=$2  # New parameter to indicate file version
    # Determine version based on parameter
    if [ "$version" = "A" ]; then
        # Version A
        sed 's/\r$//' "${thefilename}" | sed '1 s/$/ filename/' | sed "2,\$ s|\$| ${thefilename}|" >> "$temp_file_a"
    else
        # Version B and beyond
        sed 's/\r$//' "${thefilename}" | sed '1d' | sed "1,\$ s|\$| ${thefilename}|" >> "$temp_file_b"
    fi
}

# Process Version A files
for prefix in "${version_a_prefixes[@]}"; do
    process_file "$prefix" "A"
done

# Process Version B files
for prefix in "${version_b_prefixes[@]}"; do
    process_file "$prefix" "B"
done

# Move temporary files to final version-specific files
mv "$temp_file_a" "${base_dir}/all_version_A_demo_data_with_filename"
mv "$temp_file_b" "${base_dir}/all_version_B_demo_data_with_filename"
