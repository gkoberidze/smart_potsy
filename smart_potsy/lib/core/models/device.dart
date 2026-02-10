class Device {
  final String deviceId;
  final DeviceTelemetry? lastTelemetry;
  final String? status;
  final DateTime? statusReportedAt;

  Device({
    required this.deviceId,
    this.lastTelemetry,
    this.status,
    this.statusReportedAt,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      deviceId: json['deviceId'] ?? json['device_id'] ?? '',
      lastTelemetry:
          json['lastTelemetry'] != null
              ? DeviceTelemetry.fromJson(json['lastTelemetry'])
              : null,
      status: json['status'],
      statusReportedAt:
          json['statusReportedAt'] != null
              ? DateTime.parse(json['statusReportedAt'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'lastTelemetry': lastTelemetry?.toJson(),
      'status': status,
      'statusReportedAt': statusReportedAt?.toIso8601String(),
    };
  }
}

class DeviceTelemetry {
  final double? airTemperature;
  final double? airHumidity;
  final double? soilTemperature;
  final double? soilMoisture;
  final double? lightLevel;
  final DateTime? recordedAt;

  DeviceTelemetry({
    this.airTemperature,
    this.airHumidity,
    this.soilTemperature,
    this.soilMoisture,
    this.lightLevel,
    this.recordedAt,
  });

  factory DeviceTelemetry.fromJson(Map<String, dynamic> json) {
    return DeviceTelemetry(
      airTemperature: _toDouble(json['airTemperature']),
      airHumidity: _toDouble(json['airHumidity']),
      soilTemperature: _toDouble(json['soilTemperature']),
      soilMoisture: _toDouble(json['soilMoisture']),
      lightLevel: _toDouble(json['lightLevel']),
      recordedAt:
          json['recordedAt'] != null
              ? DateTime.parse(json['recordedAt'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'airTemperature': airTemperature,
      'airHumidity': airHumidity,
      'soilTemperature': soilTemperature,
      'soilMoisture': soilMoisture,
      'lightLevel': lightLevel,
      'recordedAt': recordedAt?.toIso8601String(),
    };
  }
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
