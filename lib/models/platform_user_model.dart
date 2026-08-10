/// A platform back-office user managed by the super admin (or by the
/// General Administrator in the company console).
///
/// These are the "Users" entity from the super admin console design:
/// accounts with a platform role ('General Administrator' | 'Agency Manager')
/// attached to a company and optionally an agency.
///
/// [password] is the login password set at creation: when non-empty, the
/// Firestore store mirrors the account into the `users` collection so the
/// user can log in with phone + password.
class PlatformUserModel {
  final String id;
  final String nom;
  final String telephone;
  final String role; // 'General Administrator' | 'Agency Manager' (legacy: FR)
  final String agence;
  final String societeId; // foreign key to the parent company
  final String agenceId; // foreign key to the agency ('' for GAs)
  final String status; // 'Active' | 'Suspended' (legacy: 'Actif'/'Suspendu')
  final String password; // '' = no login account

  const PlatformUserModel({
    required this.id,
    required this.nom,
    required this.telephone,
    required this.role,
    required this.agence,
    this.societeId = '',
    this.agenceId = '',
    required this.status,
    this.password = '',
  });

  PlatformUserModel copyWith({
    String? nom,
    String? telephone,
    String? role,
    String? agence,
    String? societeId,
    String? agenceId,
    String? status,
    String? password,
  }) {
    return PlatformUserModel(
      id: id,
      nom: nom ?? this.nom,
      telephone: telephone ?? this.telephone,
      role: role ?? this.role,
      agence: agence ?? this.agence,
      societeId: societeId ?? this.societeId,
      agenceId: agenceId ?? this.agenceId,
      status: status ?? this.status,
      password: password ?? this.password,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'telephone': telephone,
      'role': role,
      'agence': agence,
      'societeId': societeId,
      'agenceId': agenceId,
      'status': status,
      'password': password,
    };
  }

  factory PlatformUserModel.fromMap(Map<String, dynamic> map) {
    return PlatformUserModel(
      id: map['id'] as String? ?? '',
      nom: map['nom'] as String? ?? '',
      telephone: map['telephone'] as String? ?? '',
      role: map['role'] as String? ?? 'Agency Manager',
      agence: map['agence'] as String? ?? '—',
      societeId: map['societeId'] as String? ?? '',
      agenceId: map['agenceId'] as String? ?? '',
      status: map['status'] as String? ?? 'Active',
      password: map['password'] as String? ?? '',
    );
  }
}
