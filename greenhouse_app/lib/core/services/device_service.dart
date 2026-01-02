import '../constants/api_constants.dart';
import '../models/device.dart';
import '../models/telemetry.dart';
import 'api_service.dart';

class DeviceService {
  final ApiService _apiService;

  DeviceService(this._apiService);

  Future<List<Device>> getDevices() async {
    final response = await _apiService.get(ApiConstants.devices);
    if (response.success && response.data != null) {
      final List<dynamic> devicesJson = response.data;
      return devicesJson.map((json) => Device.fromJson(json)).toList();
    }
    return [];
  }

  Future<Device?> registerDevice(String deviceId) async {
    final response = await _apiService.post(ApiConstants.devices, {
      'deviceId': deviceId,
    });
    if (response.success && response.data != null) {
      return Device.fromJson(response.data);
    }
    return null;
  }

  Future<bool> removeDevice(String deviceId) async {
    final response = await _apiService.delete(
      ApiConstants.deleteDevice(deviceId),
    );
    return response.success;
  }

  Future<List<Telemetry>> getDeviceTelemetry(
    String deviceId, {
    int limit = 100,
  }) async {
    final response = await _apiService.get(
      '${ApiConstants.deviceTelemetry(deviceId)}?limit=$limit',
    );
    if (response.success && response.data != null) {
      final List<dynamic> telemetryJson = response.data;
      return telemetryJson.map((json) => Telemetry.fromJson(json)).toList();
    }
    return [];
  }

  Future<DeviceStatus?> getDeviceStatus(String deviceId) async {
    final response = await _apiService.get(ApiConstants.deviceStatus(deviceId));
    if (response.success && response.data != null) {
      return DeviceStatus.fromJson(response.data);
    }
    return null;
  }
}

class DeviceStatus {
  final bool online;
  final DateTime? lastSeen;
  final Telemetry? latestTelemetry;

  DeviceStatus({required this.online, this.lastSeen, this.latestTelemetry});

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      online: json['online'] ?? false,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'])
          : null,
      latestTelemetry: json['latestTelemetry'] != null
          ? Telemetry.fromJson(json['latestTelemetry'])
          : null,
    );
  }
}
