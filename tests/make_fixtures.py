"""Regenerate the trimmed parity-test input fixtures in tests/fixtures/.

The full Eurostat cache in data/ is ~1.1 GB and is gitignored. The parity tests
(test_industry_parity.py) only ever read a handful of datasets for a handful of
countries, and the pipelines select a small, well-defined subset of each. This
script slices those inputs down to the rows the tests actually consume and
writes them to tests/fixtures/ as feather files (a few hundred KB total) so the
suite is self-contained and runs without the full cache.

Safety: the only large input is nrg_bal_c. Every pipeline filter on it requires
unit == "TJ" and selects siec / nrg_bal from the code lists in ida.mappings, so
keeping the *union* of those code lists is a strict superset of every row any
test reads -> trimming cannot change a single test result. The other inputs are
KB-sized and are copied whole (notably nrg_chdd_a, which must stay complete
because residential.py normalises by a mean over the full time series before
filtering years).

Run from the repo root with the full data/ cache present:
    python -m tests.make_fixtures
"""
from __future__ import annotations

import sys
from pathlib import Path

import pyarrow.feather as feather

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from ida import data  # noqa: E402
from ida import mappings as m  # noqa: E402

FIXTURES_DIR = ROOT / "tests" / "fixtures"

# (dataset_id, [country codes]) the parity tests load. Mirrors the fixtures in
# test_industry_parity.py.
NEEDED = {
    "nrg_bal_c": ["FR", "DE", "IT", "CZ", "RO", "NL"],
    "nama_10_a64": ["FR", "DE", "IT"],
    "nama_10_a10_e": ["FR", "DE", "IT"],
    "road_tf_vehmov": ["CZ", "RO", "NL"],
    "rail_tf_trainmv": ["CZ", "RO", "NL"],
    "iww_tf_vetf": ["CZ", "RO", "NL"],
    "nrg_d_hhq": ["FR", "DE", "IT"],
    "demo_gind": ["FR", "DE", "IT"],
    "ilc_lvph01": ["FR", "DE", "IT"],
    "nrg_chdd_a": ["FR", "DE", "IT"],
}

# Superset of every siec / nrg_bal code any pipeline selects from nrg_bal_c.
NRG_SIEC_KEEP = set(m.NRG_PRODS) | set(m.TRA_PRODS) | {"TOTAL"}
NRG_BAL_KEEP = (
    set(m.NRG_IND_SECTORS) | set(m.NRG_TRA) | set(m.NRG_ECO_SECTORS)
    | {"FC_OTH_HH_E"}
)


def trim(dataset_id: str, df):
    """Return the subset of `df` that any test could read; identity for small sets."""
    if dataset_id == "nrg_bal_c":
        return df[
            (df["unit"] == "TJ")
            & (df["siec"].isin(NRG_SIEC_KEEP))
            & (df["nrg_bal"].isin(NRG_BAL_KEEP))
        ].reset_index(drop=True)
    # All other inputs are KB-sized; copy whole (no time/row trimming, to keep
    # full-series computations like nrg_chdd_a's mean exactly intact).
    return df.reset_index(drop=True)


def main():
    FIXTURES_DIR.mkdir(parents=True, exist_ok=True)
    total_in = total_out = 0
    for dataset_id, codes in NEEDED.items():
        for code in codes:
            src = data.DATA_DIR / f"{dataset_id}_{code}.feather"
            if not src.exists():
                print(f"  MISSING {src.name} -- skipped")
                continue
            df = feather.read_table(src).to_pandas()
            out = trim(dataset_id, df)
            dst = FIXTURES_DIR / f"{dataset_id}_{code}.feather"
            feather.write_feather(out, dst, compression="zstd")
            in_kb = src.stat().st_size / 1024
            out_kb = dst.stat().st_size / 1024
            total_in += in_kb
            total_out += out_kb
            print(f"  {dataset_id}_{code}: {len(df):>7} -> {len(out):>6} rows "
                  f"| {in_kb:8.1f} -> {out_kb:7.1f} KB")
    print(f"\nTotal: {total_in/1024:.1f} MB -> {total_out:.1f} KB "
          f"in {FIXTURES_DIR.relative_to(ROOT)}/")


if __name__ == "__main__":
    main()
