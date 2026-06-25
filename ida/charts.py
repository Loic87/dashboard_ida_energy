"""Plotly figures for the industry sector views.

Ports the ggplot/plotly charts from 1a_industry_gva_final.R. Energy values are
shown in PJ (TJ / 1000) and GVA in billion EUR (MEUR / 1000), as in the R app.
"""
from __future__ import annotations

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go

from . import colors

_LAYOUT = dict(
    template="plotly_white",
    margin=dict(l=60, r=20, t=60, b=40),
    legend=dict(title=None, orientation="h", yanchor="bottom", y=-0.25),
    font=dict(size=13),
)


def _empty(msg="Please select a country and years with available data"):
    fig = go.Figure()
    fig.add_annotation(text=msg, showarrow=False, font=dict(size=16))
    fig.update_layout(**_LAYOUT, xaxis=dict(visible=False), yaxis=dict(visible=False))
    return fig


def energy_by_product(df: pd.DataFrame, country: str) -> go.Figure:
    if df is None or df.empty:
        return _empty()
    d = df.copy()
    d["PJ"] = d["energy_consumption"] / 1000
    fig = px.bar(
        d, x="time", y="PJ", color="product",
        color_discrete_map=colors.FINAL_PRODUCTS_COLORS,
        category_orders={"product": list(colors.FINAL_PRODUCTS_COLORS)},
    )
    fig.update_layout(
        **_LAYOUT, title=f"Industry energy consumption by product — {country}",
        yaxis_title="Energy consumption (PJ)", xaxis_title=None, bargap=0.15)
    return fig


def energy_by_sector(df: pd.DataFrame, country: str) -> go.Figure:
    if df is None or df.empty:
        return _empty()
    d = df.copy()
    d["PJ"] = d["energy_consumption"] / 1000
    fig = px.bar(
        d, x="time", y="PJ", color="sector",
        color_discrete_map=colors.MANUFACTURING_SECTORS_COLORS,
        category_orders={"sector": list(colors.MANUFACTURING_SECTORS_COLORS)},
    )
    fig.update_layout(
        **_LAYOUT, title=f"Industry energy consumption by subsector — {country}",
        yaxis_title="Energy consumption (PJ)", xaxis_title=None, bargap=0.15)
    return fig


def gva_by_sector(df: pd.DataFrame, country: str) -> go.Figure:
    if df is None or df.empty:
        return _empty()
    d = df.copy()
    d["GVA_bn"] = d["GVA"] / 1000
    fig = px.bar(
        d, x="time", y="GVA_bn", color="sector",
        color_discrete_map=colors.MANUFACTURING_SECTORS_COLORS,
        category_orders={"sector": list(colors.MANUFACTURING_SECTORS_COLORS)},
    )
    fig.update_layout(
        **_LAYOUT, title=f"Industry gross value added by subsector — {country}",
        yaxis_title="Gross Value Added (Billion EUR)", xaxis_title=None, bargap=0.15)
    return fig


def indexed_indicators(decomposition: pd.DataFrame, first_year: int,
                       country: str) -> go.Figure:
    """Indexed energy / GVA / intensity for the Total sector (first_year = 1)."""
    if decomposition is None or decomposition.empty:
        return _empty()
    total = decomposition[decomposition["sector"] == "Total"]
    wide = total.pivot_table(index="time", columns="measure",
                             values="value_indexed", aggfunc="first")
    rename = {"intensity": "Energy intensity",
              "energy_consumption": "Energy consumption",
              "GVA": "Gross Value Added"}
    wide = wide[[c for c in rename if c in wide.columns]].rename(columns=rename)
    fig = go.Figure()
    for measure in ["Energy consumption", "Gross Value Added", "Energy intensity"]:
        if measure in wide.columns:
            fig.add_trace(go.Scatter(
                x=wide.index, y=wide[measure], mode="lines", name=measure,
                line=dict(color=colors.INDEX_COLORS[measure], width=2.5)))
    fig.update_layout(
        **_LAYOUT, title=f"Indexed indicators — {country} (base {first_year} = 1)",
        yaxis_title=f"Index ({first_year} = 1)", xaxis_title=None)
    return fig


def waterfall(lmdi: pd.DataFrame, first_year: int, last_year: int,
              country: str) -> go.Figure:
    """LMDI decomposition waterfall for the selected end year (PJ)."""
    if lmdi is None or lmdi.empty:
        return _empty()
    row = lmdi[lmdi["time"] == last_year]
    if row.empty:
        return _empty()
    row = row.iloc[0]
    base = row["value_energy_consumption_total_baseline"] / 1000
    act = row["activity_effect"] / 1000
    str_ = row["structural_effect"] / 1000
    inten = row["intensity_effect"] / 1000

    fig = go.Figure(go.Waterfall(
        orientation="v",
        measure=["absolute", "relative", "relative", "relative", "total"],
        x=[f"{first_year} level", "Activity", "Structure", "Intensity",
           f"{last_year} level"],
        y=[base, act, str_, inten, 0],
        text=[f"{v:,.1f}" for v in [base, act, str_, inten,
                                    base + act + str_ + inten]],
        textposition="outside",
        connector=dict(line=dict(color="rgba(0,0,0,0.3)")),
        increasing=dict(marker=dict(color=colors.EFFECT_COLORS["Activity"])),
        decreasing=dict(marker=dict(color=colors.EFFECT_COLORS["Intensity"])),
        totals=dict(marker=dict(color=colors.INDEX_COLORS["Energy consumption"])),
    ))
    fig.update_layout(
        **_LAYOUT, showlegend=False,
        title=f"Decomposition of energy consumption change — {country}",
        yaxis_title="Energy consumption (PJ)", xaxis_title=None)
    return fig


def _stacked_bar(df, value_col, color_col, color_map, title, ytitle, scale):
    if df is None or df.empty:
        return _empty()
    d = df.copy()
    d["_y"] = d[value_col] / scale
    fig = px.bar(d, x="time", y="_y", color=color_col,
                 color_discrete_map=color_map,
                 category_orders={color_col: list(color_map)})
    fig.update_layout(**_LAYOUT, title=title, yaxis_title=ytitle,
                      xaxis_title=None, bargap=0.15)
    return fig


# --- Transport ----------------------------------------------------------------

def transport_energy_by_product(df, country):
    return _stacked_bar(
        df, "energy_consumption", "product", colors.TRANSPORT_PRODUCT_COLORS,
        f"Transport energy consumption by fuel — {country}",
        "Energy consumption (PJ)", 1000)


def transport_energy_by_mode(df, country):
    return _stacked_bar(
        df, "energy_consumption", "mode", colors.TRANSPORT_MODE_COLORS,
        f"Transport energy consumption by mode — {country}",
        "Energy consumption (PJ)", 1000)


def transport_vkm_by_mode(df, country):
    return _stacked_bar(
        df, "VKM", "mode", colors.TRANSPORT_MODE_COLORS,
        f"Traffic by mode — {country}", "Traffic (Million VKM)", 1_000_000)


def transport_indexed_indicators(decomposition, first_year, country):
    if decomposition is None or decomposition.empty:
        return _empty()
    total = decomposition[decomposition["mode"] == "Total"]
    wide = total.pivot_table(index="time", columns="measure",
                             values="value_indexed", aggfunc="first")
    rename = {"intensity": "Energy intensity",
              "energy_consumption": "Energy consumption", "VKM": "Traffic"}
    wide = wide[[c for c in rename if c in wide.columns]].rename(columns=rename)
    fig = go.Figure()
    for measure in ["Energy consumption", "Traffic", "Energy intensity"]:
        if measure in wide.columns:
            fig.add_trace(go.Scatter(
                x=wide.index, y=wide[measure], mode="lines", name=measure,
                line=dict(color=colors.TRANSPORT_INDEX_COLORS[measure], width=2.5)))
    fig.update_layout(
        **_LAYOUT, title=f"Indexed indicators — {country} (base {first_year} = 1)",
        yaxis_title=f"Index ({first_year} = 1)", xaxis_title=None)
    return fig


def residential_energy_by_product(df, country):
    return _stacked_bar(
        df, "energy_consumption", "product", colors.FINAL_PRODUCTS_COLORS,
        f"Residential energy consumption by fuel — {country}",
        "Energy consumption (PJ)", 1000)


_RES_ENDUSE = {"space_heating": "Space heating", "space_cooling": "Space cooling",
               "water_heating": "Water heating", "cooking": "Cooking",
               "light_appliances": "Lighting and appliances", "other": "Other"}


def residential_energy_by_enduse(augmented, country):
    """Stacked bar of residential energy by end use (from the long augmented df)."""
    if augmented is None or augmented.empty:
        return _empty()
    d = augmented[augmented["measure"].isin(_RES_ENDUSE)].copy()
    d = d[d["value"].notna() & (d["value"] != 0)]
    if d.empty:
        return _empty("No end-use breakdown available for this country")
    d["end_use"] = d["measure"].map(_RES_ENDUSE)
    return _stacked_bar(
        d, "value", "end_use", colors.END_USE_COLORS,
        f"Residential energy consumption by end use — {country}",
        "Energy consumption (PJ)", 1000)


def residential_indexed_indicators(indexed, first_year, country):
    if indexed is None or indexed.empty:
        return _empty()
    rename = {"total_pop": "Population", "dwelling_per_cap": "Dwelling per capita",
              "energy_per_dwelling": "Energy per dwelling",
              "temperature_correction": "Weather", "total_res": "Energy consumption"}
    d = indexed[indexed["measure"].isin(rename)].copy()
    wide = d.pivot_table(index="time", columns="measure",
                         values="value_indexed", aggfunc="first").rename(columns=rename)
    fig = go.Figure()
    for measure, color in colors.HOUSEHOLD_INDEX_COLORS.items():
        if measure in wide.columns:
            fig.add_trace(go.Scatter(
                x=wide.index, y=wide[measure], mode="lines", name=measure,
                line=dict(color=color, width=2.5)))
    fig.update_layout(
        **_LAYOUT, title=f"Indexed indicators — {country} (base {first_year} = 1)",
        yaxis_title=f"Index ({first_year} = 1)", xaxis_title=None)
    return fig


def residential_waterfall(lmdi, first_year, last_year, country):
    """Four-effect residential decomposition waterfall (PJ)."""
    if lmdi is None or lmdi.empty:
        return _empty()
    row = lmdi[lmdi["time"] == last_year]
    if row.empty:
        return _empty()
    row = row.iloc[0]
    base = row["value_energy_consumption_baseline"] / 1000
    effects = [("Population", row["population"]), ("Dwelling/cap.", row["household_size"]),
               ("Energy/dwell.", row["household_consumption"]), ("Weather", row["weather"])]
    ys = [base] + [v / 1000 for _, v in effects] + [0]
    total = base + sum(v / 1000 for _, v in effects)
    fig = go.Figure(go.Waterfall(
        orientation="v",
        measure=["absolute", "relative", "relative", "relative", "relative", "total"],
        x=[f"{first_year} level"] + [n for n, _ in effects] + [f"{last_year} level"],
        y=ys,
        text=[f"{v:,.1f}" for v in ys[:-1]] + [f"{total:,.1f}"],
        textposition="outside",
        connector=dict(line=dict(color="rgba(0,0,0,0.3)")),
        increasing=dict(marker=dict(color=colors._RED4)),
        decreasing=dict(marker=dict(color=colors._GREEN4)),
        totals=dict(marker=dict(color=colors._BLUE4)),
    ))
    fig.update_layout(
        **_LAYOUT, showlegend=False,
        title=f"Decomposition of residential energy consumption — {country}",
        yaxis_title="Energy consumption (PJ)", xaxis_title=None)
    return fig


def residential_intensity_effect(lmdi, country):
    """Temperature-corrected actual vs counterfactual (no energy-per-dwelling effect)."""
    if lmdi is None or lmdi.empty:
        return _empty()
    d = lmdi.copy()
    bl = d["value_energy_consumption_baseline"]
    d["Without intensity effect"] = (bl + d["population"] + d["household_size"]) / 1000
    d["Corrected energy consumption"] = (
        bl + d["population"] + d["household_size"] + d["household_consumption"]) / 1000
    fig = go.Figure()
    fig.add_trace(go.Bar(
        x=d["time"], y=d["Corrected energy consumption"],
        name="Corrected energy consumption", marker=dict(color="#27408B", opacity=0.6)))
    fig.add_trace(go.Scatter(
        x=d["time"], y=d["Without intensity effect"], mode="markers",
        name="Without intensity effect",
        marker=dict(color="#2E8B57", size=10, opacity=0.7)))
    fig.update_layout(
        **_LAYOUT,
        title=f"Corrected energy consumption vs counterfactual (no per-dwelling effect) — {country}",
        yaxis_title="Energy consumption (PJ)", xaxis_title=None)
    return fig


def economy_energy_by_sector(df, country):
    return _stacked_bar(
        df, "energy_consumption", "sector", colors.ECONOMY_SECTORS_COLORS,
        f"Economy energy consumption by sector — {country}",
        "Energy consumption (PJ)", 1000)


def economy_employment_by_sector(df, country):
    return _stacked_bar(
        df, "employment", "sector", colors.ECONOMY_SECTORS_COLORS,
        f"Employment by sector — {country}", "Employment (millions)", 1000)


def economy_indexed_indicators(decomposition, first_year, country):
    if decomposition is None or decomposition.empty:
        return _empty()
    total = decomposition[decomposition["sector"] == "Total"]
    wide = total.pivot_table(index="time", columns="measure",
                             values="value_indexed", aggfunc="first")
    rename = {"intensity": "Energy consumption per employee",
              "energy_consumption": "Energy consumption", "employment": "Employment"}
    wide = wide[[c for c in rename if c in wide.columns]].rename(columns=rename)
    fig = go.Figure()
    for measure, color in colors.ECONOMY_INDEX_COLORS.items():
        if measure in wide.columns:
            fig.add_trace(go.Scatter(
                x=wide.index, y=wide[measure], mode="lines", name=measure,
                line=dict(color=color, width=2.5)))
    fig.update_layout(
        **_LAYOUT, title=f"Indexed indicators — {country} (base {first_year} = 1)",
        yaxis_title=f"Index ({first_year} = 1)", xaxis_title=None)
    return fig


def intensity_effect(lmdi: pd.DataFrame, country: str) -> go.Figure:
    """Actual vs counterfactual (no-intensity-effect) energy consumption."""
    if lmdi is None or lmdi.empty:
        return _empty()
    d = lmdi.copy()
    d["Actual"] = d["value_energy_consumption_total_end"] / 1000
    d["Without intensity effect"] = (
        d["value_energy_consumption_total_end"] - d["intensity_effect"]) / 1000
    fig = go.Figure()
    fig.add_trace(go.Bar(
        x=d["time"], y=d["Actual"], name="Actual energy consumption",
        marker=dict(color="#27408B", opacity=0.6)))
    fig.add_trace(go.Scatter(
        x=d["time"], y=d["Without intensity effect"], mode="markers",
        name="Without intensity effect",
        marker=dict(color="#2E8B57", size=10, opacity=0.7)))
    fig.update_layout(
        **_LAYOUT,
        title=f"Actual vs counterfactual energy consumption (no intensity effect) — {country}",
        yaxis_title="Energy consumption (PJ)", xaxis_title=None)
    return fig
