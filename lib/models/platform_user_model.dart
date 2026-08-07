/// A platform back-office user managed by the super admin.
///
/// These are the "Users" entity from the super admin console design:
/// accounts with a platform role ('General Administrator' | 'Agency Manager')
/// attached to an agency. This is distinct from the end-user accounts
/// (clients/collectors) stored in `users`.
///
/// [password] is the login password set by the super admin at creation (no
/// email flow yet): when non-empty, the Firestore store mirrors the account
/// into the `users` collection so the user can log in with phone + password.
class PlatformUserModel {
  final String id;
  final String nom;
  final String telephone;
  final String role; // 'General Administrator' | 'Agency Manager' (legacy: FR)
  final String agence;
  final String status; // 'Active' | 'Suspended' (legacy: 'Actif'/'Suspendu')
  final String password; // '' = no login account

  const PlatformUserModel({
    required this.id,
    required this.nom,
    required this.telephone,
    required this.role,
    required this.agence,
    required this.status,
    this.password = '',
  });

  PlatformUserModel copyWith({
    String? nom,
    String? telephone,
    String? role,
    String? agence,
    String? status,
    String? password,
  }) {
    return PlatformUserModel(
      id: id,
      nom: nom ?? this.nom,
      telephone: telephone ?? this.telephone,
      role: role ?? this.role,
      agence: agence ?? this.agence,
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
      status: map['status'] as String? ?? 'Active',
      password: map['password'] as String? ?? '',
    );
  }
}
