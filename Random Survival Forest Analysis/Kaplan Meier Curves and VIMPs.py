import re
import numpy as np
import pandas as pd
from sksurv.ensemble import RandomSurvivalForest
from sksurv.metrics import concordance_index_censored
from sklearn.utils import resample
import matplotlib.pyplot as plt
from lifelines import KaplanMeierFitter
from lifelines.statistics import multivariate_logrank_test

###############################################################################
# 1. Helper Functions
###############################################################################

def preprocess_data(data, include_scar_as_feature=True, preserve_categories=False, cat_cols_to_preserve=None):
    """
    Preprocess data:
      - Force the event indicator to 1 (locally).
      - Convert categorical columns to numeric codes.
      - Optionally preserve the original category names for specified columns.
      - Select predictors and build the structured array y = (event, time).

    Note: The age variable is "age_yr" (an integer), not an interval.
    """
    data = data.copy()
    data["status"] = 1  # local addition

    if cat_cols_to_preserve is None:
        cat_cols_to_preserve = ["sex", "region", "age_yr"]

    mapping = {}
    cat_cols = data.select_dtypes(include=["object", "category"]).columns
    for col in cat_cols:
        if preserve_categories and col in cat_cols_to_preserve:
            cat = data[col].astype("category")
            mapping[col] = dict(enumerate(cat.cat.categories))
            data[col] = cat.cat.codes
        else:
            data[col] = data[col].astype("category").cat.codes

    features = ["causative_drug", "sex", "region", "age_yr", "concomitant_count"]
    if include_scar_as_feature:
        for scar in ["SJSTEN", "DRESS", "AGEP", "GBFDE"]:
            if scar in data.columns:
                features.append(scar)
    X = data[features].copy()

    y = np.array(
        [(bool(s), t) for s, t in zip(data["status"], data["TTE"])],
        dtype=[("event", "bool"), ("time", "f8")]
    )
    if preserve_categories:
        return X, y, mapping
    else:
        return X, y

def train_rsf(data, params, include_scar_as_feature=True, preserve_categories=False):
    """
    Trains an RSF model on the given data using hyperparameters.
    """
    if preserve_categories:
        X, y, mapping = preprocess_data(data, include_scar_as_feature, preserve_categories=True)
    else:
        X, y = preprocess_data(data, include_scar_as_feature)
        mapping = None

    rsf = RandomSurvivalForest(
        n_estimators=params["ntree"],
        max_features=params["mtry"],
        min_samples_split=params["nodesize"],
        random_state=0,
        n_jobs=-1
    )
    rsf.fit(X, y)
    if preserve_categories:
        return rsf, X, y, mapping
    else:
        return rsf, X, y

def calculate_cindex(rsf, X, y):
    """
    Computes the concordance index (C-index) for the fitted RSF on (X, y).
    """
    cindex = concordance_index_censored(
        event_indicator=y["event"],
        event_time=y["time"],
        estimate=rsf.predict(X)
    )[0]
    return cindex

def permutation_importance_rsf(rsf, X, y, n_repeats=1, random_state=None):
    """
    Computes permutation-based importance for each feature in X.
    """
    rng = np.random.default_rng(random_state)
    baseline_cindex = calculate_cindex(rsf, X, y)
    importances = np.zeros(X.shape[1])
    for col_idx in range(X.shape[1]):
        col_name = X.columns[col_idx]
        original_data = X[col_name].values.copy()
        drops = []
        for _ in range(n_repeats):
            shuffled_indices = rng.permutation(len(X))
            X[col_name] = original_data[shuffled_indices]
            perm_cindex = calculate_cindex(rsf, X, y)
            drops.append(baseline_cindex - perm_cindex)
        X[col_name] = original_data
        importances[col_idx] = np.mean(drops)
    return importances

def compute_vimp(rsf, X, y, n_bootstrap=50, n_repeats=1, random_state=None):
    """
    Bootstraps the data repeatedly and computes permutation-based feature importance.
    Returns an array of shape (n_bootstrap, n_features).
    """
    rng = np.random.default_rng(random_state)
    base_params = rsf.get_params()
    vimp_list = []
    for b in range(n_bootstrap):
        X_res, y_res = resample(X, y, random_state=rng.integers(1e9))
        rsf_boot = RandomSurvivalForest(**base_params)
        rsf_boot.fit(X_res, y_res)
        perm_imp = permutation_importance_rsf(
            rsf_boot,
            X_res.copy(),
            y_res,
            n_repeats=n_repeats,
            random_state=rng.integers(1e9)
        )
        vimp_list.append(perm_imp)
    return np.array(vimp_list)

def plot_vimp(vimp_matrix, feature_names, ax=None):
    """
    Plots a boxplot of bootstrapped permutation-based VIMP values.
    """
    if ax is None:
        fig, ax = plt.subplots(figsize=(8, max(4, 0.5 * len(feature_names))))
    ax.boxplot(vimp_matrix, vert=False, labels=feature_names)
    ax.set_xlabel("Importance (C-index drop)")
    plt.tight_layout()
    plt.show()

###############################################################################
# 2. Combined RSF Curves (Figure 6A)
###############################################################################

def plot_combined_survival_curves(rsf, X, y, scar_columns):
    """
    For Figure 6A (combined RSF survival curves):
      - For each SCAR indicator, plots the RSF-predicted survival function on a common time grid.
      - Uses specified colors: SJSTEN in red, DRESS in cornflowerblue, AGEP in green, GBFDE in purple.
      - Adds a dotted horizontal line at y=0.5 and, for each curve, a vertical dotted line from
        the intersection (where survival equals 0.5) down to the x-axis.
    """
    plt.figure(figsize=(7, 5))
    max_time = y["time"].max()
    time_grid = np.linspace(0, max_time, 100)
    colors = {"SJSTEN": "red", "DRESS": "cornflowerblue", "AGEP": "green", "GBFDE": "purple"}
    for scar in scar_columns:
        if scar not in X.columns:
            continue
        idx = X[scar] == 1
        if np.sum(idx) == 0:
            continue
        surv_funcs = rsf.predict_survival_function(X[idx])
        surv_vals = np.array([fn(time_grid) for fn in surv_funcs])
        mean_surv = surv_vals.mean(axis=0)
        median_time = np.interp(0.5, mean_surv[::-1], time_grid[::-1])
        q75_time = np.interp(0.75, mean_surv[::-1], time_grid[::-1])
        q25_time = np.interp(0.25, mean_surv[::-1], time_grid[::-1])
        print(f"{scar}: 0.75 quantile = {q75_time:.2f} days, median = {median_time:.2f} days, 0.25 quantile = {q25_time:.2f} days")
        plt.plot(time_grid, mean_surv, label=scar, color=colors.get(scar, None))
        x_int = np.interp(0.5, mean_surv[::-1], time_grid[::-1])
        plt.vlines(x_int, 0, 0.5, colors=colors.get(scar, None), linestyles="dotted")
    plt.axhline(0.5, linestyle="dotted", color="black")
    plt.xlabel("Time (Days)")
    plt.ylabel("Predicted Survival Probability")
    plt.legend(loc="upper right")
    plt.tight_layout()
    plt.show()

###############################################################################
# 3. Kaplan–Meier Functions for Individual Graphs
###############################################################################

def plot_km_survival_by_age_yr(data, time_col="TTE", event_col="status", age_col="age_yr", min_group_size=5, bins=None):
    """
    Plots a Kaplan–Meier survival curve for age (binned in 20-year intervals).
    Draws a horizontal dotted line at 0.5 and a vertical dotted line from the intersection.
    Prints the log–rank p-value to the console (using scientific notation if low).
    """
    kmf = KaplanMeierFitter()
    plt.figure(figsize=(10, 6))
    if bins is None:
        max_age = int(data[age_col].max()) + 1
        bins = list(range(0, ((max_age // 20) + 2) * 20, 20))
    labels = [f"{bins[i]}-{bins[i+1]}" for i in range(len(bins)-1)]
    data["age_bin"] = pd.cut(data[age_col], bins=bins, right=False, labels=labels)
    age_bin_counts = data["age_bin"].value_counts()
    valid_bins = age_bin_counts[age_bin_counts >= min_group_size].index
    for age_bin in sorted(valid_bins, key=lambda x: int(x.split("-")[0])):
        mask = data["age_bin"] == age_bin
        kmf.fit(data.loc[mask, time_col], data.loc[mask, event_col], label=f"Age {age_bin}")
        kmf.plot(ci_show=False)
        line = plt.gca().get_lines()[-1]
        col = line.get_color()
        surv_func = kmf.survival_function_.iloc[:, 0]
        x_int = np.interp(0.5, surv_func[::-1], surv_func.index[::-1])
        plt.vlines(x_int, 0, 0.5, colors=col, linestyles="dotted")
    plt.axhline(0.5, linestyle="dotted", color="black")
    plt.xlabel("Time (Days)")
    plt.ylabel("Survival Probability")
    plt.legend(loc="upper right")
    valid_data = data[data["age_bin"].notnull()]
    results = multivariate_logrank_test(valid_data[time_col], valid_data["age_bin"], valid_data[event_col])
    p = results.p_value
    if p < 1e-3:
        print(f"Log–Rank p-value for age bins: {p:.2e}")
    else:
        print(f"Log–Rank p-value for age bins: {p:.4f}")
    plt.tight_layout()
    plt.show()

def plot_km_survival_by_region(data, time_col="TTE", event_col="status", region_col="region", min_group_size=5):
    """
    Plots a Kaplan–Meier survival curve for each region.
    Draws a horizontal dotted line at 0.5 and vertical dotted lines at intersections.
    Prints the log–rank p-value to the console (using scientific notation if low).
    """
    kmf = KaplanMeierFitter()
    plt.figure(figsize=(10, 6))
    region_counts = data[region_col].value_counts()
    valid_regions = region_counts[region_counts >= min_group_size].index
    for region in valid_regions:
        mask = data[region_col] == region
        kmf.fit(data.loc[mask, time_col], data.loc[mask, event_col], label=f"Region {region}")
        kmf.plot(ci_show=False)
        line = plt.gca().get_lines()[-1]
        col = line.get_color()
        surv_func = kmf.survival_function_.iloc[:, 0]
        x_int = np.interp(0.5, surv_func[::-1], surv_func.index[::-1])
        plt.vlines(x_int, 0, 0.5, colors=col, linestyles="dotted")
    plt.axhline(0.5, linestyle="dotted", color="black")
    plt.xlabel("Time (Days)")
    plt.ylabel("Survival Probability")
    plt.legend(loc="upper right")
    valid_data = data[data[region_col].isin(valid_regions)]
    results = multivariate_logrank_test(valid_data[time_col], valid_data[region_col], valid_data[event_col])
    p = results.p_value
    if p < 1e-3:
        print(f"Log–Rank p-value for regions: {p:.2e}")
    else:
        print(f"Log–Rank p-value for regions: {p:.4f}")
    plt.tight_layout()
    plt.show()

def plot_km_survival_by_sex(data, time_col="TTE", event_col="status", sex_col="sex", min_group_size=5):
    """
    Plots a Kaplan–Meier survival curve for each sex group.
    Draws a horizontal dotted line at 0.5 and vertical dotted lines at intersections.
    Prints the log–rank p-value to the console (using scientific notation if low).
    """
    kmf = KaplanMeierFitter()
    plt.figure(figsize=(10, 6))
    sex_counts = data[sex_col].value_counts()
    valid_sexes = sex_counts[sex_counts >= min_group_size].index
    for sex in valid_sexes:
        mask = data[sex_col] == sex
        kmf.fit(data.loc[mask, time_col], data.loc[mask, event_col], label=f"Sex {sex}")
        kmf.plot(ci_show=False)
        line = plt.gca().get_lines()[-1]
        col = line.get_color()
        surv_func = kmf.survival_function_.iloc[:, 0]
        x_int = np.interp(0.5, surv_func[::-1], surv_func.index[::-1])
        plt.vlines(x_int, 0, 0.5, colors=col, linestyles="dotted")
    plt.axhline(0.5, linestyle="dotted", color="black")
    plt.xlabel("Time (Days)")
    plt.ylabel("Survival Probability")
    plt.legend(loc="upper right")
    valid_data = data[data[sex_col].isin(valid_sexes)]
    results = multivariate_logrank_test(valid_data[time_col], valid_data[sex_col], valid_data[event_col])
    p = results.p_value
    if p < 1e-3:
        print(f"Log–Rank p-value for sexes: {p:.2e}")
    else:
        print(f"Log–Rank p-value for sexes: {p:.4f}")
    plt.tight_layout()
    plt.show()

def plot_km_survival_by_concomitant(data, time_col="TTE", event_col="status", count_col="concomitant_count", min_group_size=5):
    """
    Groups subjects by concomitant drug count into three groups:
      "0-5", "6-10", and ">10", and then plots Kaplan–Meier survival curves
      for each group. Draws a horizontal dotted line at 0.5 and vertical dotted lines at intersections.
    Prints the log–rank p-value to the console (using scientific notation if low).
    """
    kmf = KaplanMeierFitter()
    plt.figure(figsize=(10, 6))
    bins = [0, 6, 11, np.inf]
    labels = ["0-5", "6-10", ">10"]
    data["concomitant_group"] = pd.cut(data[count_col], bins=bins, right=False, labels=labels)
    group_counts = data["concomitant_group"].value_counts()
    valid_groups = group_counts[group_counts >= min_group_size].index
    for grp in valid_groups:
        mask = data["concomitant_group"] == grp
        kmf.fit(data.loc[mask, time_col], data.loc[mask, event_col], label=f"Concomitant {grp}")
        kmf.plot(ci_show=False)
        line = plt.gca().get_lines()[-1]
        col = line.get_color()
        surv_func = kmf.survival_function_.iloc[:, 0]
        x_int = np.interp(0.5, surv_func[::-1], surv_func.index[::-1])
        plt.vlines(x_int, 0, 0.5, colors=col, linestyles="dotted")
    plt.axhline(0.5, linestyle="dotted", color="black")
    plt.xlabel("Time (Days)")
    plt.ylabel("Survival Probability")
    plt.legend(loc="upper right")
    valid_data = data[data["concomitant_group"].notnull()]
    results = multivariate_logrank_test(valid_data[time_col], valid_data["concomitant_group"], valid_data[event_col])
    p = results.p_value
    if p < 1e-3:
        print(f"Log–Rank p-value for concomitant groups: {p:.2e}")
    else:
        print(f"Log–Rank p-value for concomitant groups: {p:.4f}")
    plt.tight_layout()
    plt.show()

###############################################################################
# 4. Main Analysis and Figure Generation
###############################################################################

if __name__ == "__main__":
    # === 1) Load the data ===
    combined_file = r"C:\clean_data_scar.csv"
    combined_data = pd.read_csv(combined_file)
    combined_data["status"] = 1  # Ensure 'status' is present

    # === 2) Combined RSF for all SCAR (Figure 6A) ===
    best_params_combined = {"ntree": 3000, "mtry": 5, "nodesize": 3}
    rsf_combined, X_combined, y_combined = train_rsf(
        combined_data, best_params_combined,
        include_scar_as_feature=True,
        preserve_categories=False
    )
    cindex_combined = calculate_cindex(rsf_combined, X_combined, y_combined)
    print(f"Combined RSF C-index: {cindex_combined:.4f}")

    # Figure 6A: RSF-Predicted Survival Curves for each SCAR indicator (including GBFDE in purple)
    scar_columns = ["SJSTEN", "DRESS", "AGEP", "GBFDE"]
    plot_combined_survival_curves(rsf_combined, X_combined, y_combined, scar_columns)

    # VIMP plot (combined) -- For 6B, we now plot VIMP for all features individually (no SCAR aggregation)
    feature_names = list(X_combined.columns)
    plot_vimp(compute_vimp(rsf_combined, X_combined, y_combined, n_bootstrap=30, n_repeats=1, random_state=42),
              feature_names)

    # For consistent age binning, compute bins from combined data.
    max_age_combined = int(combined_data["age_yr"].max()) + 1
    bins_combined = list(range(0, ((max_age_combined // 20) + 2) * 20, 20))

    # Kaplan–Meier Analysis for the Combined Data (individual graphs)
    print("\nKaplan–Meier Survival Analysis by Age for the Combined Data:")
    plot_km_survival_by_age_yr(combined_data, time_col="TTE", event_col="status", age_col="age_yr", bins=bins_combined)

    print("\nKaplan–Meier Survival Analysis by Region for the Combined Data:")
    plot_km_survival_by_region(combined_data, time_col="TTE", event_col="status", region_col="region")

    print("\nKaplan–Meier Survival Analysis by Sex for the Combined Data:")
    plot_km_survival_by_sex(combined_data, time_col="TTE", event_col="status", sex_col="sex")

    print("\nKaplan–Meier Survival Analysis by Concomitant Drugs for the Combined Data:")
    plot_km_survival_by_concomitant(combined_data, time_col="TTE", event_col="status", count_col="concomitant_count", min_group_size=5)

    # === 3) Individual SCAR Analyses (produce individual KM graphs) ===
    # Skip individual analysis for GBFDE as per instruction.
    individual_scar_columns = ["SJSTEN", "DRESS", "AGEP"]

    best_params_individual = {
        "SJSTEN": {"ntree": 3000, "mtry": 5, "nodesize": 3},
        "DRESS": {"ntree": 3000, "mtry": 5, "nodesize": 3},
        "AGEP": {"ntree": 2000, "mtry": 5, "nodesize": 3},
    }

    for scar in individual_scar_columns:
        print(f"\nProcessing individual SCAR analysis for {scar} cases...")
        scar_data = combined_data[combined_data[scar] == True].copy()
        scar_data["status"] = 1
        if scar_data.shape[0] == 0:
            print(f"No data for {scar}, skipping.")
            continue

        # RSF analysis for the SCAR subgroup
        rsf_ind, X_ind, y_ind, mapping = train_rsf(
            scar_data, best_params_individual[scar],
            include_scar_as_feature=False, preserve_categories=True
        )
        cindex_ind = calculate_cindex(rsf_ind, X_ind, y_ind)
        print(f"{scar} RSF C-index: {cindex_ind:.4f}")

        # Compute and plot VIMP for the SCAR subgroup
        vimp_ind = compute_vimp(rsf_ind, X_ind, y_ind, n_bootstrap=50, n_repeats=1, random_state=42)
        plot_vimp(vimp_ind, list(X_ind.columns))

        print(f"\nKaplan–Meier Survival Analysis by Age for {scar} cases:")
        plot_km_survival_by_age_yr(scar_data, time_col="TTE", event_col="status", age_col="age_yr", bins=bins_combined)

        print(f"\nKaplan–Meier Survival Analysis by Region for {scar} cases:")
        plot_km_survival_by_region(scar_data, time_col="TTE", event_col="status", region_col="region")

        print(f"\nKaplan–Meier Survival Analysis by Sex for {scar} cases:")
        plot_km_survival_by_sex(scar_data, time_col="TTE", event_col="status", sex_col="sex")

        print(f"\nKaplan–Meier Survival Analysis by Concomitant Drugs for {scar} cases:")
        plot_km_survival_by_concomitant(scar_data, time_col="TTE", event_col="status", count_col="concomitant_count", min_group_size=5)
