import pandas as pd
import numpy as np
from sksurv.ensemble import RandomSurvivalForest
from sksurv.metrics import concordance_index_censored
import itertools

clean_data_SJSTEN = pd.read_csv(r"C:\Users\parkd\Downloads\clean_data_SJSTEN.csv")
clean_data_DRESS = pd.read_csv(r"C:\Users\parkd\Downloads\clean_data_DRESS.csv")
clean_data_AGEP = pd.read_csv(r"C:\Users\parkd\Downloads\clean_data_AGEP.csv")

# Convert SJS-TEN to factors
clean_data_SJSTEN["sex"] = clean_data_SJSTEN["sex"].astype("category")
clean_data_SJSTEN["causative_drug"] = clean_data_SJSTEN["causative_drug"].astype("category")
clean_data_SJSTEN["age_group"] = clean_data_SJSTEN["age_group"].astype("category")
clean_data_SJSTEN["region"] = clean_data_SJSTEN["region"].astype("category")

# Convert DRESS to factors
clean_data_DRESS["sex"] = clean_data_DRESS["sex"].astype("category")
clean_data_DRESS["causative_drug"] = clean_data_DRESS["causative_drug"].astype("category")
clean_data_DRESS["age_group"] = clean_data_DRESS["age_group"].astype("category")
clean_data_DRESS["region"] = clean_data_DRESS["region"].astype("category")

# Convert AGEP to factors
clean_data_AGEP["sex"] = clean_data_AGEP["sex"].astype("category")
clean_data_AGEP["causative_drug"] = clean_data_AGEP["causative_drug"].astype("category")
clean_data_AGEP["age_group"] = clean_data_AGEP["age_group"].astype("category")
clean_data_AGEP["region"] = clean_data_AGEP["region"].astype("category")


# ------------------------------------------------------------------------------
# RSF ANALYSIS
# Define a function for hyperparameter tuning
# ------------------------------------------------------------------------------

def run_rsf_fast_grid(
        data,
        ntree_range=[500, 1000, 2000, 3000],
        mtry_range=[3, 5],
        min_node_size_range=[3, 5, 10, 20, 30],
        nsplit_range=[5, 10, 15]
):

    # Force all events to be observed (status = 1), as in the R code
    data["status"] = 1

    # Prepare the X (features) and y (structured array for survival)
    # The R formula was: Surv(TTE, status) ~ causative_drug + sex + region + age_group + concomitant_count
    # We'll replicate that in Python with scikit-survival
    X = data[["causative_drug", "sex", "region", "age_group", "concomitant_count"]].copy()

    # Convert all categorical variables to numeric codes for the model
    for col in X.select_dtypes(["category"]).columns:
        X[col] = X[col].cat.codes

    # Build the structured array for survival
    # Each row is (event_indicator, event_time)
    y = np.array([(bool(s), t) for s, t in zip(data["status"], data["TTE"])],
                 dtype=[("event", "bool"), ("time", "f8")])

    # Construct a list of parameter combinations as in expand.grid(...)
    param_grid = list(itertools.product(ntree_range, mtry_range, min_node_size_range, nsplit_range))

    # Initialize a storage list for results
    results_list = []

    print("Grid search using fast RSF option")
    for i, (ntree, mtry, nodesize, nsplit) in enumerate(param_grid, start=1):
        print(f"Testing combination number {i}: ntree={ntree}, mtry={mtry}, nodesize={nodesize}, nsplit={nsplit}")

        # In randomForestSRC (R), "rfsrc.fast" uses some internal optimizations.
        # Here, we simply fit a RandomSurvivalForest in Python with provided parameters.
        # Note: scikit-survival does not have a direct parameter for 'nsplit'.
        rsf_model = RandomSurvivalForest(
            n_estimators=ntree,
            # In R, "mtry" is the number of variables randomly selected at each split.
            # In scikit-survival, this is "max_features".
            max_features=mtry,

            # In R, "nodesize" is the minimum size of terminal nodes.
            # In scikit-survival, we often control splitting with min_samples_split or min_samples_leaf.
            # We'll treat 'nodesize' as min_samples_split for demonstration, though it's not exactly the same.
            min_samples_split=nodesize,

            # We turn on "importance" in R. In Python, we can request variable importance if needed,
            # but let's focus on matching the structure of the training. There's a `random_state` you can set if reproducibility is needed.
            random_state=0,
            n_jobs=1  # Modify as needed for parallelism
        )

        # Fit the model
        rsf_model.fit(X, y)

        # Evaluate performance using 1 - C-index (error rate).
        # In newer versions of scikit-survival, concordance_index_censored returns five values:
        # (cindex, concordant, comparable, tied_risk, tied_time)
        cindex, _, _, _, _ = concordance_index_censored(
            event_indicator=y["event"],
            event_time=y["time"],
            estimate=rsf_model.predict(X)
        )

        error_rate = 1.0 - cindex
        print(f"Error rate (1 - concordance): {error_rate}")

        # Store results
        results_list.append({
            "ntree": ntree,
            "mtry": mtry,
            "nodesize": nodesize,
            "nsplit": nsplit,
            "error_rate": error_rate
        })

    # Return results as a DataFrame
    results = pd.DataFrame(results_list)
    return results

# ------------------------------------------------------------------------------
# Analyze Each Dataset
# ------------------------------------------------------------------------------

print("Running RSF for SJS-TEN")
rsf_SJSTEN_hyperparam = run_rsf_fast_grid(clean_data_SJSTEN)
print("\nFinished SJS-TEN grid search results:")
print(rsf_SJSTEN_hyperparam)

print("\nRunning RSF for DRESS")
rsf_DRESS_hyperparam = run_rsf_fast_grid(clean_data_DRESS)
print("\nFinished DRESS grid search results:")
print(rsf_DRESS_hyperparam)

print("\nRunning RSF for AGEP")
rsf_AGEP_hyperparam = run_rsf_fast_grid(clean_data_AGEP)
print("\nFinished AGEP grid search results:")
print(rsf_AGEP_hyperparam)