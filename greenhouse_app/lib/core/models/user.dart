class User {
  final int id;
  final String email;
  final String? oauthProvider;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    this.oauthProvider,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int? ?? 0,
      email: json['email'] as String? ?? '',
      oauthProvider: json['oauth_provider'] as String?,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'oauth_provider': oauthProvider,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
