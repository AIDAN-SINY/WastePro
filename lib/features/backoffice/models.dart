/// Models of the mobile backoffice, mirroring the mock entities of
/// `backoffice-mobile.html`. Each model is Firestore-ready (toMap/fromMap)
/// so a Firestore-backed store can be added later without touching the UI.
library;

/// Entity kind managed by the backoffice (drives the lists and the sheets).
enum BoEntity { client, collecteur, contrat, collecte, facture, frequence }

class ClientModel {
  final String id;
  final String name;
  final String phone;
  final String zone;
  final String plan; // 'Essential' | 'Standard' | 'Premium'
  final String status; // 'Active' | 'Suspended'
  final String agenceId;
  final String societeId;
  final String collecteurId; // collecteur assigné (un collecteur = plusieurs clients)

  const ClientModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.zone,
    required this.plan,
    required this.status,
    this.agenceId = '',
    this.societeId = '',
    this.collecteurId = '',
  });

  ClientModel copyWith({
    String? name,
    String? phone,
    String? zone,
    String? plan,
    String? status,
    String? agenceId,
    String? societeId,
    String? collecteurId,
  }) {
    return ClientModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      zone: zone ?? this.zone,
      plan: plan ?? this.plan,
      status: status ?? this.status,
      agenceId: agenceId ?? this.agenceId,
      societeId: societeId ?? this.societeId,
      collecteurId: collecteurId ?? this.collecteurId,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'zone': zone,
        'plan': plan,
        'status': status,
        'agenceId': agenceId,
        'societeId': societeId,
        'collecteurId': collecteurId,
      };

  factory ClientModel.fromMap(Map<String, dynamic> map) => ClientModel(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        zone: map['zone'] as String? ?? '',
        plan: map['plan'] as String? ?? 'Standard',
        status: map['status'] as String? ?? 'Active',
        agenceId: map['agenceId'] as String? ?? '',
        societeId: map['societeId'] as String? ?? '',
        collecteurId: map['collecteurId'] as String? ?? '',
      );
}

/// Candidature d'un futur client (pré-inscription côté app client).
///
/// Le client remplit ses infos + choisit son agence (suggestions par zone /
/// recherche libre). La candidature arrive avec le statut `pending` dans le
/// dashboard du chef d'agence qui l'approuve (en assignant un collecteur)
/// ou la rejette. À l'approbation, un vrai [ClientModel] + compte de
/// connexion `users/{téléphone}` sont créés.
class RegistrationModel {
  final String id;
  final String fullName;
  final String phone;
  final String zone;
  final String agenceId; // '' si l'agence a été saisie par son nom
  final String agenceName;
  final String societeId;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String collecteurId; // assigné par le chef d'agence à l'approbation
  final String password; // mot de passe choisi par le client
  final String createdAt; // yyyy-MM-dd

  const RegistrationModel({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.zone,
    required this.agenceId,
    required this.agenceName,
    required this.societeId,
    required this.status,
    required this.password,
    required this.createdAt,
    this.collecteurId = '',
  });

  RegistrationModel copyWith({
    String? fullName,
    String? phone,
    String? zone,
    String? agenceId,
    String? agenceName,
    String? societeId,
    String? status,
    String? collecteurId,
    String? password,
  }) {
    return RegistrationModel(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      zone: zone ?? this.zone,
      agenceId: agenceId ?? this.agenceId,
      agenceName: agenceName ?? this.agenceName,
      societeId: societeId ?? this.societeId,
      status: status ?? this.status,
      collecteurId: collecteurId ?? this.collecteurId,
      password: password ?? this.password,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'fullName': fullName,
        'phone': phone,
        'zone': zone,
        'agenceId': agenceId,
        'agenceName': agenceName,
        'societeId': societeId,
        'status': status,
        'collecteurId': collecteurId,
        'password': password,
        'createdAt': createdAt,
      };

  factory RegistrationModel.fromMap(Map<String, dynamic> map) =>
      RegistrationModel(
        id: map['id'] as String? ?? '',
        fullName: map['fullName'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        zone: map['zone'] as String? ?? '',
        agenceId: map['agenceId'] as String? ?? '',
        agenceName: map['agenceName'] as String? ?? '',
        societeId: map['societeId'] as String? ?? '',
        status: map['status'] as String? ?? 'pending',
        collecteurId: map['collecteurId'] as String? ?? '',
        password: map['password'] as String? ?? '',
        createdAt: map['createdAt'] as String? ?? '',
      );
}

class CollecteurModel {
  final String id;
  final String name;
  final String phone;
  final String zone;
  final double rating;
  final String status; // 'Active' | 'Inactive'
  final String agenceId;
  final String societeId;

  const CollecteurModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.zone,
    required this.rating,
    required this.status,
    this.agenceId = '',
    this.societeId = '',
  });

  CollecteurModel copyWith({
    String? name,
    String? phone,
    String? zone,
    double? rating,
    String? status,
    String? agenceId,
    String? societeId,
  }) {
    return CollecteurModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      zone: zone ?? this.zone,
      rating: rating ?? this.rating,
      status: status ?? this.status,
      agenceId: agenceId ?? this.agenceId,
      societeId: societeId ?? this.societeId,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'zone': zone,
        'rating': rating,
        'status': status,
        'agenceId': agenceId,
        'societeId': societeId,
      };

  factory CollecteurModel.fromMap(Map<String, dynamic> map) => CollecteurModel(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        zone: map['zone'] as String? ?? '',
        rating: (map['rating'] as num?)?.toDouble() ?? 0,
        status: map['status'] as String? ?? 'Active',
        agenceId: map['agenceId'] as String? ?? '',
        societeId: map['societeId'] as String? ?? '',
      );
}

class ContratModel {
  final String id;
  final String client; // client name
  final String frequence; // libelle
  final int prix;
  final String status; // 'Active' | 'Suspended' | 'Expired'

  const ContratModel({
    required this.id,
    required this.client,
    required this.frequence,
    required this.prix,
    required this.status,
  });

  ContratModel copyWith({
    String? client,
    String? frequence,
    int? prix,
    String? status,
  }) {
    return ContratModel(
      id: id,
      client: client ?? this.client,
      frequence: frequence ?? this.frequence,
      prix: prix ?? this.prix,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'client': client,
        'frequence': frequence,
        'prix': prix,
        'status': status,
      };

  factory ContratModel.fromMap(Map<String, dynamic> map) => ContratModel(
        id: map['id'] as String? ?? '',
        client: map['client'] as String? ?? '',
        frequence: map['frequence'] as String? ?? '',
        prix: (map['prix'] as num?)?.toInt() ?? 0,
        status: map['status'] as String? ?? 'Active',
      );
}

class CollecteModel {
  final String id;
  final String client;
  final String collecteur;
  final String date; // yyyy-MM-dd
  final double poids;
  final String status; // 'Completed' | 'Scheduled' | 'Missed'

  const CollecteModel({
    required this.id,
    required this.client,
    required this.collecteur,
    required this.date,
    required this.poids,
    required this.status,
  });

  CollecteModel copyWith({
    String? client,
    String? collecteur,
    String? date,
    double? poids,
    String? status,
  }) {
    return CollecteModel(
      id: id,
      client: client ?? this.client,
      collecteur: collecteur ?? this.collecteur,
      date: date ?? this.date,
      poids: poids ?? this.poids,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'client': client,
        'collecteur': collecteur,
        'date': date,
        'poids': poids,
        'status': status,
      };

  factory CollecteModel.fromMap(Map<String, dynamic> map) => CollecteModel(
        id: map['id'] as String? ?? '',
        client: map['client'] as String? ?? '',
        collecteur: map['collecteur'] as String? ?? '',
        date: map['date'] as String? ?? '',
        poids: (map['poids'] as num?)?.toDouble() ?? 0,
        status: map['status'] as String? ?? 'Scheduled',
      );
}

class FactureModel {
  final String id;
  final String client;
  final int montant;
  final String echeance; // yyyy-MM-dd
  final String status; // 'Paid' | 'Pending' | 'Overdue'

  const FactureModel({
    required this.id,
    required this.client,
    required this.montant,
    required this.echeance,
    required this.status,
  });

  FactureModel copyWith({
    String? client,
    int? montant,
    String? echeance,
    String? status,
  }) {
    return FactureModel(
      id: id,
      client: client ?? this.client,
      montant: montant ?? this.montant,
      echeance: echeance ?? this.echeance,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'client': client,
        'montant': montant,
        'echeance': echeance,
        'status': status,
      };

  factory FactureModel.fromMap(Map<String, dynamic> map) => FactureModel(
        id: map['id'] as String? ?? '',
        client: map['client'] as String? ?? '',
        montant: (map['montant'] as num?)?.toInt() ?? 0,
        echeance: map['echeance'] as String? ?? '',
        status: map['status'] as String? ?? 'Pending',
      );
}

class FrequenceModel {
  final String id;
  final String libelle;
  final int jours;

  const FrequenceModel({
    required this.id,
    required this.libelle,
    required this.jours,
  });

  FrequenceModel copyWith({String? libelle, int? jours}) {
    return FrequenceModel(
      id: id,
      libelle: libelle ?? this.libelle,
      jours: jours ?? this.jours,
    );
  }

  Map<String, dynamic> toMap() => {'id': id, 'libelle': libelle, 'jours': jours};

  factory FrequenceModel.fromMap(Map<String, dynamic> map) => FrequenceModel(
        id: map['id'] as String? ?? '',
        libelle: map['libelle'] as String? ?? '',
        jours: (map['jours'] as num?)?.toInt() ?? 7,
      );
}

/// Nom du collecteur correspondant à un id ('' si inconnu / non assigné).
///
/// Partagé par le backoffice (cartes clients, réassignation) — les collectes
/// référencent le collecteur par son NOM, d'où la résolution id → nom.
String collecteurNameFor(List<CollecteurModel> collecteurs, String id) {
  if (id.isEmpty) return '';
  for (final c in collecteurs) {
    if (c.id == id) return c.name;
  }
  return '';
}
