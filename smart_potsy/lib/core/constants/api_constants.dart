import 'package:shared_preferences/shared_preferences.dart';

class ApiConstants {
  // ===========================================
  // BASE URL CONFIGURATION
  // ===========================================
  // 🔧 DEVELOPMENT: Use one of these:
  //    - Web/Desktop: 'http://localhost:3000'
  //    - Android Emulator: 'http://10.0.2.2:3000'
  //    - Physical Device: 'http://YOUR_PC_IP:3000'
  //
  // Use the app settings to change the backend URL for your phone.
  // ===========================================

  static const String defaultBaseUrl = 'http://localhost:3000';
  static const String _baseUrlPrefsKey = 'api_base_url';

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlPrefsKey) ?? defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlPrefsKey, url);
  }

  static Future<void> resetBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_baseUrlPrefsKey);
  }

  // Auth endpoints
  static const String register = '/api/auth/register';
  static const String login = '/api/auth/login';
  static const String oauth = '/api/auth/oauth';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String resetPassword = '/api/auth/reset-password';
  static const String changePassword = '/api/auth/change-password';
  static const String me = '/api/auth/me';

  // Device endpoints
  static const String devices = '/api/devices';
  static String deviceTelemetry(String deviceId) =>
      '/api/devices/$deviceId/telemetry';
  static String deviceStatus(String deviceId) =>
      '/api/devices/$deviceId/status';
  static String deleteDevice(String deviceId) => '/api/devices/$deviceId';
}
