FROM python:3.12-slim

# Install R and the R package used by R/predict.R.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       r-base \
       r-cran-jsonlite \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

ENV PORT=10000
ENV PYTHONUNBUFFERED=1

EXPOSE 10000

CMD ["gunicorn", "--bind", "0.0.0.0:10000", "App.app:app"]
