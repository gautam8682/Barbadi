
# Reads ONE couple's details as JSON from standard input,
# prints the predicted marriage duration as JSON.

suppressPackageStartupMessages(library(jsonlite))

result <- tryCatch({

  # ---- 1. Read the JSON that Flask sends ----
  raw_json <- paste(readLines(file("stdin"), warn = FALSE), collapse = "")
  input    <- fromJSON(raw_json)

  # ---- 2. Load the model saved by 03_train.R ----
  model <- readRDS("models/cluster_model.rds")

  # ---- 3. Check that every needed feature was provided ----
  missing <- setdiff(model$features, names(input))
  if (length(missing) > 0) {
    stop(paste("Missing inputs:", paste(missing, collapse = ", ")))
  }

  # ---- 4. Build a 1-row matrix in the SAME column order as training ----
  values <- as.numeric(unlist(input[model$features]))
  new_x  <- matrix(values, nrow = 1, dimnames = list(NULL, model$features))

  # ---- 5. Scale with the TRAINING means and sds ----
  scaled <- scale(new_x, center = model$feature_means, scale = model$feature_sds)

  # ---- 6. Find the nearest cluster centre ----
  distances <- colSums((t(model$centers) - as.numeric(scaled))^2)
  cluster   <- which.min(distances)

  # ---- 7. Look up that cluster's average duration ----
  cd       <- model$cluster_durations
  duration <- cd$avg_duration[cd$cluster == cluster]

  list(
    success            = TRUE,
    cluster            = cluster,
    predicted_duration = round(duration, 1),
    cluster_size       = cd$n[cd$cluster == cluster]
  )

}, error = function(e) {
  list(success = FALSE, error = conditionMessage(e))
})

# ---- 8. Print the result as JSON (Flask reads this) ----
cat(toJSON(result, auto_unbox = TRUE))