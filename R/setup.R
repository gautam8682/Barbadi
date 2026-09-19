# Run this ONCE to install the packages the project needs.


packages <- c(
  "dplyr",     # data manipulation (filter, select, mutate)
  "readr",     # reading CSV files quickly
  "cluster",   # clustering algorithms and silhouette scores
  "factoextra",# plots to help choose the number of clusters
  "jsonlite"   # converting R objects to/from JSON (for Flask to talk to R)
)

# Find which packages are NOT installed yet
missing <- packages[!(packages %in% installed.packages()[, "Package"])]

# Install only the missing ones
if (length(missing) > 0) {
  install.packages(missing)
}

# Load each package to confirm it works
for (p in packages) {
  library(p, character.only = TRUE)
}

cat("All packages ready.\n")