class Device {
  final int id;
  final String deviceId;
  final int userId;
  final DateTime createdAt;

  Device({
    required this.id,
    required this.deviceId,
    required this.userId,
    required this.createdAt,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'],
      deviceId: json['device_id'],
      userId: json['user_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
