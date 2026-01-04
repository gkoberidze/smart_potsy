class ApiConstants {
  // Base URL - change this for production
  static const String baseUrl = 'http://localhost:3000';

  // For Android emulator use: 'http://10.0.2.2:3000'
  // For iOS simulator use: 'http://localhost:3000'
  // For physical device use your computer's IP: 'http://192.168.x.x:3000'

  // Auth endpoints
  static const String register = '/api/auth/register';
  static const String login = '/api/auth/login';
  static const String oauth = '/api/auth/oauth';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String resetPassword = '/api/auth/reset-password';
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
