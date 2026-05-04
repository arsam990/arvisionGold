/// Typed model for the `/predict` API response.
///
/// Example JSON:
/// ```json
/// {
///   "price": 2345.60,
///   "chart_candle": "GREEN",
///   "ai_trend": "UP",
///   "signal": "STRONG BUY",
///   "severity": "buy",
///   "reason": "STRONG BUY: AI forecasts Uptrend & Chart is Bullish."
/// }
/// ```
class PredictionModel {
  final double price;
  final String chartCandle;
  final String aiTrend;
  final String signal;

  /// One of: 'buy' | 'sell' | 'neutral'
  final String severity;
  final String reason;

  const PredictionModel({
    required this.price,
    required this.chartCandle,
    required this.aiTrend,
    required this.signal,
    required this.severity,
    required this.reason,
  });

  factory PredictionModel.fromJson(Map<String, dynamic> json) {
    return PredictionModel(
      price:       (json['price']        as num?)?.toDouble() ?? 0.0,
      chartCandle:  json['chart_candle'] as String? ?? '—',
      aiTrend:      json['ai_trend']     as String? ?? '—',
      signal:       json['signal']       as String? ?? '—',
      severity:     json['severity']     as String? ?? 'neutral',
      reason:       json['reason']       as String? ?? '',
    );
  }
}

/// Typed model for the `/live_price` API response.
class LivePriceModel {
  final double? price;
  final double delta;
  final double pct;

  const LivePriceModel({this.price, this.delta = 0, this.pct = 0});

  factory LivePriceModel.fromJson(Map<String, dynamic> json) {
    return LivePriceModel(
      price: (json['price'] as num?)?.toDouble(),
      delta: (json['delta'] as num?)?.toDouble() ?? 0,
      pct:   (json['pct']   as num?)?.toDouble() ?? 0,
    );
  }
}
