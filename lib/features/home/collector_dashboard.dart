import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../services/subscription_service.dart';
import 'pickup_schedule_screen.dart';
import 'qr_scanner_screen.dart';

class CollectorDashboard extends StatefulWidget {
  const CollectorDashboard({super.key});

  @override
  State<CollectorDashboard> createState() => _CollectorDashboardState();
}

class _CollectorDashboardState extends State<CollectorDashboard> {
  bool _isOnline = false;
  Set<Marker> _markers = {};

  void _listenForPickups() {
    FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'client')
        .where('needsPickup', isEqualTo: true)
        .snapshots()
        .listen((snap) => _updateMarkers(snap.docs));
  }

  void _updateMarkers(List<DocumentSnapshot> docs) {
    Set<Marker> newMarkers = docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return Marker(
        markerId: MarkerId(doc.id),
        position: LatLng(data['latitude'], data['longitude']),
        infoWindow: InfoWindow(
          title: data['fullName'],
          snippet: data['phoneNumber'],
        ),
      );
    }).toSet();
    if (mounted) setState(() => _markers = newMarkers);
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.user!;
    // Using cast to avoid null errors in simulation
    final double earnings = (user.toMap()['earnings'] ?? 0.0).toDouble();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Operations Terminal"),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => userProvider.logout(),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- PERFORMANCE & FINTECH BAR ---
          // Inside the Column, above the Map or stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  side: const BorderSide(color: Colors.grey),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                icon: const Icon(
                  Icons.table_chart_outlined,
                  color: Colors.blue,
                ),
                label: const Text("VIEW WEEKLY SCHEDULE"),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PickupScheduleScreen(),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem(
                  "Earnings",
                  "\$${earnings.toStringAsFixed(2)}",
                  Colors.green,
                ),
                _statItem(
                  "Status",
                  _isOnline ? "Online" : "Offline",
                  _isOnline ? Colors.green : Colors.red,
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isOnline ? Colors.red : Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () {
                    setState(() => _isOnline = !_isOnline);
                    if (_isOnline) _listenForPickups();
                  },
                  child: Text(_isOnline ? "Go Offline" : "Go Online"),
                ),
              ],
            ),
          ),
          // --- MAP ---
          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(3.848, 11.5021),
                zoom: 12,
              ),
              markers: _markers,
              onMapCreated: (_) {},
            ),
          ),
        ],
      ),
      floatingActionButton: _isOnline
          ? FloatingActionButton.extended(
              backgroundColor: Colors.green,
              onPressed: () =>
                  _showVerificationMenu(user.phoneNumber, userProvider),
              label: const Text("Verify Work"),
              icon: const Icon(Icons.qr_code_scanner),
            )
          : null,
    );
  }

  // --- HELPERS ---
  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 16,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  void _showVerificationMenu(String collectorPhone, UserProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text("Scan QR Code"),
            onTap: () async {
              Navigator.pop(context);
              final res = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QRScannerScreen()),
              );
              if (res != null) _finalize(res, collectorPhone, provider);
            },
          ),
          ListTile(
            leading: const Icon(Icons.keyboard),
            title: const Text("Manual Entry (Rain)"),
            onTap: () {
              Navigator.pop(context);
              _showManualDialog(collectorPhone, provider);
            },
          ),
        ],
      ),
    );
  }

  void _finalize(
    String clientPhone,
    String collectorPhone,
    UserProvider provider,
  ) async {
    await SubscriptionService().verifyAndPay(clientPhone, collectorPhone);
    provider.refreshUser(collectorPhone);
  }

  void _showManualDialog(String collectorPhone, UserProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter Client Phone"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _finalize(controller.text.trim(), collectorPhone, provider);
            },
            child: const Text("Verify"),
          ),
        ],
      ),
    );
  }
}
