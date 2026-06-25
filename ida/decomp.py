"""Generic additive LMDI decomposition shared by all sectors.

The industry (GVA / sector) and transport (VKM / mode) decompositions are
structurally identical; they differ only in:
  * `activity`  : the activity column name ("GVA" or "VKM")
  * `group`     : the disaggregation column ("sector" or "mode")
  * `endpoints_only` : industry drops a group if *any* in-range year is missing;
                       transport drops only if the first/last year is missing.
  * `guarded`   : industry guards the indexing (0 -> 0, NaN -> NaN); transport
                  divides straight through.

This module factors that common core out of the two sector modules. Behaviour is
locked by the R-parity tests in tests/.
"""
from __future__ import annotations

import numpy as np
import pandas as pd


def aggregate_groups(df, groups, rename, id_cols):
    """Replicate the R `rowSums(select(., all_of(group)))` + rename + drop.

    `df` is wide (one column per source code). Group columns are summed
    (NaN treated as 0), originals dropped, then survivors renamed.
    """
    out = df.copy()
    consumed = []
    for agg_name, codes in groups.items():
        present = [c for c in codes if c in out.columns]
        if present:
            out[agg_name] = out[present].sum(axis=1, min_count=0)
        else:
            out[agg_name] = 0.0
        consumed.extend(present)
    out = out.drop(columns=[c for c in consumed if c not in id_cols])
    return out.rename(columns=rename)


def _intensity(activity_vals, energy_vals):
    """energy / activity, with the R case_when guards for zero activity."""
    A, E = activity_vals, energy_vals
    return np.where((A == 0) & (E > 0), np.nan,
                    np.where((A == 0) & (E == 0), 0.0, E / A))


def join_energy_activity(df, activity):
    if df.empty:
        return df
    df = df.copy()
    a0 = df[activity] == 0
    e0 = df["energy_consumption"] == 0
    df.loc[a0 & (df["energy_consumption"] > 0), activity] = np.nan
    df.loc[e0 & (df[activity] > 0), "energy_consumption"] = np.nan
    df["intensity"] = _intensity(df[activity], df["energy_consumption"])
    g = df.groupby(["geo", "time"])
    df["total_energy_consumption"] = g["energy_consumption"].transform(lambda s: s.sum(min_count=0))
    df[f"total_{activity}"] = g[activity].transform(lambda s: s.sum(min_count=0))
    df["share_energy_consumption"] = df["energy_consumption"] / df["total_energy_consumption"]
    df[f"share_{activity}"] = df[activity] / df[f"total_{activity}"]
    return df


def filter_decomposition(df, first_year, last_year, activity, group, endpoints_only):
    """Drop (geo, group) pairs with missing activity/energy in the window."""
    if df.empty:
        return {"df": df, "notifications": ["No data available for LMDI calculation."]}
    notifications = []
    drop_keys = set()
    in_range = (df["time"] >= first_year) & (df["time"] <= last_year)
    endpoints = {first_year, last_year}
    label = activity
    group_label = group.capitalize()

    for (geo, grp), sub in df[in_range].groupby(["geo", group]):
        act_bad = sub[activity].isna() | (sub[activity] == 0)
        if endpoints_only:
            act_bad = act_bad & sub["time"].isin(endpoints)
        if act_bad.any():
            yrs = ", ".join(str(int(y)) for y in sub.loc[
                sub[activity].isna() | (sub[activity] == 0), "time"])
            notifications.append(
                f"Country: {geo} , {group_label}: {grp} - removed "
                f"(missing {label} in years: {yrs} )")
            drop_keys.add((geo, grp))
            continue
        en_bad = ((sub["energy_consumption"].isna() | (sub["energy_consumption"] == 0))
                  & sub[activity].notna() & (sub[activity] != 0))
        if endpoints_only:
            en_bad = en_bad & sub["time"].isin(endpoints)
        if en_bad.any():
            yrs = ", ".join(str(int(y)) for y in sub.loc[
                sub["energy_consumption"].isna() | (sub["energy_consumption"] == 0), "time"])
            notifications.append(
                f"Country: {geo} , {group_label}: {grp} - removed "
                f"(missing energy consumption in years: {yrs} )")
            drop_keys.add((geo, grp))

    if drop_keys:
        mask = ~df.set_index(["geo", group]).index.isin(drop_keys)
        df = df[mask]
    return {"df": df.reset_index(drop=True), "notifications": notifications}


def add_share(df, activity):
    if df.empty:
        return df
    df = df.copy()
    g = df.groupby(["geo", "time"])
    df["total_energy_consumption"] = g["energy_consumption"].transform(lambda s: s.sum(min_count=0))
    df[f"total_{activity}"] = g[activity].transform(lambda s: s.sum(min_count=0))
    df["share_energy_consumption"] = df["energy_consumption"] / df["total_energy_consumption"]
    df[f"share_{activity}"] = df[activity] / df[f"total_{activity}"]
    return df.drop(columns=["total_energy_consumption", f"total_{activity}", "intensity"])


def add_total(df, activity, group):
    if df.empty:
        return df
    agg = df.groupby(["geo", "time"], as_index=False).agg(**{
        activity: (activity, lambda s: s.sum(min_count=0)),
        "energy_consumption": ("energy_consumption", lambda s: s.sum(min_count=0)),
        f"share_{activity}": (f"share_{activity}", lambda s: s.sum(min_count=0)),
        "share_energy_consumption": ("share_energy_consumption", lambda s: s.sum(min_count=0)),
    })
    agg[group] = "Total"
    return agg


def add_index_delta(df, first_year, activity, group, guarded):
    if df.empty:
        return df
    df = df.copy()
    df["intensity"] = _intensity(df[activity], df["energy_consumption"])
    long = df.melt(id_vars=["geo", "time", group], var_name="measure", value_name="value")
    base = (long[long["time"] == first_year]
            .set_index(["geo", group, "measure"])["value"])
    keys = list(zip(long["geo"], long[group], long["measure"]))
    b = base.reindex(keys).to_numpy()
    v = long["value"].to_numpy()
    if guarded:
        long["value_indexed"] = np.where(np.isnan(b), np.nan,
                                         np.where(b == 0, 0.0, v / b))
    else:
        long["value_indexed"] = v / b
    long["value_delta"] = v - b
    long["time"] = long["time"].astype(int)
    return long.reset_index(drop=True)


def apply_lmdi(df, first_year, activity, group):
    if df.empty:
        return df
    wide = df.pivot_table(
        index=["geo", "time", group], columns="measure",
        values=["value", "value_indexed", "value_delta"], aggfunc="first")
    wide.columns = [f"{a}_{b}" for a, b in wide.columns]
    wide = wide.reset_index()

    # log(1)=0 and log(0)=-inf arise naturally and mirror the R behaviour;
    # the guards below select them out, so silence the expected warnings.
    def _log(s):
        with np.errstate(divide="ignore", invalid="ignore"):
            return np.log(s)

    def _safe_log(col):
        return np.where(wide[col] == 0, 0.0, _log(wide[col]))

    delta_en = wide["value_delta_energy_consumption"]
    idx_en = wide["value_indexed_energy_consumption"]
    wide["weighting_factor"] = np.where(
        delta_en == 0, wide["value_energy_consumption"], delta_en / _log(idx_en))
    wide["activity_log"] = _safe_log(f"value_indexed_{activity}")
    wide["structure_log"] = _safe_log(f"value_indexed_share_{activity}")
    wide["intensity_log"] = _safe_log("value_indexed_intensity")

    wide = wide[[
        "geo", "time", group, "weighting_factor",
        "value_energy_consumption", "value_delta_energy_consumption",
        "activity_log", "structure_log", "intensity_log",
    ]].copy()

    base = (wide[(wide[group] == "Total") & (wide["time"] == first_year)]
            .set_index("geo")["value_energy_consumption"])
    wide["value_energy_consumption_total_baseline"] = wide["geo"].map(base)

    tot = wide[wide[group] == "Total"].set_index(["geo", "time"])
    tkeys = list(zip(wide["geo"], wide["time"]))
    wide["activity_log_total"] = tot["activity_log"].reindex(tkeys).to_numpy()
    wide["value_delta_energy_consumption_total"] = (
        tot["value_delta_energy_consumption"].reindex(tkeys).to_numpy())
    wide["value_energy_consumption_total_end"] = (
        tot["value_energy_consumption"].reindex(tkeys).to_numpy())

    wide = wide[wide[group] != "Total"].copy()
    wide["ACT"] = wide["weighting_factor"] * wide["activity_log_total"]
    wide["STR"] = wide["weighting_factor"] * wide["structure_log"]
    wide["INT"] = wide["weighting_factor"] * wide["intensity_log"]

    out = wide.groupby(["geo", "time"], as_index=False).agg(
        activity_effect=("ACT", lambda s: s.sum(min_count=0)),
        structural_effect=("STR", lambda s: s.sum(min_count=0)),
        intensity_effect=("INT", lambda s: s.sum(min_count=0)),
        energy_consumption_var_obs=("value_delta_energy_consumption_total", "mean"),
        value_energy_consumption_total_baseline=("value_energy_consumption_total_baseline", "mean"),
        value_energy_consumption_total_end=("value_energy_consumption_total_end", "mean"),
    )
    out["energy_consumption_var_calc"] = (
        out["activity_effect"] + out["structural_effect"] + out["intensity_effect"])
    return out


def get_years_with_data(activity_df, activity_col, energy_df, energy_col,
                        first_year, last_year):
    def _min(df, col):
        sub = df[df[col].notna() & (df[col] > 0)]
        return sub["time"].min()

    def _max(df, col):
        sub = df[df[col].notna() & (df[col] > 0)]
        return sub["time"].max()

    fy = max(_min(activity_df, activity_col), _min(energy_df, energy_col), first_year)
    ly = min(_max(activity_df, activity_col), _max(energy_df, energy_col), last_year)
    return fy, ly
