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

  const ClientModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.zone,
    required this.plan,
    required this.status,
    this.agenceId = '',
    this.societeId = '',
  });

  ClientModel copyWith({
    String? name,
    String? phone,
    String? zone,
    String? plan,
    String? status,
    String? agenceId,
    String? societeId,
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
