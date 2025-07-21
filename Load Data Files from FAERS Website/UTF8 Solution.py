# Example to read a file with a specific encoding and save it as UTF-8

input_file = r"D:\Current\all_version_B_drug_data_with_filename.txt"  # Your input file
output_file = r"D:\Current\all_version_B_drug_data_with_filename - copy.txt"  # Your output file

with open(input_file, "r", encoding="ISO-8859-1") as f:
    data = f.read()

with open(output_file, "w", encoding="UTF-8") as f:
    f.write(data)