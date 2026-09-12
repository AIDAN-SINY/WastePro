class UserModel {
  final String phoneNumber;
  final String fullName;
  final String role;
  final String password;
  final double? latitude;
  final double? longitude;
  final String? subscriptionPlan;
  final bool? isSubscribed;
  final String? neighborhood;
  final double earnings;
  final int successPickups;
  final bool isVerified;
  final String? assignedCollector;

  UserModel({
    required this.phoneNumber,
    required this.fullName,
    required this.role,
    required this.password,
    this.latitude,
    this.longitude,
    this.subscriptionPlan,
    this.isSubscribed,
    this.neighborhood,
    this.earnings = 0,
    this.successPickups = 0,
    this.isVerified = false,
    this.assignedCollector,
  });

  String get displayInitial {
    final name = fullName.trim();
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  String get firstName {
    final name = fullName.trim();
    if (name.isEmpty) return 'User';
    return name.split(RegExp(r'\s+')).first;
  }

  String get formattedPhone {
    final digits = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('+237') || digits.startsWith('237')) {
      return digits.startsWith('+') ? digits : '+$digits';
    }
    if (digits.length == 9) return '+237$digits';
    return phoneNumber;
  }

  Map<String, dynamic> toMap() {
    return {
      'phoneNumber': phoneNumber,
      'fullName': fullName,
      'role': role,
      'password': password,
      'latitude': latitude,
      'longitude': longitude,
      'subscription_plan': subscriptionPlan,
      'isSubscribed': isSubscribed ?? false,
      'neighborhood': neighborhood,
      'earnings': earnings,
      'successPickups': successPickups,
      'isVerified': isVerified,
      if (assignedCollector != null) 'assignedCollector': assignedCollector,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    double? asDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    int asInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    return UserModel(
      phoneNumber: map['phoneNumber']?.toString() ?? '',
      fullName: map['fullName']?.toString() ?? '',
      role: (map['role'] as String?)?.trim().toLowerCase() ?? 'client',
      password: map['password']?.toString() ?? '',
      latitude: asDouble(map['latitude']),
      longitude: asDouble(map['longitude']),
      subscriptionPlan: map['subscription_plan'] as String?,
      isSubscribed: map['isSubscribed'] as bool?,
      neighborhood: map['neighborhood'] as String?,
      earnings: asDouble(map['earnings']) ?? 0,
      successPickups: asInt(map['successPickups']),
      isVerified: map['isVerified'] == true,
      assignedCollector: map['assignedCollector'] as String?,
    );
  }

  UserModel copyWith({
    String? phoneNumber,
    String? fullName,
    String? role,
    String? password,
    double? latitude,
    double? longitude,
    String? subscriptionPlan,
    bool? isSubscribed,
    String? neighborhood,
    double? earnings,
    int? successPickups,
    bool? isVerified,
    String? assignedCollector,
  }) {
    return UserModel(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      password: password ?? this.password,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      neighborhood: neighborhood ?? this.neighborhood,
      earnings: earnings ?? this.earnings,
      successPickups: successPickups ?? this.successPickups,
      isVerified: isVerified ?? this.isVerified,
      assignedCollector: assignedCollector ?? this.assignedCollector,
    );
  }
}
