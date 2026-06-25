"""Energy Decomposition Analysis dashboard — Dash front-end.

Python port of the R Shiny dashboard. Run:
    python/.venv/bin/python python/app.py
then open http://127.0.0.1:8050
"""
from __future__ import annotations

import dash
import dash_bootstrap_components as dbc
from dash import Input, Output, dcc, html

from ida import charts, countries, data, economy, industry, residential, transport

INDUSTRY_COUNTRIES = sorted(
    set(data.available_countries("nrg_bal_c"))
    & set(data.available_countries("nama_10_a64"))
)
COUNTRY_OPTIONS = [{"label": countries.name(c), "value": c} for c in INDUSTRY_COUNTRIES]
DEFAULT_COUNTRY = "FR" if "FR" in INDUSTRY_COUNTRIES else INDUSTRY_COUNTRIES[0]

# MAX_YEAR tracks whatever vintage `ida.download` last fetched (falls back to a
# sensible cap if the cache is empty); MIN_YEAR is a fixed sensible floor.
MIN_YEAR = 1990
MAX_YEAR = data.latest_year() or 2023
DEFAULT_YEARS = [2000, MAX_YEAR]

app = dash.Dash(
    __name__,
    external_stylesheets=[dbc.themes.FLATLY, dbc.icons.FONT_AWESOME],
    title="IDA Energy Dashboard",
    suppress_callback_exceptions=True,
)
server = app.server  # for gunicorn / deployment


def _card(title, graph_id, height=420):
    return dbc.Card(
        dbc.CardBody([
            html.H6(title, className="text-muted mb-2"),
            dcc.Loading(dcc.Graph(id=graph_id, style={"height": f"{height}px"}),
                        type="default", color="#2C3E50"),
        ]),
        className="shadow-sm mb-4",
    )


sidebar = dbc.Card(dbc.CardBody([
    html.H4([html.I(className="fa-solid fa-bolt me-2"), "IDA Energy"],
            className="mb-1"),
    html.P("Index Decomposition Analysis of energy use across Europe (LMDI).",
           className="text-muted small"),
    html.Hr(),
    html.Label("Country", className="fw-bold"),
    dcc.Dropdown(id="country", options=COUNTRY_OPTIONS, value=DEFAULT_COUNTRY,
                 clearable=False, className="mb-4"),
    html.Label("Year range", className="fw-bold"),
    dcc.RangeSlider(
        id="year-range", min=MIN_YEAR, max=MAX_YEAR, step=1, value=DEFAULT_YEARS,
        marks={y: str(y) for y in range(MIN_YEAR, MAX_YEAR + 1, 5)},
        tooltip={"placement": "bottom", "always_visible": True}),
    html.Hr(),
    html.Div(id="status", className="small text-muted"),
]), className="shadow-sm")


def _industry_tab():
    return [
        dbc.Tabs(active_tab="ind-overview", className="mt-3", children=[
            dbc.Tab(label="Energy & GVA by sector", tab_id="ind-overview", children=[
                html.Div(className="pt-3", children=[
                    _card("Energy consumption by product", "fig-energy-product"),
                    _card("Energy consumption by subsector", "fig-energy-sector"),
                    _card("Gross value added by subsector", "fig-gva-sector"),
                ]),
            ]),
            dbc.Tab(label="LMDI decomposition", tab_id="ind-decomp", children=[
                html.Div(className="pt-3", children=[
                    dbc.Row([
                        dbc.Col(_card("Indexed indicators", "fig-indexed"), md=6),
                        dbc.Col(_card("Decomposition waterfall", "fig-waterfall"), md=6),
                    ]),
                    _card("Intensity effect (actual vs counterfactual)", "fig-intensity"),
                ]),
            ]),
        ]),
    ]


def _transport_tab():
    return [
        dbc.Tabs(active_tab="tra-overview", className="mt-3", children=[
            dbc.Tab(label="Energy & traffic by mode", tab_id="tra-overview", children=[
                html.Div(className="pt-3", children=[
                    _card("Energy consumption by fuel", "fig-tra-energy-product"),
                    _card("Energy consumption by mode", "fig-tra-energy-mode"),
                    _card("Traffic (vehicle-km) by mode", "fig-tra-vkm-mode"),
                ]),
            ]),
            dbc.Tab(label="LMDI decomposition", tab_id="tra-decomp", children=[
                html.Div(className="pt-3", children=[
                    dbc.Row([
                        dbc.Col(_card("Indexed indicators", "fig-tra-indexed"), md=6),
                        dbc.Col(_card("Decomposition waterfall", "fig-tra-waterfall"), md=6),
                    ]),
                    _card("Intensity effect (actual vs counterfactual)", "fig-tra-intensity"),
                ]),
            ]),
        ]),
    ]


def _residential_tab():
    return [
        dbc.Tabs(active_tab="res-overview", className="mt-3", children=[
            dbc.Tab(label="Energy by fuel & end use", tab_id="res-overview", children=[
                html.Div(className="pt-3", children=[
                    _card("Energy consumption by fuel", "fig-res-fuel"),
                    _card("Energy consumption by end use", "fig-res-enduse"),
                ]),
            ]),
            dbc.Tab(label="LMDI decomposition", tab_id="res-decomp", children=[
                html.Div(className="pt-3", children=[
                    dbc.Row([
                        dbc.Col(_card("Indexed indicators", "fig-res-indexed"), md=6),
                        dbc.Col(_card("Decomposition waterfall", "fig-res-waterfall"), md=6),
                    ]),
                    _card("Intensity effect (actual vs counterfactual)", "fig-res-intensity"),
                ]),
            ]),
        ]),
    ]


def _economy_tab():
    return [
        dbc.Tabs(active_tab="eco-overview", className="mt-3", children=[
            dbc.Tab(label="Energy & employment by sector", tab_id="eco-overview", children=[
                html.Div(className="pt-3", children=[
                    _card("Energy consumption by sector", "fig-eco-energy"),
                    _card("Employment by sector", "fig-eco-employment"),
                ]),
            ]),
            dbc.Tab(label="LMDI decomposition", tab_id="eco-decomp", children=[
                html.Div(className="pt-3", children=[
                    dbc.Row([
                        dbc.Col(_card("Indexed indicators", "fig-eco-indexed"), md=6),
                        dbc.Col(_card("Decomposition waterfall", "fig-eco-waterfall"), md=6),
                    ]),
                    _card("Intensity effect (actual vs counterfactual)", "fig-eco-intensity"),
                ]),
            ]),
        ]),
    ]


app.layout = dbc.Container(fluid=True, className="py-3", children=[
    dbc.Row([
        dbc.Col(sidebar, md=3, lg=2),
        dbc.Col(md=9, lg=10, children=[
            dbc.Tabs(active_tab="sector-industry", children=[
                dbc.Tab(_industry_tab(), label="Industry", tab_id="sector-industry"),
                dbc.Tab(_transport_tab(), label="Transport", tab_id="sector-transport"),
                dbc.Tab(_residential_tab(), label="Residential", tab_id="sector-residential"),
                dbc.Tab(_economy_tab(), label="Economy-wide", tab_id="sector-economy"),
            ]),
        ]),
    ]),
])


@app.callback(
    Output("fig-energy-product", "figure"),
    Output("fig-energy-sector", "figure"),
    Output("fig-gva-sector", "figure"),
    Output("fig-indexed", "figure"),
    Output("fig-waterfall", "figure"),
    Output("fig-intensity", "figure"),
    Output("fig-tra-energy-product", "figure"),
    Output("fig-tra-energy-mode", "figure"),
    Output("fig-tra-vkm-mode", "figure"),
    Output("fig-tra-indexed", "figure"),
    Output("fig-tra-waterfall", "figure"),
    Output("fig-tra-intensity", "figure"),
    Output("fig-res-fuel", "figure"),
    Output("fig-res-enduse", "figure"),
    Output("fig-res-indexed", "figure"),
    Output("fig-res-waterfall", "figure"),
    Output("fig-res-intensity", "figure"),
    Output("fig-eco-energy", "figure"),
    Output("fig-eco-employment", "figure"),
    Output("fig-eco-indexed", "figure"),
    Output("fig-eco-waterfall", "figure"),
    Output("fig-eco-intensity", "figure"),
    Output("status", "children"),
    Input("country", "value"),
    Input("year-range", "value"),
)
def update(country_code, year_range):
    first_year, last_year = year_range
    name = countries.name(country_code)
    nrg = data.load_dataset("nrg_bal_c", country_code)
    nama = data.load_dataset("nama_10_a64", country_code)
    road = data.load_dataset("road_tf_vehmov", country_code)
    rail = data.load_dataset("rail_tf_trainmv", country_code)
    iww = data.load_dataset("iww_tf_vetf", country_code)

    ind = industry.compute_industry(nrg, nama, first_year, last_year)
    tra = transport.compute_transport(nrg, road, rail, iww, first_year, last_year)
    res = residential.compute_residential(
        nrg, data.load_dataset("nrg_d_hhq", country_code),
        data.load_dataset("demo_gind", country_code),
        data.load_dataset("ilc_lvph01", country_code),
        data.load_dataset("nrg_chdd_a", country_code), first_year, last_year)
    eco = economy.compute_economy(
        nrg, data.load_dataset("nama_10_a10_e", country_code), first_year, last_year)

    ify, ily = int(ind["first_year_with_data"]), int(ind["last_year_with_data"])
    tfy, tly = int(tra["first_year_with_data"]), int(tra["last_year_with_data"])
    rfy = res["first_year_with_data"]
    rly = res["last_year_with_data"]
    efy, ely = int(eco["first_year_with_data"]), int(eco["last_year_with_data"])
    n_notes = (len(ind["notifications"]) + len(tra["notifications"])
               + len(res["notifications"]) + len(eco["notifications"]))
    status = [
        html.Div([html.I(className="fa-solid fa-industry me-1"),
                  f"Industry window: {ify}–{ily}"]),
        html.Div([html.I(className="fa-solid fa-train me-1"),
                  f"Transport window: {tfy}–{tly}"]),
        html.Div([html.I(className="fa-solid fa-house me-1"),
                  f"Residential window: {int(rfy)}–{int(rly)}"]) if rfy else None,
        html.Div([html.I(className="fa-solid fa-building me-1"),
                  f"Economy window: {efy}–{ely}"]),
        html.Div(f"{n_notes} data notice(s)", className="text-warning") if n_notes else None,
    ]
    res_indexed = res.get("indexed")
    return (
        charts.energy_by_product(ind["energy_by_product"], name),
        charts.energy_by_sector(ind["energy_by_sector"], name),
        charts.gva_by_sector(ind["gva_by_sector"], name),
        charts.indexed_indicators(ind["decomposition"], ify, name),
        charts.waterfall(ind["lmdi"], ify, ily, name),
        charts.intensity_effect(ind["lmdi"], name),
        charts.transport_energy_by_product(tra["energy_by_product"], name),
        charts.transport_energy_by_mode(tra["energy_by_mode"], name),
        charts.transport_vkm_by_mode(tra["vkm_by_mode"], name),
        charts.transport_indexed_indicators(tra["decomposition"], tfy, name),
        charts.waterfall(tra["lmdi"], tfy, tly, name),
        charts.intensity_effect(tra["lmdi"], name),
        charts.residential_energy_by_product(res["fuel"], name),
        charts.residential_energy_by_enduse(res["augmented"], name),
        charts.residential_indexed_indicators(res_indexed, int(rfy) if rfy else 0, name),
        charts.residential_waterfall(res["lmdi"], int(rfy) if rfy else 0,
                                     int(rly) if rly else 0, name),
        charts.residential_intensity_effect(res["lmdi"], name),
        charts.economy_energy_by_sector(eco["energy_by_sector"], name),
        charts.economy_employment_by_sector(eco["employment_by_sector"], name),
        charts.economy_indexed_indicators(eco["decomposition"], efy, name),
        charts.waterfall(eco["lmdi"], efy, ely, name),
        charts.intensity_effect(eco["lmdi"], name),
        status,
    )


if __name__ == "__main__":
    app.run(debug=True, port=8050)
