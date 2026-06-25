"""Transport sector IDA pipeline + LMDI decomposition.

Direct port of scripts/3_transport/transport_VKM.R. Activity is Vehicle
Kilometres (VKM) by transport mode (Road / Rail / Navigation); the LMDI core is
shared with industry via decomp.py.

VKM comes from three datasets with different units, all converted to absolute
vehicle-kilometres:
  * road_tf_vehmov  (MIO_VKM)   -> x 1e6
  * rail_tf_trainmv (THS_TRKM)  -> x 1e3
  * iww_tf_vetf     (THS_VESKM) -> x 1e3
"""
from __future__ import annotations

import pandas as pd

from . import decomp
from . import mappings as m


# --- Energy consumption -------------------------------------------------------

def prepare_transport_energy_consumption_by_product(nrg_bal_c, first_year, last_year):
    if nrg_bal_c.empty:
        return pd.DataFrame()
    df = nrg_bal_c[
        (nrg_bal_c["time"] >= first_year)
        & (nrg_bal_c["time"] <= last_year)
        & (nrg_bal_c["siec"].isin(m.TRA_PRODS))
        & (nrg_bal_c["nrg_bal"].isin(m.NRG_TRA))
        & (nrg_bal_c["unit"] == "TJ")
    ]
    df = df.groupby(["geo", "time", "siec"], as_index=False)["values"].sum(min_count=1)
    wide = df.pivot_table(index=["geo", "time"], columns="siec",
                          values="values", aggfunc="sum").reset_index()
    wide.columns.name = None
    wide = decomp.aggregate_groups(wide, m.TRA_PRODUCT_GROUPS, m.TRA_PRODUCT_RENAME,
                                   id_cols=["geo", "time"])
    long = wide.melt(id_vars=["geo", "time"], var_name="product",
                     value_name="energy_consumption")
    long = long[long["energy_consumption"] > 0].copy()
    long["product"] = pd.Categorical(long["product"], categories=m.IDA_TRA_PROD)
    long = long.dropna(subset=["product"])
    totals = long.groupby(["geo", "time"])["energy_consumption"].transform("sum")
    long["share_energy_consumption"] = long["energy_consumption"] / totals
    return long.reset_index(drop=True)


def prepare_transport_energy_consumption_by_mode(nrg_bal_c, first_year, last_year):
    if nrg_bal_c.empty:
        return pd.DataFrame()
    df = nrg_bal_c[
        (nrg_bal_c["time"] >= first_year)
        & (nrg_bal_c["time"] <= last_year)
        & (nrg_bal_c["nrg_bal"].isin(m.NRG_TRA))
        & (nrg_bal_c["siec"] == "TOTAL")
        & (nrg_bal_c["unit"] == "TJ")
    ][["geo", "time", "nrg_bal", "values"]]
    wide = df.pivot_table(index=["geo", "time"], columns="nrg_bal",
                          values="values", aggfunc="sum").reset_index()
    wide.columns.name = None
    wide = wide.rename(columns=m.TRA_MODE_RENAME)
    modes = [c for c in ["Road", "Rail", "Navigation"] if c in wide.columns]
    long = wide.melt(id_vars=["geo", "time"], value_vars=modes,
                     var_name="mode", value_name="energy_consumption")
    return long.reset_index(drop=True)


# --- Traffic (VKM) ------------------------------------------------------------

def prepare_transport_vkm(road, rail, iww, first_year, last_year):
    frames = []

    if road is not None and not road.empty:
        r = road[
            (road["time"] >= first_year) & (road["time"] <= last_year)
            & (road["regisveh"].isin(["TERNAT_REG", "TERNAT_REGNAT"]))
            & (road["vehicle"] == "TOTAL") & (road["unit"] == "MIO_VKM")
        ]
        # one row per (geo, time, regisveh); "first" preserves NaN (sum -> 0),
        # dropna=False keeps all-NaN years (R's pivot_wider does too)
        rw = r.pivot_table(index=["geo", "time"], columns="regisveh",
                           values="values", aggfunc="first",
                           dropna=False).reset_index()
        rw.columns.name = None
        reg = rw["TERNAT_REG"] if "TERNAT_REG" in rw else pd.Series(pd.NA, index=rw.index)
        regnat = rw["TERNAT_REGNAT"] if "TERNAT_REGNAT" in rw else pd.Series(pd.NA, index=rw.index)
        rw["values"] = reg.where(reg.notna(), regnat)
        rw["VKM"] = rw["values"] * 1_000_000
        rw["mode"] = "Road"
        frames.append(rw[["geo", "time", "VKM", "mode"]])

    if rail is not None and not rail.empty:
        r = rail[
            (rail["time"] >= first_year) & (rail["time"] <= last_year)
            & (rail["train"] == "TOTAL") & (rail["unit"] == "THS_TRKM")
        ].copy()
        r["VKM"] = r["values"] * 1_000
        r["mode"] = "Rail"
        frames.append(r[["geo", "time", "VKM", "mode"]])

    if iww is not None and not iww.empty:
        w = iww[
            (iww["time"] >= first_year) & (iww["time"] <= last_year)
            & (iww["tra_cov"] == "TOTAL") & (iww["loadstat"] == "TOTAL")
            & (iww["unit"] == "THS_VESKM")
        ].copy()
        w["VKM"] = w["values"] * 1_000
        w["mode"] = "Navigation"
        frames.append(w[["geo", "time", "VKM", "mode"]])

    traffic = pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()
    if not traffic.empty:
        # ensure float dtype (the pd.NA road fallback can yield object dtype)
        traffic["VKM"] = pd.to_numeric(traffic["VKM"], errors="coerce")
    return {"df": traffic, "notifications": []}


# --- Decomposition (delegates to the generic LMDI core) -----------------------

def prepare_transport_vkm_decomposition(traffic, transport_energy, first_year, last_year):
    if traffic.empty or transport_energy.empty:
        return {"df": pd.DataFrame(),
                "notifications": ["No data available for LMDI calculation."]}
    merged = pd.merge(transport_energy, traffic,
                      on=["geo", "time", "mode"], how="outer")
    merged = decomp.join_energy_activity(merged, activity="VKM")
    # transport drops a mode only if the first/last year is missing (endpoints_only)
    filtered = decomp.filter_decomposition(
        merged, first_year, last_year, activity="VKM", group="mode",
        endpoints_only=True)
    augmented = decomp.add_share(filtered["df"], activity="VKM")
    total = decomp.add_total(augmented, activity="VKM", group="mode")
    full = pd.concat([augmented, total], ignore_index=True)
    # transport indexes straight through (no zero/NaN guard)
    full = decomp.add_index_delta(full, first_year, activity="VKM",
                                  group="mode", guarded=False)
    return {"df": full, "notifications": filtered["notifications"]}


def apply_LMDI_transport_vkm(df, first_year):
    return decomp.apply_lmdi(df, first_year, activity="VKM", group="mode")


# --- Orchestrator -------------------------------------------------------------

def compute_transport(nrg_bal_c, road, rail, iww, first_year, last_year):
    energy_by_product = prepare_transport_energy_consumption_by_product(
        nrg_bal_c, first_year, last_year)
    energy_by_mode = prepare_transport_energy_consumption_by_mode(
        nrg_bal_c, first_year, last_year)
    vkm = prepare_transport_vkm(road, rail, iww, first_year, last_year)

    fy, ly = decomp.get_years_with_data(
        vkm["df"], "VKM", energy_by_mode, "energy_consumption",
        first_year, last_year)

    decomposition = prepare_transport_vkm_decomposition(
        vkm["df"], energy_by_mode, fy, ly)
    lmdi = apply_LMDI_transport_vkm(decomposition["df"], fy)

    return {
        "energy_by_product": energy_by_product,
        "energy_by_mode": energy_by_mode,
        "vkm_by_mode": vkm["df"],
        "first_year_with_data": fy,
        "last_year_with_data": ly,
        "decomposition": decomposition["df"],
        "lmdi": lmdi,
        "notifications": decomposition["notifications"],
    }
