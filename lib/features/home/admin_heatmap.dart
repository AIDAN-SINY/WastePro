import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminHeatmapScreen extends StatefulWidget {
  const AdminHeatmapScreen({super.key});

  @override
  State<AdminHeatmapScreen> createState() => _AdminHeatmapScreenState();
}

class _AdminHeatmapScreenState extends State<AdminHeatmapScreen> {
  Set<Circle> _heatCircles = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHeatmapData();
  }

  // BANK RESEARCH LOGIC: Fetch subscribed households to visualize "Financial Heat"
  void _loadHeatmapData() {
    FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'client')
        .where('isSubscribed', isEqualTo: true) // Only show paying customers
        .snapshots()
        .listen((snapshot) {
      Set<Circle> newCircles = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['latitude'] != null && data['longitude'] != null) {
          // We create a "Heat Point" using a semi-transparent circle
          newCircles.add(
            Circle(
              circleId: CircleId(doc.id),
              center: LatLng(data['latitude'], data['longitude']),
              radius: 300, // 300 meters radius
              fillColor: Colors.red.withValues(alpha: 0.3), // The "Heat" color
              strokeWidth: 0,
            ),
          );
        }
      }

      setState(() {
        _heatCircles = newCircles;
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Financial Penetration Map"),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(3.8480, 11.5021), // Yaoundé
              zoom: 12,
            ),
            circles: _heatCircles,
            myLocationEnabled: true,
          ),
          
          // --- RESEARCH LEGEND ---
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 5)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("LEGEND", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 5),
                  _legendItem(Colors.red.withValues(alpha: 0.6), "High Subscription Density"),
                  _legendItem(Colors.orange.withValues(alpha: 0.4), "Medium Activity"),
                  _legendItem(Colors.blue.withValues(alpha: 0.3), "Emerging Market"),
                ],
              ),
            ),
          ),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      children: [
        Container(width: 15, height: 15, color: color),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 10)),
      ],
    );
  }
}