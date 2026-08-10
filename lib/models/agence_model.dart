/// An agency belonging to a [SocieteModel] on the platform.
///
/// Mirrors the "Agencies" entity from the super admin console design.
class AgenceModel {
  final String id;
  final String societe; // raisonSociale of the parent company
  final String societeId; // foreign key to the parent company
  final String ville;
  final String responsable;
  final String telephone;
  final String status; // 'Active' | 'Suspended' (legacy docs may say 'Actif')

  const AgenceModel({
    required this.id,
    required this.societe,
    this.societeId = '',
    required this.ville,
    required this.responsable,
    required this.telephone,
    required this.status,
  });

  AgenceModel copyWith({
    String? societe,
    String? societeId,
    String? ville,
    String? responsable,
    String? telephone,
    String? status,
  }) {
    return AgenceModel(
      id: id,
      societe: societe ?? this.societe,
      societeId: societeId ?? this.societeId,
      ville: ville ?? this.ville,
      responsable: responsable ?? this.responsable,
      telephone: telephone ?? this.telephone,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'societe': societe,
      'societeId': societeId,
      'ville': ville,
      'responsable': responsable,
      'telephone': telephone,
      'status': status,
    };
  }

  factory AgenceModel.fromMap(Map<String, dynamic> map) {
    return AgenceModel(
      id: map['id'] as String? ?? '',
      societe: map['societe'] as String? ?? '',
      societeId: map['societeId'] as String? ?? '',
      ville: map['ville'] as String? ?? '',
      responsable: map['responsable'] as String? ?? '',
      telephone: map['telephone'] as String? ?? '',
      status: map['status'] as String? ?? 'Active',
    );
  }
}
