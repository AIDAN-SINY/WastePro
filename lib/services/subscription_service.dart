import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const double _earthRadiusKm = 6371.0;

  // --- GEOSPATIAL UTILS ---
  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    final a =
        pow(sin(dLat / 2), 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            pow(sin(dLon / 2), 2);
    final c = 2 * asin(sqrt(a));
    return _earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) => degrees * pi / 180;

  Future<Map<String, dynamic>?> findNearestCollector(
    double latitude,
    double longitude,
  ) async {
    final snapshot = await _db
        .collection('users')
        .where('role', isEqualTo: 'collector')
        .get();
    Map<String, dynamic>? nearest;
    double? nearestDistance;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['latitude'] == null || data['longitude'] == null) continue;
      final distance = _distanceKm(
        latitude,
        longitude,
        (data['latitude'] as num).toDouble(),
        (data['longitude'] as num).toDouble(),
      );

      if (nearestDistance == null || distance < nearestDistance) {
        nearestDistance = distance;
        nearest = {
          'phoneNumber': data['phoneNumber'] ?? doc.id,
          'fullName': data['fullName'] ?? 'Collector',
          'distanceKm': distance,
        };
      }
    }
    return nearest;
  }

  // --- IMPLEMENTING THE DIAGRAM FLOW ---

  /// 1. FLOW: Client -> Frequency -> Contract
  /// This implements the "Contract" table from your diagram.
  Future<void> createContractFlow(
    String clientPhone,
    String frequencyId,
    double amount,
  ) async {
    // Generate Unique ID for the Contract
    String contractId = "CTR-${DateTime.now().millisecondsSinceEpoch}";

    // Step A: Create the record in the 'contracts' collection
    await _db.collection('contracts').doc(contractId).set({
      'contract_id': contractId,
      'client_id': clientPhone, // FK to Clients
      'frequency_id': frequencyId, // FK to Frequency (daily, weekly, monthly)
      'status': 'Active',
      'expiry_date': DateTime.now().add(const Duration(days: 30)),
      'amount_paid': amount,
      'created_at': FieldValue.serverTimestamp(),
    });

    // Step B: Update the Client's user document to store the "Active Contract" pointer
    await _db.collection('users').doc(clientPhone).update({
      'active_contract_id':
          contractId, // Maintains the 1:1 relation from diagram
      'subscription_plan': frequencyId,
      'isSubscribed': true,
      'needsPickup': true,
      'last_subscription_at': FieldValue.serverTimestamp(),
    });
  }

  /// 2. FLOW: Pickup (The Association between Client, Collector, and Contract)
  /// This implements the 'Pickups' intersection table from your diagram.
  Future<void> executePickupFlow(
    String clientPhone,
    String collectorPhone,
    String contractId,
  ) async {
    String pickupId = "PKP-${DateTime.now().millisecondsSinceEpoch}";

    await _db.collection('pickups').doc(pickupId).set({
      'pickup_id': pickupId,
      'client_id': clientPhone, // FK from Diagram
      'collector_id': collectorPhone, // FK from Diagram
      'contract_id': contractId, // FK from Diagram
      'timestamp': FieldValue.serverTimestamp(),
      'verification_code': 'Verified_By_Scan',
    });
  }

  // --- BANKING & SETTLEMENT LOGIC ---

  Future<bool> simulatePayment(int amount) async {
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  /// Updated Verification logic to include the Contract linkage
  Future<void> verifyAndPay(String clientPhone, String collectorPhone) async {
    final clientRef = _db.collection('users').doc(clientPhone);
    final collectorRef = _db.collection('users').doc(collectorPhone);

    await _db.runTransaction((transaction) async {
      final clientSnap = await transaction.get(clientRef);
      final collectorSnap = await transaction.get(collectorRef);

      if (!clientSnap.exists) throw 'Client not found';
      if (!collectorSnap.exists) throw 'Collector not found';

      final clientData = clientSnap.data() as Map<String, dynamic>;
      final String? activeContractId = clientData['active_contract_id'];

      // Step 1: Record the formal Pickup entry (The Diagram Link)
      await executePickupFlow(
        clientPhone,
        collectorPhone,
        activeContractId ?? "N/A",
      );

      // Step 2: Update Client Status
      transaction.update(clientRef, {
        'needsPickup': false,
        'lastCollection': FieldValue.serverTimestamp(),
      });

      // Step 3: Update Collector Metrics for Bank Credit Scoring
      transaction.update(collectorRef, {
        'lastCollectedClient': clientPhone,
        'lastCollectionAt': FieldValue.serverTimestamp(),
        // Increment earnings and success count
        'earnings': (collectorData(collectorSnap)['earnings'] ?? 0) + 250,
        'successPickups':
            (collectorData(collectorSnap)['successPickups'] ?? 0) + 1,
      });
    });
  }

  Future<void> requestUrgentPickup(
    String clientPhone,
    String collectorPhone,
  ) async {
    final clientRef = _db.collection('users').doc(clientPhone);
    final collectorRef = _db.collection('users').doc(collectorPhone);

    await _db.runTransaction((transaction) async {
      final clientSnap = await transaction.get(clientRef);
      final collectorSnap = await transaction.get(collectorRef);

      if (!clientSnap.exists) throw 'Client not found';
      if (!collectorSnap.exists) throw 'Collector not found';

      transaction.update(clientRef, {
        'needsPickup': true,
        'urgentPickupRequestedAt': FieldValue.serverTimestamp(),
        'assignedCollector': collectorPhone,
      });

      transaction.update(collectorRef, {
        'currentUrgentClient': clientPhone,
        'urgentAssignedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // Helper to handle data casting safely
  Map<String, dynamic> collectorData(DocumentSnapshot snap) =>
      snap.data() as Map<String, dynamic>;

  Future<void> processOneTimePayment(String phone, int i, String s) async {}
}
