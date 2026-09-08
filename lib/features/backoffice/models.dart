/// Models of the mobile backoffice, mirroring the mock entities of
/// `backoffice-mobile.html`. Each model is Firestore-ready (toMap/fromMap)
/// so a Firestore-backed store can be added later without touching the UI.
library;

/// Entity kind managed by the backoffice (drives the lists and the sheets).
enum BoEntity { client, collecteur, contrat, collecte, facture, frequence, issue, zone, assignment, vehicle }

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
  final String adresse; // Adresse du client
  final String quartier; // Quartier / neighborhood
  final double? latitude; // GPS latitude
  final double? longitude; // GPS longitude
  final String photoUrl; // URL de la photo
  final String housingType; // Type d'habitation (House, Apartment, Villa, Other)

  /// Date d'abonnement (yyyy-MM-dd) — alimente les graphiques annuels
  /// « nouveaux clients abonnés par mois ». Vide si inconnue (docs créés
  /// avant l'introduction du champ).
  final String subscribedAt;

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
    this.adresse = '',
    this.quartier = '',
    this.latitude,
    this.longitude,
    this.photoUrl = '',
    this.housingType = '',
    this.subscribedAt = '',
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
    String? adresse,
    String? quartier,
    double? latitude,
    double? longitude,
    String? photoUrl,
    String? housingType,
    String? subscribedAt,
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
      adresse: adresse ?? this.adresse,
      quartier: quartier ?? this.quartier,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      photoUrl: photoUrl ?? this.photoUrl,
      housingType: housingType ?? this.housingType,
      subscribedAt: subscribedAt ?? this.subscribedAt,
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
        'adresse': adresse,
        'quartier': quartier,
        'latitude': latitude,
        'longitude': longitude,
        'photoUrl': photoUrl,
        'housingType': housingType,
        'subscribedAt': subscribedAt,
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
        adresse: map['adresse'] as String? ?? '',
        quartier: map['quartier'] as String? ?? '',
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        photoUrl: map['photoUrl'] as String? ?? '',
        housingType: map['housingType'] as String? ?? '',
        subscribedAt: map['subscribedAt'] as String? ?? '',
      );
}

/// Mois (Jan → Déc) des graphiques annuels d'abonnements clients.
const List<String> subscriptionMonthLabels = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Répartition des nouveaux clients abonnés par mois (index 0 = janvier)
/// pendant [year]. Les clients sans date d'abonnement (`subscribedAt` vide,
/// docs créés avant le champ) ne sont pas comptés.
List<int> monthlySubscriptions(Iterable<ClientModel> clients, int year) {
  final counts = List<int>.filled(12, 0);
  for (final c in clients) {
    final d = DateTime.tryParse(c.subscribedAt);
    if (d != null && d.year == year) counts[d.month - 1]++;
  }
  return counts;
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
  final String cni; // Carte Nationale d'Identité
  final String photoUrl; // URL de la photo
  final String vehicle; // Description du véhicule (ex. 'Tricycle — MB-2024-CM')
  final int salary; // Salaire en XAF

  const CollecteurModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.zone,
    required this.rating,
    required this.status,
    this.agenceId = '',
    this.societeId = '',
    this.cni = '',
    this.photoUrl = '',
    this.vehicle = '',
    this.salary = 0,
  });

  CollecteurModel copyWith({
    String? name,
    String? phone,
    String? zone,
    double? rating,
    String? status,
    String? agenceId,
    String? societeId,
    String? cni,
    String? photoUrl,
    String? vehicle,
    int? salary,
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
      cni: cni ?? this.cni,
      photoUrl: photoUrl ?? this.photoUrl,
      vehicle: vehicle ?? this.vehicle,
      salary: salary ?? this.salary,
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
        'cni': cni,
        'photoUrl': photoUrl,
        'vehicle': vehicle,
        'salary': salary,
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
        cni: map['cni'] as String? ?? '',
        photoUrl: map['photoUrl'] as String? ?? '',
        vehicle: map['vehicle'] as String? ?? '',
        salary: (map['salary'] as num?)?.toInt() ?? 0,
      );
}

class ContratModel {
  final String id;
  final String client; // client name
  final String frequence; // libelle
  final int prix;
  final String status; // 'Active' | 'Suspended' | 'Expired'
  final String agenceId;
  final String societeId;

  /// Frequency tier chosen by the client (daily / every_2_days / weekly / monthly).
  final String frequencyTier;

  /// Concrete collection day(s) resolved from the zone's calendar.
  final List<String> collectionDays;

  /// Standard pickup time window inherited from the zone.
  final String pickupTime;

  /// Zone name this contract is linked to.
  final String zoneName;

  const ContratModel({
    required this.id,
    required this.client,
    required this.frequence,
    required this.prix,
    required this.status,
    this.agenceId = '',
    this.societeId = '',
    this.frequencyTier = '',
    this.collectionDays = const [],
    this.pickupTime = '',
    this.zoneName = '',
  });

  ContratModel copyWith({
    String? client,
    String? frequence,
    int? prix,
    String? status,
    String? agenceId,
    String? societeId,
    String? frequencyTier,
    List<String>? collectionDays,
    String? pickupTime,
    String? zoneName,
  }) {
    return ContratModel(
      id: id,
      client: client ?? this.client,
      frequence: frequence ?? this.frequence,
      prix: prix ?? this.prix,
      status: status ?? this.status,
      agenceId: agenceId ?? this.agenceId,
      societeId: societeId ?? this.societeId,
      frequencyTier: frequencyTier ?? this.frequencyTier,
      collectionDays: collectionDays ?? this.collectionDays,
      pickupTime: pickupTime ?? this.pickupTime,
      zoneName: zoneName ?? this.zoneName,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'client': client,
        'frequence': frequence,
        'prix': prix,
        'status': status,
        'agenceId': agenceId,
        'societeId': societeId,
        'frequencyTier': frequencyTier,
        'collectionDays': collectionDays,
        'pickupTime': pickupTime,
        'zoneName': zoneName,
      };

  factory ContratModel.fromMap(Map<String, dynamic> map) => ContratModel(
        id: map['id'] as String? ?? '',
        client: map['client'] as String? ?? '',
        frequence: map['frequence'] as String? ?? '',
        prix: (map['prix'] as num?)?.toInt() ?? 0,
        status: map['status'] as String? ?? 'Active',
        agenceId: map['agenceId'] as String? ?? '',
        societeId: map['societeId'] as String? ?? '',
        frequencyTier: map['frequencyTier'] as String? ?? '',
        collectionDays: (map['collectionDays'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        pickupTime: map['pickupTime'] as String? ?? '',
        zoneName: map['zoneName'] as String? ?? '',
      );
}

class CollecteModel {
  final String id;
  final String client;
  final String collecteur;
  final String date; // yyyy-MM-dd
  final double poids;
  final String status; // 'Completed' | 'Scheduled' | 'Missed'
  final String agenceId;
  final String societeId;

  const CollecteModel({
    required this.id,
    required this.client,
    required this.collecteur,
    required this.date,
    required this.poids,
    required this.status,
    this.agenceId = '',
    this.societeId = '',
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
      agenceId: agenceId,
      societeId: societeId,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'client': client,
        'collecteur': collecteur,
        'date': date,
        'poids': poids,
        'status': status,
        'agenceId': agenceId,
        'societeId': societeId,
      };

  factory CollecteModel.fromMap(Map<String, dynamic> map) => CollecteModel(
        id: map['id'] as String? ?? '',
        client: map['client'] as String? ?? '',
        collecteur: map['collecteur'] as String? ?? '',
        date: map['date'] as String? ?? '',
        poids: (map['poids'] as num?)?.toDouble() ?? 0,
        status: map['status'] as String? ?? 'Scheduled',
        agenceId: map['agenceId'] as String? ?? '',
        societeId: map['societeId'] as String? ?? '',
      );
}

class FactureModel {
  final String id;
  final String client;
  final int montant;
  final String echeance; // yyyy-MM-dd
  final String status; // 'Paid' | 'Pending' | 'Overdue'
  final String agenceId;
  final String societeId;

  const FactureModel({
    required this.id,
    required this.client,
    required this.montant,
    required this.echeance,
    required this.status,
    this.agenceId = '',
    this.societeId = '',
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
      agenceId: agenceId,
      societeId: societeId,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'client': client,
        'montant': montant,
        'echeance': echeance,
        'status': status,
        'agenceId': agenceId,
        'societeId': societeId,
      };

  factory FactureModel.fromMap(Map<String, dynamic> map) => FactureModel(
        id: map['id'] as String? ?? '',
        client: map['client'] as String? ?? '',
        montant: (map['montant'] as num?)?.toInt() ?? 0,
        echeance: map['echeance'] as String? ?? '',
        status: map['status'] as String? ?? 'Pending',
        agenceId: map['agenceId'] as String? ?? '',
        societeId: map['societeId'] as String? ?? '',
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

class VehicleModel {
  final String id;
  final String plateNumber; // e.g. 'CE-123-AE'
  final String type; // 'Tricycle' | 'Truck' | 'Motorcycle' | 'Van'
  final String brand; // e.g. 'Honda'
  final String model; // e.g. 'Tricycle TMO-250'
  final int year; // e.g. 2024
  final String status; // 'Active' | 'Maintenance' | 'Retired'
  final String agenceId;
  final String societeId;
  final String assignedCollecteurId; // collector currently using this vehicle
  final String assignedCollecteurName;
  final int mileage; // current odometer reading (km)
  final String lastMaintenanceDate; // yyyy-MM-dd
  final int maintenanceIntervalKm; // service every N km (default 5000)
  final int maintenanceIntervalDays; // service every N days (default 30)
  final String notes;

  const VehicleModel({
    required this.id,
    required this.plateNumber,
    required this.type,
    this.brand = '',
    this.model = '',
    this.year = 0,
    this.status = 'Active',
    this.agenceId = '',
    this.societeId = '',
    this.assignedCollecteurId = '',
    this.assignedCollecteurName = '',
    this.mileage = 0,
    this.lastMaintenanceDate = '',
    this.maintenanceIntervalKm = 5000,
    this.maintenanceIntervalDays = 30,
    this.notes = '',
  });

  VehicleModel copyWith({
    String? plateNumber,
    String? type,
    String? brand,
    String? model,
    int? year,
    String? status,
    String? agenceId,
    String? societeId,
    String? assignedCollecteurId,
    String? assignedCollecteurName,
    int? mileage,
    String? lastMaintenanceDate,
    int? maintenanceIntervalKm,
    int? maintenanceIntervalDays,
    String? notes,
  }) {
    return VehicleModel(
      id: id,
      plateNumber: plateNumber ?? this.plateNumber,
      type: type ?? this.type,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      status: status ?? this.status,
      agenceId: agenceId ?? this.agenceId,
      societeId: societeId ?? this.societeId,
      assignedCollecteurId: assignedCollecteurId ?? this.assignedCollecteurId,
      assignedCollecteurName: assignedCollecteurName ?? this.assignedCollecteurName,
      mileage: mileage ?? this.mileage,
      lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate,
      maintenanceIntervalKm: maintenanceIntervalKm ?? this.maintenanceIntervalKm,
      maintenanceIntervalDays: maintenanceIntervalDays ?? this.maintenanceIntervalDays,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'plateNumber': plateNumber,
        'type': type,
        'brand': brand,
        'model': model,
        'year': year,
        'status': status,
        'agenceId': agenceId,
        'societeId': societeId,
        'assignedCollecteurId': assignedCollecteurId,
        'assignedCollecteurName': assignedCollecteurName,
        'mileage': mileage,
        'lastMaintenanceDate': lastMaintenanceDate,
        'maintenanceIntervalKm': maintenanceIntervalKm,
        'maintenanceIntervalDays': maintenanceIntervalDays,
        'notes': notes,
      };

  factory VehicleModel.fromMap(Map<String, dynamic> map) => VehicleModel(
        id: map['id'] as String? ?? '',
        plateNumber: map['plateNumber'] as String? ?? '',
        type: map['type'] as String? ?? 'Tricycle',
        brand: map['brand'] as String? ?? '',
        model: map['model'] as String? ?? '',
        year: (map['year'] as num?)?.toInt() ?? 0,
        status: map['status'] as String? ?? 'Active',
        agenceId: map['agenceId'] as String? ?? '',
        societeId: map['societeId'] as String? ?? '',
        assignedCollecteurId: map['assignedCollecteurId'] as String? ?? '',
        assignedCollecteurName: map['assignedCollecteurName'] as String? ?? '',
        mileage: (map['mileage'] as num?)?.toInt() ?? 0,
        lastMaintenanceDate: map['lastMaintenanceDate'] as String? ?? '',
        maintenanceIntervalKm: (map['maintenanceIntervalKm'] as num?)?.toInt() ?? 5000,
        maintenanceIntervalDays: (map['maintenanceIntervalDays'] as num?)?.toInt() ?? 30,
        notes: map['notes'] as String? ?? '',
      );
}

/// A single maintenance log entry for a vehicle.
class VehicleMaintenanceModel {
  final String id;
  final String vehicleId;
  final String vehiclePlate;
  final String type; // 'Oil Change' | 'Tire Rotation' | 'Brake Service' | 'Engine Repair' | 'General Inspection' | 'Other'
  final String description;
  final int mileageAtService; // odometer at time of service
  final String serviceDate; // yyyy-MM-dd
  final int cost; // in XAF
  final String mechanicName;
  final String nextServiceDate; // yyyy-MM-dd (scheduled)
  final int nextServiceMileage; // km (scheduled)
  final String status; // 'Completed' | 'Scheduled' | 'Overdue'
  final String agenceId;
  final String societeId;

  const VehicleMaintenanceModel({
    required this.id,
    required this.vehicleId,
    required this.vehiclePlate,
    required this.type,
    this.description = '',
    this.mileageAtService = 0,
    required this.serviceDate,
    this.cost = 0,
    this.mechanicName = '',
    this.nextServiceDate = '',
    this.nextServiceMileage = 0,
    this.status = 'Completed',
    this.agenceId = '',
    this.societeId = '',
  });

  VehicleMaintenanceModel copyWith({
    String? type,
    String? description,
    int? mileageAtService,
    String? serviceDate,
    int? cost,
    String? mechanicName,
    String? nextServiceDate,
    int? nextServiceMileage,
    String? status,
  }) {
    return VehicleMaintenanceModel(
      id: id,
      vehicleId: vehicleId,
      vehiclePlate: vehiclePlate,
      type: type ?? this.type,
      description: description ?? this.description,
      mileageAtService: mileageAtService ?? this.mileageAtService,
      serviceDate: serviceDate ?? this.serviceDate,
      cost: cost ?? this.cost,
      mechanicName: mechanicName ?? this.mechanicName,
      nextServiceDate: nextServiceDate ?? this.nextServiceDate,
      nextServiceMileage: nextServiceMileage ?? this.nextServiceMileage,
      status: status ?? this.status,
      agenceId: agenceId,
      societeId: societeId,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'vehicleId': vehicleId,
        'vehiclePlate': vehiclePlate,
        'type': type,
        'description': description,
        'mileageAtService': mileageAtService,
        'serviceDate': serviceDate,
        'cost': cost,
        'mechanicName': mechanicName,
        'nextServiceDate': nextServiceDate,
        'nextServiceMileage': nextServiceMileage,
        'status': status,
        'agenceId': agenceId,
        'societeId': societeId,
      };

  factory VehicleMaintenanceModel.fromMap(Map<String, dynamic> map) =>
      VehicleMaintenanceModel(
        id: map['id'] as String? ?? '',
        vehicleId: map['vehicleId'] as String? ?? '',
        vehiclePlate: map['vehiclePlate'] as String? ?? '',
        type: map['type'] as String? ?? 'General Inspection',
        description: map['description'] as String? ?? '',
        mileageAtService: (map['mileageAtService'] as num?)?.toInt() ?? 0,
        serviceDate: map['serviceDate'] as String? ?? '',
        cost: (map['cost'] as num?)?.toInt() ?? 0,
        mechanicName: map['mechanicName'] as String? ?? '',
        nextServiceDate: map['nextServiceDate'] as String? ?? '',
        nextServiceMileage: (map['nextServiceMileage'] as num?)?.toInt() ?? 0,
        status: map['status'] as String? ?? 'Completed',
        agenceId: map['agenceId'] as String? ?? '',
        societeId: map['societeId'] as String? ?? '',
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

/// Collection calendar for a zone managed by an agency.
///
/// The Agency Manager defines fixed collection day(s) per zone (e.g.
/// Zone Nord = Tuesday & Friday). Clients in a zone inherit these days
/// when they pick a frequency tier.
class ZoneModel {
  final String id;
  final String name; // e.g. 'Bastos'
  final List<String> collectionDays; // e.g. ['Tuesday', 'Friday']
  final String standardPickupTime; // e.g. '07:00 — 08:00'
  final String agenceId;
  final String societeId;
  final String status; // 'Active' | 'Inactive'

  const ZoneModel({
    required this.id,
    required this.name,
    this.collectionDays = const [],
    this.standardPickupTime = '07:00 — 08:00',
    this.agenceId = '',
    this.societeId = '',
    this.status = 'Active',
  });

  ZoneModel copyWith({
    String? name,
    List<String>? collectionDays,
    String? standardPickupTime,
    String? agenceId,
    String? societeId,
    String? status,
  }) {
    return ZoneModel(
      id: id,
      name: name ?? this.name,
      collectionDays: collectionDays ?? this.collectionDays,
      standardPickupTime: standardPickupTime ?? this.standardPickupTime,
      agenceId: agenceId ?? this.agenceId,
      societeId: societeId ?? this.societeId,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'collectionDays': collectionDays,
    'standardPickupTime': standardPickupTime,
    'agenceId': agenceId,
    'societeId': societeId,
    'status': status,
  };

  factory ZoneModel.fromMap(Map<String, dynamic> map) => ZoneModel(
    id: map['id'] as String? ?? '',
    name: map['name'] as String? ?? '',
    collectionDays: (map['collectionDays'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    standardPickupTime: map['standardPickupTime'] as String? ?? '07:00 — 08:00',
    agenceId: map['agenceId'] as String? ?? '',
    societeId: map['societeId'] as String? ?? '',
    status: map['status'] as String? ?? 'Active',
  );
}

class IssueModel {
  final String id;
  final String clientId;
  final String clientName;
  final String category;
  final String description;
  final String location;
  final String status; // 'open' | 'in_progress' | 'resolved'
  final String createdAt;

  const IssueModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.category,
    required this.description,
    this.location = '',
    required this.status,
    required this.createdAt,
  });

  IssueModel copyWith({
    String? status,
  }) {
    return IssueModel(
      id: id,
      clientId: clientId,
      clientName: clientName,
      category: category,
      description: description,
      location: location,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'client_id': clientId,
    'client_name': clientName,
    'category': category,
    'description': description,
    'location': location,
    'status': status,
    'created_at': createdAt,
  };

  factory IssueModel.fromMap(Map<String, dynamic> map) => IssueModel(
    id: map['id'] as String? ?? '',
    clientId: map['client_id'] as String? ?? '',
    clientName: map['client_name'] as String? ?? '',
    category: map['category'] as String? ?? '',
    description: map['description'] as String? ?? '',
    location: map['location'] as String? ?? '',
    status: map['status'] as String? ?? 'open',
    createdAt: _parseCreatedAt(map['created_at']),
  );

  /// Handles both String dates and Firestore Timestamps.
  static String _parseCreatedAt(dynamic value) {
    if (value is String) return value;
    if (value != null) return value.toString();
    return '';
  }
}
