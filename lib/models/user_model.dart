class UserModel {
  final String phoneNumber;
  final String fullName;
  final String role;
  final String password; // Legacy only — never written since the Auth migration
  final String? uid; // Firebase Auth uid (set after tool/migrate_auth.mjs)
  final String? registrationStatus; // pending | approved | rejected (applicants)
  final double? latitude;
  final double? longitude;
  final String? subscriptionPlan;
  final bool? isSubscribed;
  final String societeId; // '' for clients/collectors without a console link
  final String agenceId;
  final String collecteurId; // collecteur assigné au client par le backoffice

  UserModel({
    required this.phoneNumber,
    required this.fullName,
    required this.role,
    this.password = '',
    this.uid,
    this.registrationStatus,
    this.latitude,
    this.longitude,
    this.subscriptionPlan,
    this.isSubscribed,
    this.societeId = '',
    this.agenceId = '',
    this.collecteurId = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'phoneNumber': phoneNumber,
      'fullName': fullName,
      'role': role,
      'uid': uid,
      'registrationStatus': registrationStatus,
      'latitude': latitude,
      'longitude': longitude,
      'subscription_plan': subscriptionPlan,
      'isSubscribed': isSubscribed,
      'societeId': societeId,
      'agenceId': agenceId,
      'collecteurId': collecteurId,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      phoneNumber: map['phoneNumber'] ?? '',
      fullName: map['fullName'] ?? '',
      role: (map['role'] as String?)?.trim().toLowerCase() ?? 'client',
      password: map['password'] ?? '', // Read for legacy docs only
      uid: map['uid'] as String?,
      registrationStatus: map['registrationStatus'] as String?,
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      subscriptionPlan: map['subscription_plan'] as String?,
      isSubscribed: map['isSubscribed'] as bool?,
      societeId: map['societeId'] as String? ?? '',
      agenceId: map['agenceId'] as String? ?? '',
      collecteurId: map['collecteurId'] as String? ?? '',
    );
  }
}
