# app.py
# Flask backend: receives couple details, calls the R model, returns the prediction.

import json
import os
import subprocess
from pathlib import Path

from flask import Flask, jsonify, render_template, request

# Project root = the folder above "App/"
BASE_DIR = Path(__file__).resolve().parent.parent

# Use the local Windows Rscript path on your PC.
# On Render/Linux, use the Rscript executable installed by Docker.
if os.name == "nt":
    RSCRIPT = os.environ.get(
        "RSCRIPT",
        r"C:\Program Files\R\R-4.6.1\bin\Rscript.exe"
    )
else:
    RSCRIPT = os.environ.get("RSCRIPT", "Rscript")

app = Flask(__name__)

# Every input the model needs, with the allowed (min, max) range
FIELDS = {
    "person1_age": (21, 50),
    "person2_age": (21, 50),
    "relationship_years_before_marriage": (0, 10),
    "person1_monthly_income": (0, 1500000),
    "person2_monthly_income": (0, 1500000),
    "financial_stability_score": (1, 10),
    "communication_score": (1, 10),
    "conflict_frequency_per_month": (0, 15),
    "children_count": (0, 10),
    "compatibility_score": (1, 10),
}


def validate(data):
    """Check the input. Returns (cleaned_data, error_message)."""
    cleaned = {}

    for name, (low, high) in FIELDS.items():
        if name not in data:
            return None, f"Missing field: {name}"

        try:
            value = float(data[name])
        except (TypeError, ValueError):
            return None, f"{name} must be a number"

        if not (low <= value <= high):
            return None, f"{name} must be between {low} and {high}"

        cleaned[name] = value

    return cleaned, None


@app.route("/")
def home():
    return render_template("index.html", fields=FIELDS)


@app.route("/predict", methods=["POST"])
def predict():
    data = request.get_json(silent=True)

    if data is None:
        return jsonify(success=False, error="Send JSON data"), 400

    cleaned, error = validate(data)

    if error:
        return jsonify(success=False, error=error), 400

    # Call the R script, sending the JSON through stdin.
    try:
        proc = subprocess.run(
            [RSCRIPT, "R/predict.R"],
            input=json.dumps(cleaned),
            capture_output=True,
            text=True,
            cwd=BASE_DIR,
            timeout=30,
        )
    except FileNotFoundError:
        return jsonify(
            success=False,
            error=f"Rscript not found: {RSCRIPT}"
        ), 500
    except subprocess.TimeoutExpired:
        return jsonify(
            success=False,
            error="The R model took too long"
        ), 500

    # If R exited with an error, return its stderr so deployment
    # problems are easier to diagnose.
    if proc.returncode != 0:
        print("R stderr:", proc.stderr)
        return jsonify(
            success=False,
            error="R model failed to run"
        ), 500

    # Read the JSON that R printed.
    try:
        result = json.loads(proc.stdout)
    except json.JSONDecodeError:
        print("R stdout:", proc.stdout)
        print("R stderr:", proc.stderr)
        return jsonify(
            success=False,
            error="R returned an unreadable result"
        ), 500

    status = 200 if result.get("success") else 500
    return jsonify(result), status


if __name__ == "__main__":
    # Local development + fallback if you run app.py directly.
    # Render uses Gunicorn from the Dockerfile.
    app.run(
        host="0.0.0.0",
        port=int(os.environ.get("PORT", 10000)),
        debug=False
    )
