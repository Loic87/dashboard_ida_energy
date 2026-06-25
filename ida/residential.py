"""Residential sector IDA pipeline + LMDI decomposition.

Port of scripts/2_household/households.R. Unlike industry/transport this is a
single-sector decomposition (one row per geo-year) into FOUR effects:

    ΔE = Population + Dwelling-per-capita + Weather + Energy-per-dwelling

with a weather (HDD/CDD) normalisation of space heating/cooling. Because the
structure differs from the activity/structure/intensity core, it has its own
module rather than reusing decomp.py.
"""
from __future__ import annotations

import numpy as np
import pandas as pd

from . import decomp
from . import mappings as m

# nrg_d_hhq end-use code -> friendly column name
ENDUSE_RENAME = {
    "FC_OTH_HH_E": "total_res",
    "FC_OTH_HH_E_SH": "space_heating",
    "FC_OTH_HH_E_SC": "space_cooling",
    "FC_OTH_HH_E_WH": "water_heating",
    "FC_OTH_HH_E_CK": "cooking",
    "FC_OTH_HH_E_LE": "light_appliances",
    "FC_OTH_HH_E_OE": "other",
}
END_USES = ["space_heating", "space_cooling", "water_heating",
            "cooking", "light_appliances", "other"]
END_USE_LABELS = {
    "space_heating": "Space heating", "space_cooling": "Space cooling",
    "water_heating": "Water heating", "cooking": "Cooking",
    "light_appliances": "Lighting and appliances", "other": "Other",
}


def _na_nonpos(s):
    """Replace values <= 0 with NaN (R: replace(x, which(x<=0), NA))."""
    return s.where(~(s <= 0), np.nan)


# --- Fuel breakdown -----------------------------------------------------------

def prepare_energy_product_breakdown(nrg_bal_c, first_year, last_year):
    """Household energy by fuel (same product groups as industry)."""
    if nrg_bal_c.empty:
        return pd.DataFrame()
    df = nrg_bal_c[
        (nrg_bal_c["time"] >= first_year) & (nrg_bal_c["time"] <= last_year)
        & (nrg_bal_c["nrg_bal"] == "FC_OTH_HH_E")
        & (nrg_bal_c["siec"].isin(m.NRG_PRODS)) & (nrg_bal_c["unit"] == "TJ")
    ]
    df = df.groupby(["geo", "time", "siec"], as_index=False)["values"].sum(min_count=1)
    wide = df.pivot_table(index=["geo", "time"], columns="siec",
                          values="values", aggfunc="sum").reset_index()
    wide.columns.name = None
    wide = decomp.aggregate_groups(wide, m.PRODUCT_GROUPS, m.PRODUCT_RENAME,
                                   id_cols=["geo", "time"])
    long = wide.melt(id_vars=["geo", "time"], var_name="product",
                     value_name="energy_consumption")
    long = long[long["energy_consumption"] > 0].copy()
    long["product"] = pd.Categorical(long["product"], categories=m.IDA_FINAL_PROD)
    long = long.dropna(subset=["product"])
    totals = long.groupby(["geo", "time"])["energy_consumption"].transform("sum")
    long["share_energy_consumption"] = long["energy_consumption"] / totals
    return long.reset_index(drop=True)


# --- Energy consumption (aggregated + disaggregated by end use) ---------------

def prepare_energy_consumption(nrg_bal_c, nrg_d_hhq, first_year, last_year):
    agg = pd.DataFrame(columns=["geo", "time", "total_bal"])
    if not nrg_bal_c.empty:
        a = nrg_bal_c[
            (nrg_bal_c["time"] >= first_year) & (nrg_bal_c["time"] <= last_year)
            & (nrg_bal_c["nrg_bal"] == "FC_OTH_HH_E")
            & (nrg_bal_c["siec"] == "TOTAL") & (nrg_bal_c["unit"] == "TJ")
        ][["geo", "time", "values"]].rename(columns={"values": "total_bal"})
        agg = a

    dis = pd.DataFrame(columns=["geo", "time"])
    if not nrg_d_hhq.empty:
        d = nrg_d_hhq[
            (nrg_d_hhq["time"] >= first_year) & (nrg_d_hhq["time"] <= last_year)
            & (nrg_d_hhq["siec"] == "TOTAL") & (nrg_d_hhq["unit"] == "TJ")
        ]
        dis = d.pivot_table(index=["geo", "time"], columns="nrg_bal",
                            values="values", aggfunc="first").reset_index()
        dis.columns.name = None
        dis = dis.rename(columns=ENDUSE_RENAME)

    for col in ["total_bal"]:
        if col in agg:
            agg[col] = _na_nonpos(agg[col])
    for col in ["total_res", "cooking", "light_appliances", "other",
                "space_cooling", "space_heating", "water_heating"]:
        if col in dis:
            dis[col] = _na_nonpos(dis[col])

    return pd.merge(agg, dis, on=["geo", "time"], how="outer")


def prepare_activity(demo_gind, ilc_lvph01, nrg_chdd_a, first_year, last_year):
    pop = pd.DataFrame(columns=["geo", "time", "total_pop"])
    if not demo_gind.empty:
        p = demo_gind[(demo_gind["time"] >= first_year)
                      & (demo_gind["time"] <= last_year)
                      & (demo_gind["indic_de"] == "AVG")]
        pop = p[["geo", "time", "values"]].rename(columns={"values": "total_pop"})

    size = pd.DataFrame(columns=["geo", "time", "HH_size"])
    if not ilc_lvph01.empty:
        s = ilc_lvph01[(ilc_lvph01["time"] >= first_year)
                       & (ilc_lvph01["time"] <= last_year)]
        size = s[["geo", "time", "values"]].rename(columns={"values": "HH_size"})

    chdd = pd.DataFrame(columns=["geo", "time", "CDD", "HDD", "CDD_norm", "HDD_norm"])
    if not nrg_chdd_a.empty:
        c = nrg_chdd_a.pivot_table(index=["geo", "time"], columns="indic_nrg",
                                   values="values", aggfunc="first").reset_index()
        c.columns.name = None
        # normalise by the per-country mean over the FULL series, then clip range.
        # R's mean() has no na.rm, so a single NaN makes the mean NaN (skipna=False).
        g = c.groupby("geo")
        c["CDD_norm"] = c["CDD"] / g["CDD"].transform(lambda x: x.mean(skipna=False))
        c["HDD_norm"] = c["HDD"] / g["HDD"].transform(lambda x: x.mean(skipna=False))
        chdd = c[(c["time"] >= first_year) & (c["time"] <= last_year)]

    pop = pop.copy(); pop["total_pop"] = _na_nonpos(pop["total_pop"])
    size = size.copy(); size["HH_size"] = _na_nonpos(size["HH_size"])
    chdd = chdd.copy()
    for col in ["CDD_norm", "HDD_norm"]:
        if col in chdd:
            chdd[col] = _na_nonpos(chdd[col])

    out = pd.merge(pop, size, on=["geo", "time"], how="outer")
    out = pd.merge(out, chdd, on=["geo", "time"], how="outer")
    return out


def join_energy_consumption_activity(df):
    """Compute residential indicators; returns long (geo, time, measure, value)."""
    if df.empty:
        return df
    df = df.copy()
    for col in END_USES + ["total_bal", "total_res", "total_pop", "HH_size",
                           "CDD", "HDD", "CDD_norm", "HDD_norm"]:
        if col not in df:
            df[col] = np.nan

    df["occupied_dwellings"] = df["total_pop"] / df["HH_size"]
    df["space_heating_corrected"] = np.where(
        df["HDD_norm"].isna(), df["space_heating"], df["space_heating"] / df["HDD_norm"])
    df["space_cooling_corrected"] = np.where(
        df["CDD_norm"].isna(), df["space_cooling"], df["space_cooling"] / df["CDD_norm"])

    # rowSums(..., na.rm=TRUE): NaN treated as 0
    plus = df[["total_bal", "space_heating_corrected", "space_cooling_corrected"]].sum(axis=1, min_count=0)
    minus = df[["space_heating", "space_cooling"]].sum(axis=1, min_count=0)
    df["total_res_corrected"] = plus - minus
    df["total_res"] = df["total_bal"]
    df["total_res_corrected"] = np.where(
        df["total_res_corrected"].isna() | (df["total_res_corrected"] == 0),
        df["total_bal"], df["total_res_corrected"])
    df["dwelling_per_cap"] = 1 / df["HH_size"]
    df["temperature_correction"] = np.where(
        df["total_res_corrected"] == 0, df["total_res"],
        df["total_res"] / df["total_res_corrected"])
    df["energy_per_dwelling"] = df["total_res_corrected"] / df["occupied_dwellings"]

    long = df.melt(id_vars=["geo", "time"], var_name="measure", value_name="value")
    long = long.sort_values("time")
    long["time"] = long["time"].astype(int)
    return long.reset_index(drop=True)


def add_index_delta(df, base_year):
    if df.empty:
        return df
    base = (df[df["time"] == base_year].set_index(["geo", "measure"])["value"])
    keys = list(zip(df["geo"], df["measure"]))
    b = base.reindex(keys).to_numpy()
    v = df["value"].to_numpy()
    df = df.copy()
    df["value_indexed"] = v / b
    df["value_delta"] = v - b
    return df


def apply_LMDI(df, base_year):
    if df.empty:
        return df
    wide = df.pivot_table(index=["geo", "time"], columns="measure",
                          values=["value", "value_indexed", "value_delta"],
                          aggfunc="first")
    wide.columns = [f"{a}_{b}" for a, b in wide.columns]
    wide = wide.reset_index()

    def _log(s):
        with np.errstate(divide="ignore", invalid="ignore"):
            return np.log(s)

    delta_tr = wide["value_delta_total_res"]
    wide["weighting_factor"] = np.where(
        delta_tr == 0, wide["value_total_res"],
        delta_tr / _log(wide["value_indexed_total_res"]))
    pop_log = _log(wide["value_indexed_total_pop"])
    size_log = _log(wide["value_indexed_dwelling_per_cap"])
    weather_log = _log(wide["value_indexed_temperature_correction"])
    cons_log = _log(wide["value_indexed_energy_per_dwelling"])

    out = wide[["geo", "time", "value_delta_total_res"]].copy()
    out["value_energy_consumption_end"] = wide["value_total_res"]
    base = (wide[wide["time"] == base_year].set_index("geo")["value_total_res"])
    out["value_energy_consumption_baseline"] = wide["geo"].map(base)
    out["population"] = wide["weighting_factor"] * pop_log
    out["household_size"] = wide["weighting_factor"] * size_log
    out["weather"] = wide["weighting_factor"] * weather_log
    out["household_consumption"] = wide["weighting_factor"] * cons_log
    out["energy_consumption_delta_calc"] = out[
        ["population", "household_size", "weather", "household_consumption"]
    ].sum(axis=1, min_count=0)
    return out


# --- Year coverage ------------------------------------------------------------

def residential_years_with_data(consumption, activity, first_year, last_year):
    """Base/last year where energy (total_bal), population and HH size all exist."""
    e = consumption[consumption["total_bal"].notna() & (consumption["total_bal"] > 0)]
    a = activity[activity["total_pop"].notna() & (activity["total_pop"] > 0)
                 & activity["HH_size"].notna() & (activity["HH_size"] > 0)]
    if e.empty or a.empty:
        return None, None
    fy = int(max(e["time"].min(), a["time"].min(), first_year))
    ly = int(min(e["time"].max(), a["time"].max(), last_year))
    return fy, ly


# --- Orchestrator -------------------------------------------------------------

def compute_residential(nrg_bal_c, nrg_d_hhq, demo_gind, ilc_lvph01,
                        nrg_chdd_a, first_year, last_year):
    fuel = prepare_energy_product_breakdown(nrg_bal_c, first_year, last_year)
    consumption = prepare_energy_consumption(nrg_bal_c, nrg_d_hhq, first_year, last_year)
    activity = prepare_activity(demo_gind, ilc_lvph01, nrg_chdd_a, first_year, last_year)

    fy, ly = residential_years_with_data(consumption, activity, first_year, last_year)

    augmented = join_energy_consumption_activity(
        pd.merge(consumption, activity, on=["geo", "time"], how="outer"))
    if fy is None or augmented.empty:
        return {"fuel": fuel, "augmented": augmented, "lmdi": pd.DataFrame(),
                "first_year_with_data": fy, "last_year_with_data": ly,
                "notifications": ["No data available for LMDI calculation."]}

    indexed = add_index_delta(augmented, fy)
    lmdi = apply_LMDI(indexed, fy)
    lmdi = lmdi[(lmdi["time"] >= fy) & (lmdi["time"] <= ly)].reset_index(drop=True)
    return {
        "fuel": fuel,
        "augmented": augmented,
        "indexed": indexed,
        "lmdi": lmdi,
        "first_year_with_data": fy,
        "last_year_with_data": ly,
        "notifications": [],
    }
