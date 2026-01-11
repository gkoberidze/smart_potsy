class Device {
  final int id;
  final String deviceId;
  final int userId;
  final DateTime createdAt;
  final DateTime? lastSeen;

  Device({
    required this.id,
    required this.deviceId,
    required this.userId,
    required this.createdAt,
    this.lastSeen,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] ?? 0,
      deviceId: json['device_id'] ?? json['deviceId'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? 0,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
      lastSeen:
          json['last_seen'] != null ? DateTime.parse(json['last_seen']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'last_seen': lastSeen?.toIso8601String(),
    };
  }
}
