"""
ARVision Gold – Flask Dashboard
Run: python app.py
"""

import os
import io
import cv2
import json
import yaml
import joblib
import base64
import numpy as np
import pandas as pd
import yfinance as yf

from flask import Flask, render_template, request, jsonify

# ── paths ────────────────────────────────────────────────────────────────────
BASE = os.path.dirname(os.path.abspath(__file__))

def _load_yaml(path):
    if os.path.exists(path):
        with open(path) as f:
            return yaml.safe_load(f)
    return {}

PATHS  = _load_yaml(os.path.join(BASE, "paths.yaml"))
MCFG   = _load_yaml(os.path.join(BASE, "model.yaml"))
SIG    = _load_yaml(os.path.join(BASE, "signals.yaml"))

MODEL_PATH = (PATHS.get("artifacts", {}).get("model_rf")
              or os.path.join(BASE, "gold_price_predictor_v2.joblib"))

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 16 * 1024 * 1024   # 16 MB upload limit

# ── helpers ───────────────────────────────────────────────────────────────────

def get_ai_prediction():
    """Return (trend_label, current_price)."""
    try:
        df = yf.download("GC=F", period="2y", interval="1d", progress=False)
        if df.empty:
            return "NO DATA", 0.0

        if isinstance(df.columns, pd.MultiIndex):
            df.columns = df.columns.get_level_values(0)

        close = df["Close"]
        delta = close.diff()
        gain  = delta.where(delta > 0, 0).rolling(14).mean()
        loss  = (-delta.where(delta < 0, 0)).rolling(14).mean()
        df["RSI"]    = 100 - (100 / (1 + gain / loss))
        df["SMA_50"] = close.rolling(50).mean()
        df["EMA_20"] = close.ewm(span=20, adjust=False).mean()
        df.dropna(inplace=True)

        if df.empty:
            return "NOT ENOUGH DATA", 0.0

        last_row      = df.iloc[[-1]].copy()
        current_price = float(last_row["Close"].values[0])

        if os.path.exists(MODEL_PATH):
            rf       = joblib.load(MODEL_PATH)
            features = getattr(rf, "feature_names_in_",
                                MCFG.get("features", {}).get("include", []))
            for feat in features:
                if feat not in last_row.columns:
                    last_row[feat] = 0
            pred = rf.predict(last_row[features])[0]
            return ("UP" if pred == 1 else "DOWN"), current_price
        else:
            return "MODEL MISSING", current_price
    except Exception:
        return "ERROR", 0.0


def analyze_image(img_bytes: bytes) -> str:
    """Return GREEN / RED / NEUTRAL based on dominant candle colour."""
    arr = np.frombuffer(img_bytes, np.uint8)
    img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if img is None:
        return "BAD IMAGE"

    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    g   = cv2.countNonZero(cv2.inRange(hsv, (40, 40, 40),   (80, 255, 255)))
    r   = cv2.countNonZero(
        cv2.inRange(hsv, (0,   50, 50),  (10, 255, 255)) +
        cv2.inRange(hsv, (170, 50, 50),  (180, 255, 255))
    )
    if g > r:
        return "GREEN"
    if r > g:
        return "RED"
    return "NEUTRAL"


def fuse_signal(trend: str, candle: str) -> tuple[str, str]:
    """Return (signal_text, severity): BUY / SELL / HOLD."""
    if "UP" in trend and candle == "GREEN":
        return "STRONG BUY",  "buy"
    if "DOWN" in trend and candle == "RED":
        return "STRONG SELL", "sell"
    return "HOLD / WAIT", "neutral"


# ── routes ────────────────────────────────────────────────────────────────────

@app.route("/")
def index():
    return render_template("index.html")


@app.route("/predict", methods=["POST"])
def predict():
    file = request.files.get("file")
    if not file:
        return jsonify({"error": "No file uploaded"}), 400

    img_bytes = file.read()
    candle    = analyze_image(img_bytes)
    trend, price = get_ai_prediction()
    signal, severity = fuse_signal(trend, candle)

    # encode thumbnail for preview
    thumb_b64 = base64.b64encode(img_bytes).decode()

    reason_map = {
        "buy":     "STRONG BUY: AI forecasts Uptrend & Chart is Bullish.",
        "sell":    "STRONG SELL: AI forecasts Downtrend & Chart is Bearish.",
        "neutral": "Signals are conflicting. Stand by.",
    }

    return jsonify({
        "price":       round(price, 2),
        "chart_candle": candle,
        "ai_trend":    trend,
        "signal":      signal,
        "severity":    severity,
        "reason":      reason_map[severity],
        "thumb":       f"data:image/jpeg;base64,{thumb_b64}",
    })


@app.route("/live_price")
def live_price():
    """Lightweight endpoint polled every 30 s for ticker bar."""
    try:
        df = yf.download("GC=F", period="2d", interval="1m", progress=False)
        if df.empty:
            raise ValueError("empty")
        if isinstance(df.columns, pd.MultiIndex):
            df.columns = df.columns.get_level_values(0)
        last  = float(df["Close"].iloc[-1])
        prev  = float(df["Close"].iloc[-2])
        delta = round(last - prev, 2)
        pct   = round((delta / prev) * 100, 3)
        return jsonify({"price": round(last, 2), "delta": delta, "pct": pct})
    except Exception:
        return jsonify({"price": None, "delta": 0, "pct": 0})


if __name__ == "__main__":
    # Set FLASK_DEBUG=1 in your environment to enable debug mode.
    debug = os.environ.get("FLASK_DEBUG", "0") == "1"
    app.run(host="0.0.0.0", port=5000, debug=debug)
