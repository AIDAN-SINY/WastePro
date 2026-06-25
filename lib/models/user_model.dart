class UserModel {
  final String uid;
  final String phoneNumber;
  final String fullName;
  final String role; // 'client' or 'collector'
  final bool isVerified;
  final double? latitude;
  final double? longitude;

  UserModel({
    required this.uid,
    required this.phoneNumber,
    required this.fullName,
    required this.role,
    this.isVerified = false,
    this.latitude,
    this.longitude,
  });

  // Convert a Firestore Document to a local User Object
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      fullName: map['fullName'] ?? '',
      role: map['role'] ?? 'client',
      isVerified: map['isVerified'] ?? false,
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
    );
  }

  // Convert our User Object to a Map to save in Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'fullName': fullName,
      'role': role,
      'isVerified': isVerified,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}