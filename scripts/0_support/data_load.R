# Load data

load_eurostat_data <- function(data_path, nrg_bal_c) {

  # Energy consumption (and supply) from the energy balance (nrg_bal_c)
  load(paste(data_path, "nrg_bal_c.Rda", sep = ""))

  # Economic activity from the national account data (nama_10_a64)
  load(paste(data_path, "nama_10_a64.Rda", sep = ""))

  # Employment data from the national account (nama_10_a10_e)
  load(paste(data_path, "nama_10_a10_e.Rda", sep = ""))

  # Disaggregated final energy consumption in households (nrg_d_hhq)
  load(paste(data_path, "nrg_d_hhq.Rda", sep = ""))

  # Cooling and heating degree days (nrg_chdd_a)
  load(paste(data_path, "nrg_chdd_a.Rda", sep = ""))

  # Population from the demographic balance (demo_gind)
  load(paste(data_path, "demo_gind.Rda", sep = ""))

  # Average household size from the EU-SILC survey (ilc_lvph01)
  load(paste(data_path, "ilc_lvph01.Rda", sep = ""))

  # Vehicle kilometer from road transport data (road_tf_vehmov)
  load(paste(data_path, "road_tf_vehmov.Rda", sep = ""))

  # Vehicle kilometer from rail transport data (rail_tf_trainmv)
  load(paste(data_path, "rail_tf_trainmv.Rda", sep = ""))

  # Vehicle kilometer from water transport data (iww_tf_vetf)
  load(paste(data_path, "iww_tf_vetf.Rda", sep = ""))

}