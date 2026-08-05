class UserModel {
  final String phoneNumber;
  final String fullName;
  final String role;
  final String password; // Changed from pin
  final double? latitude;
  final double? longitude;
  final String? subscriptionPlan;
  final bool? isSubscribed;

  UserModel({
    required this.phoneNumber,
    required this.fullName,
    required this.role,
    required this.password,
    this.latitude,
    this.longitude,
    this.subscriptionPlan,
    this.isSubscribed,
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
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      phoneNumber: map['phoneNumber'] ?? '',
      fullName: map['fullName'] ?? '',
      role: map['role'] ?? 'client',
      password: map['password'] ?? '', // Read as password
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      subscriptionPlan: map['subscription_plan'] as String?,
      isSubscribed: map['isSubscribed'] as bool?,
    );
  }
}
