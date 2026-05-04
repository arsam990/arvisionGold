from flask import Flask, request, jsonify, render_template
from flask_cors import CORS
import cv2
import numpy as np
import pandas as pd
import yfinance as yf
import joblib
import os
import xgboost as xgb

app = Flask(__name__)
CORS(app)

# --- CONFIGURATION ---
MODEL_PATH = "artifacts/gold_price_predictor_v2.joblib"

# Load Model Safely
if os.path.exists(MODEL_PATH):
    try:
        model = joblib.load(MODEL_PATH)
        print(f"✅ SUCCESS: XGBoost Model Loaded from {MODEL_PATH}")
    except Exception as e:
        print(f"❌ MODEL ERROR: {e}")
        model = None
else:
    print(f"⚠️ WARNING: Model file not found at {MODEL_PATH}")
    model = None

# --- INDICATOR FUNCTIONS ---
def calculate_rsi(series, period=14):
    delta = series.diff(1)
    gain = delta.where(delta > 0, 0)
    loss = -delta.where(delta < 0, 0)
    avg_gain = gain.ewm(alpha=1/period, adjust=False).mean()
    avg_loss = loss.ewm(alpha=1/period, adjust=False).mean()
    rs = avg_gain / avg_loss
    return 100 - (100 / (1 + rs))

# --- ROUTES ---
@app.route('/')
def home():
    # Serve the UI
    return render_template('index.html')

@app.route('/predict', methods=['POST'])
def predict():
    if 'file' not in request.files:
        return jsonify({"error": "No image uploaded"}), 400

    file = request.files['file']

    # ==========================================
    # MODULE 1: COMPUTER VISION (OpenCV)
    # ==========================================
    try:
        img_bytes = np.frombuffer(file.read(), np.uint8)
        img = cv2.imdecode(img_bytes, cv2.IMREAD_COLOR)
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)

        # Masking for Green & Red
        mask_green = cv2.inRange(hsv, (35, 40, 40), (85, 255, 255))
        mask_red = cv2.inRange(hsv, (0, 40, 40), (10, 255, 255))
        
        green_pixels = cv2.countNonZero(mask_green)
        red_pixels = cv2.countNonZero(mask_red)

        if green_pixels > red_pixels:
            chart_candle = "GREEN"
            vision_signal = "BULLISH"
        else:
            chart_candle = "RED"
            vision_signal = "BEARISH"
            
    except Exception as e:
        return jsonify({"error": f"Vision Error: {str(e)}"}), 500

    # ==========================================
    # MODULE 2: AI PREDICTION (XGBoost)
    # ==========================================
    current_price = 0.0
    ai_trend = "NEUTRAL"
    
    try:
        # Fetch Live Data
        df = yf.download("GC=F", period="6mo", interval="1d", progress=False)
        if isinstance(df.columns, pd.MultiIndex):
            df.columns = df.columns.get_level_values(0)

        close = df['Close']
        df['RSI'] = calculate_rsi(close, 14)
        df['SMA_50'] = close.rolling(window=50).mean()
        df['EMA_20'] = close.ewm(span=20, adjust=False).mean()
        
        k = close.ewm(span=12, adjust=False).mean()
        d = close.ewm(span=26, adjust=False).mean()
        df['MACD'] = k - d
        df['MACD_SIGNAL'] = df['MACD'].ewm(span=9, adjust=False).mean()
        
        ma = close.rolling(window=20).mean()
        std = close.rolling(window=20).std()
        df['BB_UPPER'] = ma + (2 * std)
        df['BB_LOWER'] = ma - (2 * std)
        
        for i in range(1, 6):
            df[f'Return_Lag_{i}'] = df['Close'].pct_change(i)

        features = ['RSI', 'SMA_50', 'EMA_20', 'MACD', 'MACD_SIGNAL', 
                    'BB_UPPER', 'BB_LOWER', 'Return_Lag_1', 'Return_Lag_2', 
                    'Return_Lag_3', 'Return_Lag_4', 'Return_Lag_5']
        
        latest_data = df.iloc[-1:][features]
        current_price = round(float(df['Close'].iloc[-1]), 2)
        
        if model:
            prediction = model.predict(latest_data)[0]
            ai_trend = "UP" if prediction == 1 else "DOWN"
        else:
            ai_trend = "NO_MODEL"

    except Exception as e:
        print(f"AI Error: {e}")
        ai_trend = "ERROR"

    # ==========================================
    # MODULE 3: FINAL FUSION LOGIC
    # ==========================================
    if ai_trend == "UP" and vision_signal == "BULLISH":
        signal, reason = "BUY", "STRONG BUY: AI forecasts Uptrend & Chart is Bullish."
    elif ai_trend == "DOWN" and vision_signal == "BEARISH":
        signal, reason = "SELL", "STRONG SELL: AI forecasts Downtrend & Chart is Bearish."
    elif ai_trend == "UP" and vision_signal == "BEARISH":
        signal, reason = "WAIT", "RISKY: AI predicts UP, but immediate candle is RED."
    elif ai_trend == "DOWN" and vision_signal == "BULLISH":
        signal, reason = "WAIT", "RISKY: AI predicts DOWN, but immediate candle is GREEN."
    else:
        signal, reason = "WAIT", "System Uncertainty."

    return jsonify({
        "price": current_price,
        "chart_candle": chart_candle,
        "ai_trend": f"{ai_trend}",
        "signal": signal,
        "reason": reason
    })

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)