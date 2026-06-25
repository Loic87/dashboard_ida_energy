"""Download the Eurostat data the dashboard needs, into per-country feather files.

Makes the project reproducible without the committed 1.1 GB cache: a fresh
clone runs `python -m ida.download` and gets exactly the `data/*.feather` files
the pipelines read. Replaces the R `data_download.R`.

Each dataset is fetched filtered to the dimensions the pipelines use, reshaped
from Eurostat's wide layout (years as columns) to the long
`[...dims, geo, time, values]` schema, and written one file per country.

Usage:
    python -m ida.download                      # all datasets, all countries
    python -m ida.download --countries FR DE IT  # subset
    python -m ida.download --datasets nrg_bal_c  # one dataset
"""
from __future__ import annotations

import argparse
import sys
import time as _time

import pandas as pd

try:
    import eurostat
except ImportError:  # pragma: no cover
    eurostat = None

from .countries import COUNTRY_NAMES
from .data import DATA_DIR

# dataset code -> fixed dimension filters (besides geo). Mirrors the R pipeline
# and the dimensions each prepare_* step relies on.
DATASETS = {
    "nrg_bal_c": {"unit": ["TJ"]},
    "nama_10_a64": {"na_item": ["B1G"], "unit": ["CLV10_MEUR"]},
    "nama_10_a10_e": {"na_item": ["EMP_DC"], "unit": ["THS_PER"]},
    "nrg_d_hhq": {"siec": ["TOTAL"], "unit": ["TJ"]},
    "nrg_chdd_a": {"unit": ["NR"]},
    "demo_gind": {"indic_de": ["AVG"]},
    "ilc_lvph01": {"unit": ["AVG"]},
    "road_tf_vehmov": {"vehicle": ["TOTAL"], "unit": ["MIO_VKM"]},
    "rail_tf_trainmv": {"train": ["TOTAL"], "unit": ["THS_TRKM"]},
    "iww_tf_vetf": {"tra_cov": ["TOTAL"], "loadstat": ["TOTAL"], "unit": ["THS_VESKM"]},
}

ALL_COUNTRIES = sorted(COUNTRY_NAMES)


def _to_long(df: pd.DataFrame) -> pd.DataFrame:
    """Reshape Eurostat wide output to the long feather schema."""
    df = df.rename(columns={"geo\\TIME_PERIOD": "geo"})
    if "freq" in df.columns:
        df = df.drop(columns=["freq"])
    year_cols = [c for c in df.columns if str(c).isdigit()]
    id_cols = [c for c in df.columns if c not in year_cols]
    long = df.melt(id_vars=id_cols, var_name="time", value_name="values")
    long["time"] = long["time"].astype(float)
    long["values"] = pd.to_numeric(long["values"], errors="coerce")
    return long


def download_dataset(code: str, country: str, filters: dict) -> pd.DataFrame | None:
    """Fetch one dataset for one country; returns the long frame or None."""
    pars = {"freq": ["A"], "geo": [country], **filters}
    try:
        wide = eurostat.get_data_df(code, filter_pars=pars)
    except Exception as exc:  # network / no-data
        print(f"  ! {code} {country}: {exc!r}"[:140], file=sys.stderr)
        return None
    if wide is None or wide.empty:
        return None
    return _to_long(wide)


def run(countries, datasets, out_dir=DATA_DIR, pause=0.0):
    if eurostat is None:
        raise SystemExit("The 'eurostat' package is required: pip install eurostat")
    out_dir.mkdir(parents=True, exist_ok=True)
    n_ok = n_skip = 0
    for code in datasets:
        filters = DATASETS[code]
        print(f"== {code} ({len(countries)} countries) ==")
        for country in countries:
            long = download_dataset(code, country, filters)
            if long is None or long.empty:
                n_skip += 1
                continue
            long.to_feather(out_dir / f"{code}_{country}.feather")
            n_ok += 1
            if pause:
                _time.sleep(pause)
    print(f"\nDone: {n_ok} files written, {n_skip} skipped (no data / error).")
    return n_ok, n_skip


def main(argv=None):
    p = argparse.ArgumentParser(description="Download Eurostat data for the IDA dashboard.")
    p.add_argument("--countries", nargs="+", default=ALL_COUNTRIES,
                   help="country codes (default: all)")
    p.add_argument("--datasets", nargs="+", default=list(DATASETS),
                   choices=list(DATASETS), help="datasets (default: all)")
    p.add_argument("--pause", type=float, default=0.0,
                   help="seconds to pause between requests (politeness)")
    args = p.parse_args(argv)
    run(args.countries, args.datasets, pause=args.pause)


if __name__ == "__main__":
    main()
