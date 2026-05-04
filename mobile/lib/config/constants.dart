/// Global configuration for the ARVision Gold app.
///
/// 🔧 Before running, replace [flaskBaseUrl] with your laptop's LAN IP.
///    Example:  'http://192.168.1.105:5000'
///    Find your IP with `ipconfig` (Windows) or `ifconfig` (macOS/Linux).
class AppConstants {
  AppConstants._();

  // ── Flask API ──────────────────────────────────────────────────────────────
  static const String flaskBaseUrl = 'http://192.168.1.100:5000';

  static const String predictEndpoint   = '$flaskBaseUrl/predict';
  static const String livePriceEndpoint = '$flaskBaseUrl/live_price';

  // ── Polling ────────────────────────────────────────────────────────────────
  static const Duration pricePollInterval = Duration(seconds: 30);
  static const Duration requestTimeout    = Duration(seconds: 30);

  // ── Colours (also defined in theme, repeated here for use in painters) ─────
  static const int colorGold    = 0xFFF0B90B;
  static const int colorGreen   = 0xFF00E676;
  static const int colorRed     = 0xFFFF1744;
  static const int colorNeutral = 0xFF90A4AE;
  static const int colorBg      = 0xFF080B0F;
}
