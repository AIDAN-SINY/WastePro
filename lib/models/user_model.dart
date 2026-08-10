class UserModel {
  final String phoneNumber;
  final String fullName;
  final String role;
  final String password; // Changed from pin
  final double? latitude;
  final double? longitude;
  final String? subscriptionPlan;
  final bool? isSubscribed;
  final String societeId; // '' for clients/collectors without a console link
  final String agenceId;

  UserModel({
    required this.phoneNumber,
    required this.fullName,
    required this.role,
    required this.password,
    this.latitude,
    this.longitude,
    this.subscriptionPlan,
    this.isSubscribed,
    this.societeId = '',
    this.agenceId = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'phoneNumber': phoneNumber,
      'fullName': fullName,
      'role': role,
      'password': password, // Store as password
      'latitude': latitude,
      'longitude': longitude,
      'subscription_plan': subscriptionPlan,
      'isSubscribed': isSubscribed,
      'societeId': societeId,
      'agenceId': agenceId,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      phoneNumber: map['phoneNumber'] ?? '',
      fullName: map['fullName'] ?? '',
      role: (map['role'] as String?)?.trim().toLowerCase() ?? 'client',
      password: map['password'] ?? '', // Read as password
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      subscriptionPlan: map['subscription_plan'] as String?,
      isSubscribed: map['isSubscribed'] as bool?,
      societeId: map['societeId'] as String? ?? '',
      agenceId: map['agenceId'] as String? ?? '',
    );
  }
}
