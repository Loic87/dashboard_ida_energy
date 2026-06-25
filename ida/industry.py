"""Industry sector IDA pipeline + LMDI decomposition.

Direct port of scripts/1_industry/1a_industry_gva_final.R. Function names mirror
the R `prepare_*` / `apply_*` helpers so the two can be compared step by step.

Activity / structure / intensity effects are decomposed with the additive LMDI
(Logarithmic Mean Divisia Index) method.
"""
from __future__ import annotations

import numpy as np
import pandas as pd

from . import decomp
from . import mappings as m


_aggregate_groups = decomp.aggregate_groups


# --- Energy consumption -------------------------------------------------------

def prepare_industry_energy_consumption_by_product(nrg_bal_c, first_year, last_year):
    if nrg_bal_c.empty:
        return pd.DataFrame()
    df = nrg_bal_c[
        (nrg_bal_c["time"] >= first_year)
        & (nrg_bal_c["time"] <= last_year)
        & (nrg_bal_c["siec"].isin(m.NRG_PRODS))
        & (nrg_bal_c["nrg_bal"].isin(m.NRG_IND_SECTORS))
        & (nrg_bal_c["unit"] == "TJ")
    ]
    df = (
        df.groupby(["geo", "time", "siec"], as_index=False)["values"]
        .sum(min_count=1)
    )
    wide = df.pivot_table(index=["geo", "time"], columns="siec",
                          values="values", aggfunc="sum").reset_index()
    wide.columns.name = None
    wide = _aggregate_groups(wide, m.PRODUCT_GROUPS, m.PRODUCT_RENAME,
                             id_cols=["geo", "time"])
    long = wide.melt(id_vars=["geo", "time"], var_name="product",
                     value_name="energy_consumption")
    long = long[long["energy_consumption"] > 0].copy()
    long["product"] = pd.Categorical(long["product"], categories=m.IDA_FINAL_PROD)
    long = long.dropna(subset=["product"])
    totals = long.groupby(["geo", "time"])["energy_consumption"].transform("sum")
    long["share_energy_consumption"] = long["energy_consumption"] / totals
    return long.reset_index(drop=True)


def _prepare_industry_energy_consumption(nrg_bal_c, first_year, last_year):
    """Wide-by-sector energy consumption (helper shared by sector views)."""
    if nrg_bal_c.empty:
        return pd.DataFrame()
    df = nrg_bal_c[
        (nrg_bal_c["time"] >= first_year)
        & (nrg_bal_c["time"] <= last_year)
        & (nrg_bal_c["nrg_bal"].isin(m.NRG_IND_SECTORS))
        & (nrg_bal_c["siec"].isin(m.NRG_PRODS + ["TOTAL"]))
        & (nrg_bal_c["unit"] == "TJ")
    ].drop(columns=["unit"])
    wide = df.pivot_table(index=["geo", "time", "siec"], columns="nrg_bal",
                          values="values", aggfunc="sum").reset_index()
    wide.columns.name = None
    # R: replace(is.na(.), 0) over the whole frame
    wide = wide.fillna(0)
    wide = _aggregate_groups(wide, m.ENERGY_SECTOR_GROUPS, m.ENERGY_SECTOR_RENAME,
                             id_cols=["geo", "time", "siec"])
    return wide


def prepare_industry_energy_consumption_by_sector(nrg_bal_c, first_year, last_year):
    if nrg_bal_c.empty:
        return pd.DataFrame()
    wide = _prepare_industry_energy_consumption(nrg_bal_c, first_year, last_year)
    wide = wide[wide["siec"] == "TOTAL"].drop(columns=["siec"])
    long = wide.melt(id_vars=["geo", "time"], var_name="sector",
                     value_name="energy_consumption")
    return long.reset_index(drop=True)


# --- GVA ----------------------------------------------------------------------

def prepare_industry_GVA_by_sector(nama_10_a64, first_year, last_year):
    if nama_10_a64.empty:
        return {"df": pd.DataFrame(), "notifications": ["No GVA data"]}
    df = nama_10_a64[
        (nama_10_a64["time"] >= first_year)
        & (nama_10_a64["time"] <= last_year)
        & (nama_10_a64["nace_r2"].isin(m.GVA_IND_SECTORS))
        & (nama_10_a64["na_item"] == "B1G")
        & (nama_10_a64["unit"].isin(["CLV10_MEUR", "CLV15_MEUR"]))
    ][["geo", "time", "nace_r2", "values"]]
    wide = df.pivot_table(index=["geo", "time"], columns="nace_r2",
                          values="values", aggfunc="sum").reset_index()
    wide.columns.name = None
    wide = _aggregate_groups(wide, m.GVA_SECTOR_GROUPS, m.GVA_SECTOR_RENAME,
                             id_cols=["geo", "time"])
    long = wide.melt(id_vars=["geo", "time"], var_name="sector", value_name="GVA")
    return _reverse_negative_gva(long.reset_index(drop=True))


def _reverse_negative_gva(df):
    """Flip negative GVA to positive (Eurostat sign quirk), collecting notes."""
    notifications = []
    neg = df["GVA"].notna() & (df["GVA"] < 0)
    for _, row in df[neg].iterrows():
        notifications.append(
            f"Country: {row['geo']} , Sector: {row['sector']} , "
            f"Year: {int(row['time'])}  -  negative GVA reversed"
        )
    df = df.copy()
    df.loc[neg, "GVA"] = -df.loc[neg, "GVA"]
    return {"df": df, "notifications": notifications}


# --- Decomposition (delegates to the generic LMDI core in decomp.py) ----------

def prepare_industry_GVA_decomposition(industry_GVA, industry_energy_final,
                                       first_year, last_year):
    if industry_GVA.empty or industry_energy_final.empty:
        return {"df": pd.DataFrame(),
                "notifications": ["No data available for LMDI calculation."]}
    merged = pd.merge(industry_GVA, industry_energy_final,
                      on=["geo", "time", "sector"], how="outer")
    merged = decomp.join_energy_activity(merged, activity="GVA")
    # industry drops a sector if ANY in-range year is missing (endpoints_only=False)
    filtered = decomp.filter_decomposition(
        merged, first_year, last_year, activity="GVA", group="sector",
        endpoints_only=False)
    augmented = decomp.add_share(filtered["df"], activity="GVA")
    total = decomp.add_total(augmented, activity="GVA", group="sector")
    full = pd.concat([augmented, total], ignore_index=True)
    full = decomp.add_index_delta(full, first_year, activity="GVA",
                                  group="sector", guarded=True)
    return {"df": full, "notifications": filtered["notifications"]}


def apply_LMDI_industry_gva(df, first_year):
    return decomp.apply_lmdi(df, first_year, activity="GVA", group="sector")


# --- Orchestrator -------------------------------------------------------------

def compute_industry(nrg_bal_c, nama_10_a64, first_year, last_year):
    """Run the full industry pipeline; mirrors the server.R reactive graph."""
    energy_by_product = prepare_industry_energy_consumption_by_product(
        nrg_bal_c, first_year, last_year)
    energy_by_sector = prepare_industry_energy_consumption_by_sector(
        nrg_bal_c, first_year, last_year)
    gva_by_sector = prepare_industry_GVA_by_sector(
        nama_10_a64, first_year, last_year)

    fy, ly = decomp.get_years_with_data(
        gva_by_sector["df"], "GVA", energy_by_sector, "energy_consumption",
        first_year, last_year)

    decomposition = prepare_industry_GVA_decomposition(
        gva_by_sector["df"], energy_by_sector, fy, ly)
    lmdi = apply_LMDI_industry_gva(decomposition["df"], fy)

    return {
        "energy_by_product": energy_by_product,
        "energy_by_sector": energy_by_sector,
        "gva_by_sector": gva_by_sector["df"],
        "first_year_with_data": fy,
        "last_year_with_data": ly,
        "decomposition": decomposition["df"],
        "lmdi": lmdi,
        "notifications": gva_by_sector["notifications"]
        + decomposition["notifications"],
    }
