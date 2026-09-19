
# Cluster couples (unsupervised), then use each cluster's average
# marriage duration as the prediction.

library(readr)
library(dplyr)
library(cluster)

set.seed(42)   # makes random steps repeatable

# ---- 1. Load data ----
data <- read_csv("data/marriage.csv", show_col_types = FALSE)

target   <- "marriage_duration_years"
features <- setdiff(names(data), c("couple_id", "age_difference",
    "education_level", "family_support_score", "marriage_type", target))

# ---- 2. Train/test split (80/20) ----
n         <- nrow(data)
train_idx <- sample(seq_len(n), size = 0.8 * n)
train     <- data[train_idx, ]
test      <- data[-train_idx, ]

# ---- 3. Scale features using TRAIN statistics only ----
train_x       <- as.matrix(train[, features])
feature_means <- colMeans(train_x)
feature_sds   <- apply(train_x, 2, sd)
train_scaled  <- scale(train_x, center = feature_means, scale = feature_sds)

# ---- 4. Choose number of clusters (k) with silhouette score ----
dist_matrix <- dist(train_scaled)
results <- data.frame(k = 2:8, silhouette = NA)

for (i in seq_len(nrow(results))) {
  km  <- kmeans(train_scaled, centers = results$k[i], nstart = 25)
  sil <- silhouette(km$cluster, dist_matrix)
  results$silhouette[i] <- mean(sil[, "sil_width"])
}
print(results)

best_k <- results$k[which.max(results$silhouette)]
cat("\nBest k:", best_k, "\n")

# ---- 5. Final clustering ----
final_km <- kmeans(train_scaled, centers = best_k, nstart = 25)
train$cluster <- final_km$cluster

# ---- 6. Average duration per cluster ----
cluster_durations <- train %>%
  group_by(cluster) %>%
  summarise(avg_duration = mean(marriage_duration_years), n = n())
print(cluster_durations)

# ---- 7. Function: assign new rows to the nearest cluster centre ----
assign_cluster <- function(new_x, centers) {
  apply(new_x, 1, function(row) {
    which.min(colSums((t(centers) - row)^2))
  })
}

# ---- 8. Evaluate on the test set ----
test_scaled  <- scale(as.matrix(test[, features]),
                      center = feature_means, scale = feature_sds)
test_cluster <- assign_cluster(test_scaled, final_km$centers)
predicted    <- cluster_durations$avg_duration[
                  match(test_cluster, cluster_durations$cluster)]
actual       <- test[[target]]

rmse          <- sqrt(mean((actual - predicted)^2))
baseline_rmse <- sqrt(mean((actual - mean(train[[target]]))^2))

cat("\nCluster model RMSE:", round(rmse, 2), "years\n")
cat("Baseline RMSE (always guess the mean):", round(baseline_rmse, 2), "years\n")

# ---- 9. Save everything the prediction script will need ----
dir.create("models", showWarnings = FALSE)
model <- list(
  features          = features,
  feature_means     = feature_means,
  feature_sds       = feature_sds,
  centers           = final_km$centers,
  cluster_durations = cluster_durations
)
saveRDS(model, "models/cluster_model.rds")
cat("Model saved to models/cluster_model.rds\n")