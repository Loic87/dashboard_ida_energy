"""Economy-wide IDA pipeline + LMDI decomposition (employment-based).

Port of scripts/1_industry/1c_economy_emp_final.R. Structurally identical to the
industry decomposition — activity/structure/intensity LMDI — but the activity is
**employment** (thousand persons, nama_10_a10_e) across five economy sectors:
Agriculture, Manufacturing, Construction, Commercial & public services, Other
industries. The shared decomp.py core is reused; only the data prep differs.
"""
from __future__ import annotations

import numpy as np
import pandas as pd

from . import decomp
from . import mappings as m


def _na_nonpos(s):
    return s.where(~(s <= 0), np.nan)


def prepare_economy_energy_consumption(nrg_bal_c, first_year, last_year):
    if nrg_bal_c.empty:
        return pd.DataFrame()
    df = nrg_bal_c[
        (nrg_bal_c["time"] >= first_year) & (nrg_bal_c["time"] <= last_year)
        & (nrg_bal_c["nrg_bal"].isin(m.NRG_ECO_SECTORS))
        & (nrg_bal_c["siec"] == "TOTAL") & (nrg_bal_c["unit"] == "TJ")
    ][["geo", "time", "nrg_bal", "values"]]
    wide = df.pivot_table(index=["geo", "time"], columns="nrg_bal",
                          values="values", aggfunc="sum").reset_index()
    wide.columns.name = None
    wide = decomp.aggregate_groups(wide, m.ECO_ENERGY_GROUPS, m.ECO_ENERGY_RENAME,
                                   id_cols=["geo", "time"])
    long = wide.melt(id_vars=["geo", "time"], var_name="sector",
                     value_name="energy_consumption")
    long["energy_consumption"] = _na_nonpos(long["energy_consumption"])
    return long.reset_index(drop=True)


def prepare_economy_employment(nama_10_a10_e, first_year, last_year):
    if nama_10_a10_e.empty:
        return pd.DataFrame()
    df = nama_10_a10_e[
        (nama_10_a10_e["time"] >= first_year) & (nama_10_a10_e["time"] <= last_year)
        & (nama_10_a10_e["nace_r2"].isin(m.EMP_ECO_SECTORS))
        & (nama_10_a10_e["na_item"] == "EMP_DC") & (nama_10_a10_e["unit"] == "THS_PER")
    ]
    wide = df.pivot_table(index=["geo", "time"], columns="nace_r2",
                          values="values", aggfunc="first").reset_index()
    wide.columns.name = None
    wide = wide.rename(columns={"B-E": "B_E", "G-I": "G_I", "O-Q": "O_Q", "R-U": "R_U"})
    for col in ["A", "B_E", "C", "F", "G_I", "J", "K", "L", "M_N", "O_Q", "R_U"]:
        if col not in wide:
            wide[col] = np.nan
    # Other industries = (B-E) minus Manufacturing(C)
    wide["Other industries"] = wide["B_E"] - wide["C"]
    # Commercial & public services = sum of services NACE groups (na.rm)
    wide["Comm. and pub. services"] = wide[["G_I", "J", "K", "L", "M_N", "O_Q", "R_U"]].sum(axis=1, min_count=0)
    wide = wide.rename(columns={"A": "Agricult., forest. and fish.",
                                "C": "Manufacturing", "F": "Construction"})
    keep = ["geo", "time", "Agricult., forest. and fish.", "Manufacturing",
            "Construction", "Other industries", "Comm. and pub. services"]
    long = wide[keep].melt(id_vars=["geo", "time"], var_name="sector",
                           value_name="employment")
    long["employment"] = _na_nonpos(long["employment"])
    return long.reset_index(drop=True)


# --- Decomposition (delegates to the generic LMDI core) -----------------------

def prepare_economy_decomposition(energy, employment, first_year, last_year):
    if energy.empty or employment.empty:
        return {"df": pd.DataFrame(),
                "notifications": ["No data available for LMDI calculation."]}
    merged = pd.merge(energy, employment, on=["geo", "time", "sector"], how="outer")
    merged = decomp.join_energy_activity(merged, activity="employment")
    filtered = decomp.filter_decomposition(
        merged, first_year, last_year, activity="employment", group="sector",
        endpoints_only=False)
    augmented = decomp.add_share(filtered["df"], activity="employment")
    total = decomp.add_total(augmented, activity="employment", group="sector")
    full = pd.concat([augmented, total], ignore_index=True)
    full = decomp.add_index_delta(full, first_year, activity="employment",
                                  group="sector", guarded=True)
    return {"df": full, "notifications": filtered["notifications"]}


def apply_LMDI_economy(df, first_year):
    return decomp.apply_lmdi(df, first_year, activity="employment", group="sector")


# --- Orchestrator -------------------------------------------------------------

def compute_economy(nrg_bal_c, nama_10_a10_e, first_year, last_year):
    energy_by_sector = prepare_economy_energy_consumption(nrg_bal_c, first_year, last_year)
    employment_by_sector = prepare_economy_employment(nama_10_a10_e, first_year, last_year)

    fy, ly = decomp.get_years_with_data(
        employment_by_sector, "employment", energy_by_sector, "energy_consumption",
        first_year, last_year)

    decomposition = prepare_economy_decomposition(
        energy_by_sector, employment_by_sector, fy, ly)
    lmdi = apply_LMDI_economy(decomposition["df"], fy)
    return {
        "energy_by_sector": energy_by_sector,
        "employment_by_sector": employment_by_sector,
        "first_year_with_data": fy,
        "last_year_with_data": ly,
        "decomposition": decomposition["df"],
        "lmdi": lmdi,
        "notifications": decomposition["notifications"],
    }
