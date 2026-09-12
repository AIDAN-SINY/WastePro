import 'dart:async';

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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  @override
  void initState() {
    super.initState();
    _loadHeatmapData();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _loadHeatmapData() {
    // Avoid composite index: filter isSubscribed client-side.
    _sub = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'client')
        .snapshots()
        .listen((snapshot) {
      final newCircles = <Circle>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['isSubscribed'] != true) continue;
        final lat = data['latitude'];
        final lng = data['longitude'];
        if (lat is! num || lng is! num) continue;

        newCircles.add(
          Circle(
            circleId: CircleId(doc.id),
            center: LatLng(lat.toDouble(), lng.toDouble()),
            radius: 300,
            fillColor: Colors.red.withValues(alpha: 0.3),
            strokeWidth: 0,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _heatCircles = newCircles;
        _isLoading = false;
      });
    }, onError: (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Penetration Map'),
        backgroundColor: Colors.indigo[900],
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(3.8480, 11.5021),
              zoom: 12,
            ),
            circles: _heatCircles,
            myLocationEnabled: true,
          ),
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 5),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LEGEND',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  _legendItem(
                    Colors.red.withValues(alpha: 0.6),
                    'High Subscription Density',
                  ),
                  _legendItem(
                    Colors.orange.withValues(alpha: 0.4),
                    'Medium Activity',
                  ),
                  _legendItem(
                    Colors.blue.withValues(alpha: 0.3),
                    'Emerging Market',
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
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
