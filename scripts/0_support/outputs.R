library(futile.logger)

source("scripts/0_support/folders_management.R")

print_chart <- function(p,
                        filename,
                        output_path,
                        width,
                        height,
                        res) {
  flog.info(paste("Save the chart", filename))
  create_folder_if_not_exists(output_path)
  jpeg(
    file = paste0(output_path, filename),
    width = width,
    height = height,
    res = res
  )
  print(p)
  dev.off()
}

save_data <- function(data,
                      filename,
                      output_path) {
  flog.info(paste("Save the data", filename))
  create_folder_if_not_exists(output_path)
  write.csv(
    data,
    paste0(output_path, filename),
    row.names = FALSE
  )
}