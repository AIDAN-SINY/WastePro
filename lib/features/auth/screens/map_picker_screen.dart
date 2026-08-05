import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // The Leaflet for Flutter
import 'package:latlong2/latlong.dart'; // Coordinates
import 'package:geocoding/geocoding.dart'; // Neighborhood lookup
import 'package:google_fonts/google_fonts.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng _currentCenter = const LatLng(3.8480, 11.5021); // Yaoundé
  String _address = "Move the map to your gate";
  final MapController _mapController = MapController();

  Future<void> _getAddress(LatLng point) async {
  setState(() => _address = "Locating neighborhood..."); // Visual feedback
  try {
    List<Placemark> placemarks = await placemarkFromCoordinates(point.latitude, point.longitude);
    if (placemarks.isNotEmpty) {
      Placemark place = placemarks[0];
      setState(() {
        // Professional Fallback Logic:
        // Try Neighborhood -> if empty try Street -> if empty try City
        _address = place.subLocality?.isNotEmpty == true 
            ? place.subLocality! 
            : (place.thoroughfare?.isNotEmpty == true ? place.thoroughfare! : place.locality ?? "Unknown Area");
      });
    }
  } catch (e) {
    debugPrint("GEO ERROR: $e");
    setState(() => _address = "Area Identified (${point.latitude.toStringAsFixed(2)})");
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Set Collection Point",
          style: GoogleFonts.poppins(fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // THE OPENSTREETMAP LAYER
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 16,
              onPositionChanged: (position, hasGesture) {
                if (position.center != null) {
                  _currentCenter = position.center!;
                  _getAddress(_currentCenter);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.waste_pro',
              ),
            ],
          ),

          // STATIC CENTER PIN
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40), // Adjust for pin tip
              child: Icon(Icons.location_on, color: Colors.red, size: 50),
            ),
          ),

          // TOP ADDRESS CARD
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
              ),
              child: Text(
                _address,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // CONFIRM BUTTON
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[800],
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: () {
                Navigator.pop(context, {
                  'location': _currentCenter,
                  'address': _address,
                });
              },
              child: const Text(
                "CONFIRM THIS POINT",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
