from statsmodels.stats.multitest import multipletests

# List of p-values (Replace the XXX with p-values extracted from the Python console after running Kaplan Meier Curves and VIMPs.py)
p_values = [
    XXX, XXX, XXX, XXX,
    XXX, XXX, XXX, XXX,
    XXX, XXX, XXX, XXX,
    XXX, XXX, XXX, XXX,
]

# Perform the Benjamini-Hochberg correction
reject, pvals_corrected, _, _ = multipletests(p_values, alpha=0.05, method='fdr_bh')

# Print each original p-value with its corresponding corrected value and decision
print("Index | Original p-value | Corrected p-value | Reject Null?")
print("-" * 60)
for i, (orig, corrected, rej) in enumerate(zip(p_values, pvals_corrected, reject), start=1):
    print(f"{i:5d} | {orig:15.2e} | {corrected:18.2e} | {rej}")
