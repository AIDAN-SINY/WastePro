import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../services/live_tracking_service.dart';
import '../theme.dart';

/// Full-screen Leaflet map showing all active collectors in real time.
/// Accessible from the Agency Manager backoffice sidebar.
class BoTrackingPage extends StatefulWidget {
  const BoTrackingPage({super.key, this.store});

  /// Injected store — not strictly needed, but kept for consistency.
  final dynamic store;

  @override
  State<BoTrackingPage> createState() => _BoTrackingPageState();
}

class _BoTrackingPageState extends State<BoTrackingPage> {
  final LiveTrackingService _trackingService = LiveTrackingService();
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _collectors = [];
  bool _loading = true;
  String? _selectedCollectorId;

  // Default center: Yaoundé
  static const LatLng _defaultCenter = LatLng(3.8480, 11.5021);

  @override
  void initState() {
    super.initState();
    _listenToCollectors();
  }

  void _listenToCollectors() {
    _trackingService.watchAllCollectors().listen((collectors) {
      if (!mounted) return;
      setState(() {
        _collectors = collectors;
        _loading = false;
      });

      // Auto-fit map bounds when we have collectors.
      if (collectors.isNotEmpty) {
        _fitBounds(collectors);
      }
    });
  }

  void _fitBounds(List<Map<String, dynamic>> collectors) {
    if (collectors.isEmpty) return;
    final points = collectors
        .map((c) =>
            LatLng(c['latitude'] as double, c['longitude'] as double))
        .toList();
    if (points.length == 1) {
      _mapController.move(points.first, 15);
    } else {
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(60),
        ),
      );
    }
  }

  @override
  void dispose() {
    _trackingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BackofficeTheme.bg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: BackofficeTheme.green,
                    ),
                  )
                : _buildMap(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final activeCount =
        _collectors.where((c) => c['isTracking'] == true).length;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        color: BackofficeTheme.surface,
        border: Border(bottom: BorderSide(color: BackofficeTheme.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: BackofficeTheme.greenSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.map_outlined,
              color: BackofficeTheme.green,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Collector Tracking',
                  style: BackofficeTheme.sora(16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '$activeCount of ${_collectors.length} collectors active',
                  style: BackofficeTheme.inter(
                    12,
                    color: BackofficeTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          // Refresh button
          Material(
            color: BackofficeTheme.bg,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => _fitBounds(_collectors),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.center_focus_strong,
                  size: 20,
                  color: BackofficeTheme.green,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    final center =
        _collectors.isNotEmpty
            ? LatLng(
                _collectors.first['latitude'] as double,
                _collectors.first['longitude'] as double,
              )
            : _defaultCenter;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.proprie237.waste_pro',
            ),
            MarkerLayer(
              markers: [
                for (final c in _collectors)
                  _buildCollectorMarker(c),
              ],
            ),
          ],
        ),
        // Collector list panel
        Positioned(
          left: 12,
          bottom: 12,
          child: _buildCollectorList(),
        ),
        // Selected collector detail card
        if (_selectedCollectorId != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _buildCollectorDetail(),
          ),
      ],
    );
  }

  Marker _buildCollectorMarker(Map<String, dynamic> collector) {
    final lat = collector['latitude'] as double;
    final lng = collector['longitude'] as double;
    final name = collector['name'] as String;
    final isActive = collector['isTracking'] as bool;
    final id = collector['id'] as String;
    final isSelected = _selectedCollectorId == id;

    final initials = name
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0])
        .take(2)
        .join()
        .toUpperCase();

    return Marker(
      point: LatLng(lat, lng),
      width: isSelected ? 52 : 44,
      height: isSelected ? 52 : 44,
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedCollectorId = isSelected ? null : id);
          _mapController.move(LatLng(lat, lng), 16);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: isActive ? BackofficeTheme.green : BackofficeTheme.muted,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: isSelected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: isSelected ? 10 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Text(
              initials.isNotEmpty ? initials : '?',
              style: BackofficeTheme.sora(
                isSelected ? 16 : 14,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollectorList() {
    if (_collectors.isEmpty) return const SizedBox.shrink();

    return Container(
      width: 180,
      constraints: BoxConstraints(
        maxHeight: math.min(200.0, _collectors.length * 48.0 + 40),
      ),
      decoration: BoxDecoration(
        color: BackofficeTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BackofficeTheme.border),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(
              'Collectors (${_collectors.length})',
              style: BackofficeTheme.sora(12, weight: FontWeight.w700),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: _collectors.length,
              itemBuilder: (context, index) {
                final c = _collectors[index];
                final name = c['name'] as String;
                final isActive = c['isTracking'] as bool;
                final id = c['id'] as String;
                return ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  leading: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? BackofficeTheme.success : BackofficeTheme.muted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BackofficeTheme.inter(11, weight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isActive ? 'Active' : 'Offline',
                    style: BackofficeTheme.inter(9, color: BackofficeTheme.muted),
                  ),
                  onTap: () {
                    final lat = c['latitude'] as double;
                    final lng = c['longitude'] as double;
                    setState(() => _selectedCollectorId = id);
                    _mapController.move(LatLng(lat, lng), 16);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectorDetail() {
    final collector = _collectors.firstWhere(
      (c) => c['id'] == _selectedCollectorId,
      orElse: () => {},
    );
    if (collector.isEmpty) return const SizedBox.shrink();

    final name = collector['name'] as String;
    final isActive = collector['isTracking'] as bool;
    final speed = collector['speed'] as double;
    final lastUpdate = collector['lastPositionUpdate'];

    String lastUpdateText = 'Unknown';
    if (lastUpdate != null && lastUpdate is DateTime) {
      final diff = DateTime.now().difference(lastUpdate);
      if (diff.inMinutes < 1) {
        lastUpdateText = 'Just now';
      } else if (diff.inMinutes < 60) {
        lastUpdateText = '${diff.inMinutes} min ago';
      } else {
        lastUpdateText = '${diff.inHours}h ago';
      }
    } else if (lastUpdate != null && lastUpdate is Timestamp) {
      final diff = DateTime.now().difference(lastUpdate.toDate());
      if (diff.inMinutes < 1) {
        lastUpdateText = 'Just now';
      } else if (diff.inMinutes < 60) {
        lastUpdateText = '${diff.inMinutes} min ago';
      } else {
        lastUpdateText = '${diff.inHours}h ago';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BackofficeTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BackofficeTheme.border),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isActive ? BackofficeTheme.greenSoft : BackofficeTheme.graySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  size: 18,
                  color: isActive ? BackofficeTheme.green : BackofficeTheme.muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: BackofficeTheme.sora(13, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isActive ? 'Active · $lastUpdateText' : 'Offline',
                      style: BackofficeTheme.inter(
                        11,
                        color: isActive ? BackofficeTheme.success : BackofficeTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (speed > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: BackofficeTheme.greenSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(speed * 3.6).toStringAsFixed(0)} km/h',
                    style: BackofficeTheme.inter(
                      10,
                      weight: FontWeight.w600,
                      color: BackofficeTheme.green,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _selectedCollectorId = null),
                child: const Icon(
                  Icons.close,
                  size: 18,
                  color: BackofficeTheme.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
