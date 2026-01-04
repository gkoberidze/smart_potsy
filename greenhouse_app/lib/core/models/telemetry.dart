class Telemetry {
  final int? id;
  final String? deviceId;
  final double? airTemperature;
  final double? airHumidity;
  final double? soilTemperature;
  final double? soilMoisture;
  final double? lightLevel;
  final DateTime? recordedAt;

  Telemetry({
    this.id,
    this.deviceId,
    this.airTemperature,
    this.airHumidity,
    this.soilTemperature,
    this.soilMoisture,
    this.lightLevel,
    this.recordedAt,
  });

  factory Telemetry.fromJson(Map<String, dynamic> json) {
    return Telemetry(
      id: json['id'],
      deviceId: json['device_id'] ?? json['deviceId'],
      airTemperature: (json['air_temp'] ?? json['airTemperature'])?.toDouble(),
      airHumidity: (json['air_humidity'] ?? json['airHumidity'])?.toDouble(),
      soilTemperature:
          (json['soil_temp'] ?? json['soilTemperature'])?.toDouble(),
      soilMoisture: (json['soil_moisture'] ?? json['soilMoisture'])?.toDouble(),
      lightLevel: (json['light_level'] ?? json['lightLevel'])?.toDouble(),
      recordedAt:
          json['recorded_at'] != null
              ? DateTime.parse(json['recorded_at'])
              : json['recordedAt'] != null
              ? DateTime.parse(json['recordedAt'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'air_temp': airTemperature,
      'air_humidity': airHumidity,
      'soil_temp': soilTemperature,
      'soil_moisture': soilMoisture,
      'light_level': lightLevel,
      'recorded_at': recordedAt?.toIso8601String(),
    };
  }
}
