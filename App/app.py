# app.py
# Flask backend: receives couple details, calls the R model, returns the prediction.

import json
import subprocess
from pathlib import Path

from flask import Flask, jsonify, render_template, request

# Project root = the folder above "app/"
BASE_DIR = Path(__file__).resolve().parent.parent

# If Windows can't find Rscript, put the full path here, e.g.
# RSCRIPT = r"C:\Program Files\R\R-4.4.1\bin\Rscript.exe"
RSCRIPT = r"C:\Program Files\R\R-4.6.1\bin\Rscript.exe"

app = Flask(__name__)

# Every input the model needs, with the allowed (min, max) range
FIELDS = {
    "person1_age": (21, 40),
    "person2_age": (21, 40),
    "relationship_years_before_marriage": (0, 8),
    "person1_monthly_income": (10000, 150000),
    "person2_monthly_income": (10000, 150000),
    "financial_stability_score": (1, 10),
    "communication_score": (1, 10),
    "conflict_frequency_per_month": (0, 15),
    "children_count": (0, 4),
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

    # Call the R script, sending the JSON through stdin
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
        return jsonify(success=False, error="Rscript not found. Check RSCRIPT in app.py"), 500
    except subprocess.TimeoutExpired:
        return jsonify(success=False, error="The R model took too long"), 500

    # Read the JSON that R printed
    try:
        result = json.loads(proc.stdout)
    except json.JSONDecodeError:
        print("R stderr:", proc.stderr)   # shows in your terminal for debugging
        return jsonify(success=False, error="R returned an unreadable result"), 500

    status = 200 if result.get("success") else 500
    return jsonify(result), status


if __name__ == "__main__":
    app.run(debug=True)