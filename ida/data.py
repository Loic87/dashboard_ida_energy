"""Data loading for cached Eurostat feather files.

Reads the same `data/<dataset>_<country>.feather` files produced by the R
pipeline (scripts/0_support/data_download.R), so the Python port runs against
identical inputs.
"""
from __future__ import annotations

from functools import lru_cache
from pathlib import Path

import pandas as pd
import pyarrow.feather as feather

# repo_root/ida/data.py -> repo_root
REPO_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = REPO_ROOT / "data"


@lru_cache(maxsize=256)
def load_dataset(dataset_id: str, country_code: str) -> pd.DataFrame:
    """Load one cached dataset for one country; empty frame if missing."""
    path = DATA_DIR / f"{dataset_id}_{country_code}.feather"
    if not path.exists():
        return pd.DataFrame()
    df = feather.read_table(path).to_pandas()
    if "freq" in df.columns:
        df = df.drop(columns=["freq"])
    return df


def available_countries(dataset_id: str = "nrg_bal_c") -> list[str]:
    """Country codes that have a cached file for the given dataset."""
    prefix = f"{dataset_id}_"
    codes = [
        p.stem[len(prefix):]
        for p in DATA_DIR.glob(f"{prefix}*.feather")
    ]
    return sorted(codes)


def latest_year(
    dataset_ids: tuple[str, ...] = ("nrg_bal_c", "nama_10_a64", "nama_10_a10_e"),
) -> int | None:
    """Latest year present in the cache across the given datasets.

    Reads only the `time` column from each cached file (cheap), so the UI can
    track whatever vintage `ida.download` last fetched instead of a hardcoded
    cap. Returns None if the cache is empty.
    """
    years: list[int] = []
    for dataset_id in dataset_ids:
        for code in available_countries(dataset_id):
            path = DATA_DIR / f"{dataset_id}_{code}.feather"
            try:
                col = feather.read_table(path, columns=["time"]).column("time")
            except Exception:
                continue
            if len(col):
                years.append(int(max(col.to_pylist())))
    return max(years) if years else None
