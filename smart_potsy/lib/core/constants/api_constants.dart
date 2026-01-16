class ApiConstants {
  // ===========================================
  // BASE URL CONFIGURATION
  // ===========================================
  // 🔧 DEVELOPMENT: Use one of these:
  //    - Web/Desktop: 'http://localhost:3000'
  //    - Android Emulator: 'http://10.0.2.2:3000'
  //    - iOS Simulator: 'http://localhost:3000'
  //    - Physical Device: 'http://YOUR_PC_IP:3000'
  //
  // 🚀 PRODUCTION: Change to your server domain:
  //    - 'https://yourdomain.com'
  // ===========================================

  // static const String baseUrl = 'http://localhost:3000'; // Chrome/Web (Development)
  static const String baseUrl =
      'http://161.35.219.50'; // Production Server (nginx on port 80)
  // static const String baseUrl = 'https://yourdomain.com'; // PRODUCTION (if you have SSL/domain)

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

  // Notification endpoints
  static const String notifications = '/api/notifications';
  static const String registerFCMToken = '/api/notifications/register-token';
}
