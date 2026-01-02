class Telemetry {
  final int id;
  final String deviceId;
  final double? airTemperature;
  final double? airHumidity;
  final double? soilTemperature;
  final double? soilMoisture;
  final int? lightLevel;
  final DateTime recordedAt;

  Telemetry({
    required this.id,
    required this.deviceId,
    this.airTemperature,
    this.airHumidity,
    this.soilTemperature,
    this.soilMoisture,
    this.lightLevel,
    required this.recordedAt,
  });

  factory Telemetry.fromJson(Map<String, dynamic> json) {
    return Telemetry(
      id: json['id'],
      deviceId: json['device_id'],
      airTemperature: json['air_temp']?.toDouble(),
      airHumidity: json['air_humidity']?.toDouble(),
      soilTemperature: json['soil_temp']?.toDouble(),
      soilMoisture: json['soil_moisture']?.toDouble(),
      lightLevel: json['light_level'],
      recordedAt: DateTime.parse(json['recorded_at']),
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
      'recorded_at': recordedAt.toIso8601String(),
    };
  }
}
