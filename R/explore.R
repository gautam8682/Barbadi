
# Load the dataset and look at its structure. No modelling yet.

library(readr)
library(dplyr)

# 1. Load the data (change the file name to yours)
data <- read_csv("data/marriage.csv")

# 2. How big is it?
cat("Rows and columns:\n")
print(dim(data))

# 3. Column names and their types
cat("\nColumn names and types:\n")
glimpse(data)

# 4. First 5 rows
cat("\nFirst 5 rows:\n")
print(head(data, 5))

# 5. Missing values per column
cat("\nMissing values per column:\n")
print(colSums(is.na(data)))

# 6. Statistical summary of every column
cat("\nSummary:\n")
print(summary(data))