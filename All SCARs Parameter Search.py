import pandas as pd
import numpy as np
import itertools
from sksurv.ensemble import RandomSurvivalForest
from sksurv.metrics import concordance_index_censored

# -------------------------------------------------------------------------------
# Load and Preprocess the Combined SCAR Data
# -------------------------------------------------------------------------------

# Load the combined SCAR data
clean_data_scar = pd.read_csv(r"C:\clean_data_SCAR.csv")

# Convert relevant columns to categorical variables
categorical_columns = ["sex", "causative_drug", "age_group", "region"]
for col in categorical_columns:
    clean_data_scar[col] = clean_data_scar[col].astype("category")

# -------------------------------------------------------------------------------
# Define the RSF Hyperparameter Tuning Function
# -------------------------------------------------------------------------------

def run_rsf_fast_grid(
        data,
        ntree_range=[500, 1000, 2000, 3000],
        mtry_range=[3, 5],
        min_node_size_range=[3, 5, 10, 20, 30],
        nsplit_range=[5, 10, 15]
):
    # For consistency with your R-code, force all events to be observed
    data["status"] = 1

    # Prepare the feature matrix (X) and the survival outcome (y)
    # Here we use the same features: causative_drug, sex, region, age_group, concomitant_count
    X = data[["causative_drug", "sex", "region", "age_group", "concomitant_count"]].copy()

    # Convert all categorical variables to numeric codes
    for col in X.select_dtypes(["category"]).columns:
        X[col] = X[col].cat.codes

    # Build the structured array for survival
    # Each record contains (event_indicator, event_time)
    y = np.array([(bool(s), t) for s, t in zip(data["status"], data["TTE"])],
                 dtype=[("event", "bool"), ("time", "f8")])

    # Create a grid of parameter combinations
    param_grid = list(itertools.product(ntree_range, mtry_range, min_node_size_range, nsplit_range))
    results_list = []

    print("Grid search using fast RSF option on combined SCAR data")
    for i, (ntree, mtry, nodesize, nsplit) in enumerate(param_grid, start=1):
        print(f"Testing combination number {i}: ntree={ntree}, mtry={mtry}, nodesize={nodesize}, nsplit={nsplit}")

        # Set up the Random Survival Forest model with the given parameters.
        # Note: 'nsplit' does not directly correspond to any parameter in scikit-survival.
        rsf_model = RandomSurvivalForest(
            n_estimators=ntree,
            max_features=mtry,       # corresponds to mtry in R
            min_samples_split=nodesize,  # using nodesize as min_samples_split for demonstration
            random_state=0,
            n_jobs=1  # adjust as necessary for parallel processing
        )

        # Fit the model on the data
        rsf_model.fit(X, y)

        # Evaluate model performance using the concordance index
        cindex, _, _, _, _ = concordance_index_censored(
            event_indicator=y["event"],
            event_time=y["time"],
            estimate=rsf_model.predict(X)
        )

        error_rate = 1.0 - cindex
        print(f"Error rate (1 - concordance): {error_rate}")

        # Save the results for this parameter combination
        results_list.append({
            "ntree": ntree,
            "mtry": mtry,
            "nodesize": nodesize,
            "nsplit": nsplit,
            "error_rate": error_rate
        })

    # Convert the list of results to a DataFrame for easier viewing
    results = pd.DataFrame(results_list)
    return results

# -------------------------------------------------------------------------------
# Run the RSF Grid Search on the Combined SCAR Data
# -------------------------------------------------------------------------------

print("Running RSF hyperparameter grid search on combined SCAR data")
rsf_scar_hyperparam = run_rsf_fast_grid(clean_data_scar)

print("\nFinished combined SCAR grid search results:")
print(rsf_scar_hyperparam)
