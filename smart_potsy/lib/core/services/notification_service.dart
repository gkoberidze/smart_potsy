import '../constants/api_constants.dart';
import 'api_service.dart';

class NotificationService {
  final ApiService _apiService;

  NotificationService(this._apiService);

  // Enable/disable alerts for a device
  Future<bool> setDeviceAlerts(
    String deviceId,
    Map<String, dynamic> rules,
  ) async {
    try {
      final response = await _apiService.post(
        '${ApiConstants.devices}/$deviceId/alert-rules',
        rules,
      );
      return response.success;
    } catch (e) {
      print('❌ Failed to set alert rules: $e');
      return false;
    }
  }

  // Get alert rules for a device
  Future<Map<String, dynamic>?> getDeviceAlertRules(String deviceId) async {
    try {
      final response = await _apiService.get(
        '${ApiConstants.devices}/$deviceId/alert-rules',
      );
      if (response.success && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      print('❌ Failed to fetch alert rules: $e');
    }
    return null;
  }
}
