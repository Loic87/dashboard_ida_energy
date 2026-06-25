"""Parity tests: Python industry pipeline vs R reference outputs.

The R reference CSVs are produced by python/reference/reference_gen.R from the
same cached feather files, so any numerical drift here is a port bug.
"""
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from ida import data, economy, industry, residential, transport  # noqa: E402

REF_DIR = ROOT / "reference"
COUNTRIES = ["FR", "DE", "IT"]
FIRST_YEAR, LAST_YEAR = 2000, 2021

# (stage key in compute_industry result, sort columns)
STAGES = {
    "energy_by_product": ["time", "product"],
    "energy_by_sector": ["time", "sector"],
    "gva_by_sector": ["time", "sector"],
    "decomposition": ["time", "sector", "measure"],
    "lmdi": ["time"],
}

# Transport: CZ/RO/NL at 2012-2016 (see reference_gen.R). CZ/RO exercise
# Navigation+Rail and NL exercises Road, covering all three modes. Reference
# file suffix `tra_<stage>` -> compute_transport result key.
TRA_COUNTRIES = ["CZ", "RO", "NL"]
TRA_FIRST_YEAR, TRA_LAST_YEAR = 2012, 2016
TRA_STAGES = {
    "tra_energy_by_product": ("energy_by_product", ["time", "product"]),
    "tra_energy_by_mode": ("energy_by_mode", ["time", "mode"]),
    "tra_vkm_by_mode": ("vkm_by_mode", ["time", "mode"]),
    "tra_decomposition": ("decomposition", ["time", "mode", "measure"]),
    "tra_lmdi": ("lmdi", ["time"]),
}


def _normalize(df, sort_cols):
    df = df.copy()
    # categoricals (product) -> str for stable comparison
    for c in df.columns:
        if isinstance(df[c].dtype, pd.CategoricalDtype):
            df[c] = df[c].astype(str)
    sort_cols = [c for c in sort_cols if c in df.columns]
    df = df.sort_values(sort_cols).reset_index(drop=True)
    df.columns = [str(c) for c in df.columns]
    return df


@pytest.fixture(scope="module")
def results():
    out = {}
    for code in COUNTRIES:
        nrg = data.load_dataset("nrg_bal_c", code)
        nama = data.load_dataset("nama_10_a64", code)
        out[code] = industry.compute_industry(nrg, nama, FIRST_YEAR, LAST_YEAR)
    return out


def _compare(ref, got, sort_cols, label):
    assert not got.empty, f"{label} produced empty frame"
    ref = _normalize(ref, sort_cols)
    got = _normalize(got, sort_cols)

    # align columns present in both (R may keep helper cols dropped in Python)
    common = [c for c in ref.columns if c in got.columns]
    assert len(common) >= len(ref.columns) - 1, (
        f"column mismatch {label}: ref={list(ref.columns)} got={list(got.columns)}")
    assert len(ref) == len(got), (
        f"row count {label}: ref={len(ref)} got={len(got)}")

    for col in common:
        if pd.api.types.is_numeric_dtype(ref[col]):
            np.testing.assert_allclose(
                got[col].to_numpy(dtype=float), ref[col].to_numpy(dtype=float),
                rtol=1e-6, atol=1e-6, equal_nan=True,
                err_msg=f"{label} column {col} differs")
        else:
            assert (got[col].astype(str).to_numpy()
                    == ref[col].astype(str).to_numpy()).all(), (
                f"{label} column {col} differs")


@pytest.mark.parametrize("code", COUNTRIES)
@pytest.mark.parametrize("stage", list(STAGES))
def test_industry_stage_matches_reference(results, code, stage):
    ref_path = REF_DIR / f"{code}_{stage}.csv"
    if not ref_path.exists():
        pytest.skip(f"no reference for {code}/{stage}")
    _compare(pd.read_csv(ref_path), results[code][stage],
             STAGES[stage], f"{code}/{stage}")


def test_industry_years_with_data(results):
    for code in COUNTRIES:
        assert results[code]["first_year_with_data"] == FIRST_YEAR
        assert results[code]["last_year_with_data"] == LAST_YEAR


@pytest.fixture(scope="module")
def tra_results():
    out = {}
    for code in TRA_COUNTRIES:
        nrg = data.load_dataset("nrg_bal_c", code)
        road = data.load_dataset("road_tf_vehmov", code)
        rail = data.load_dataset("rail_tf_trainmv", code)
        iww = data.load_dataset("iww_tf_vetf", code)
        out[code] = transport.compute_transport(
            nrg, road, rail, iww, TRA_FIRST_YEAR, TRA_LAST_YEAR)
    return out


@pytest.mark.parametrize("code", TRA_COUNTRIES)
@pytest.mark.parametrize("stage", list(TRA_STAGES))
def test_transport_stage_matches_reference(tra_results, code, stage):
    ref_path = REF_DIR / f"{code}_{stage}.csv"
    if not ref_path.exists():
        pytest.skip(f"no reference for {code}/{stage}")
    key, sort_cols = TRA_STAGES[stage]
    _compare(pd.read_csv(ref_path), tra_results[code][key], sort_cols,
             f"{code}/{stage}")


# Residential: FR/DE/IT at 2005-2021 (see reference_gen_residential.R).
RES_COUNTRIES = ["FR", "DE", "IT"]
RES_FIRST_YEAR, RES_LAST_YEAR = 2005, 2021
RES_STAGES = {
    "res_augmented": ("augmented", ["time", "measure"]),
    "res_lmdi": ("lmdi", ["time"]),
}


@pytest.fixture(scope="module")
def res_results():
    out = {}
    for code in RES_COUNTRIES:
        out[code] = residential.compute_residential(
            data.load_dataset("nrg_bal_c", code),
            data.load_dataset("nrg_d_hhq", code),
            data.load_dataset("demo_gind", code),
            data.load_dataset("ilc_lvph01", code),
            data.load_dataset("nrg_chdd_a", code),
            RES_FIRST_YEAR, RES_LAST_YEAR)
    return out


@pytest.mark.parametrize("code", RES_COUNTRIES)
@pytest.mark.parametrize("stage", list(RES_STAGES))
def test_residential_stage_matches_reference(res_results, code, stage):
    ref_path = REF_DIR / f"{code}_{stage}.csv"
    if not ref_path.exists():
        pytest.skip(f"no reference for {code}/{stage}")
    key, sort_cols = RES_STAGES[stage]
    _compare(pd.read_csv(ref_path), res_results[code][key], sort_cols,
             f"{code}/{stage}")


# Economy-wide / employment: FR/DE/IT at 2000-2021 (see reference_gen_economy.R).
ECO_COUNTRIES = ["FR", "DE", "IT"]
ECO_FIRST_YEAR, ECO_LAST_YEAR = 2000, 2021
ECO_STAGES = {
    "eco_energy_by_sector": ("energy_by_sector", ["time", "sector"]),
    "eco_employment_by_sector": ("employment_by_sector", ["time", "sector"]),
    "eco_decomposition": ("decomposition", ["time", "sector", "measure"]),
    "eco_lmdi": ("lmdi", ["time"]),
}


@pytest.fixture(scope="module")
def eco_results():
    out = {}
    for code in ECO_COUNTRIES:
        out[code] = economy.compute_economy(
            data.load_dataset("nrg_bal_c", code),
            data.load_dataset("nama_10_a10_e", code),
            ECO_FIRST_YEAR, ECO_LAST_YEAR)
    return out


@pytest.mark.parametrize("code", ECO_COUNTRIES)
@pytest.mark.parametrize("stage", list(ECO_STAGES))
def test_economy_stage_matches_reference(eco_results, code, stage):
    ref_path = REF_DIR / f"{code}_{stage}.csv"
    if not ref_path.exists():
        pytest.skip(f"no reference for {code}/{stage}")
    key, sort_cols = ECO_STAGES[stage]
    _compare(pd.read_csv(ref_path), eco_results[code][key], sort_cols,
             f"{code}/{stage}")
