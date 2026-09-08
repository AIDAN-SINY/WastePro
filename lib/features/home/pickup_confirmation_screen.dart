import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../providers/user_provider.dart';
import '../../services/tournee_service.dart';
import '../../services/notification_service.dart';
import '../backoffice/theme.dart';

// Client-dashboard-style color aliases (matching client_dashboard.dart).
const dBg = Color(0xFFF6F4EE);
const dSurface = Color(0xFFFFFFFF);
const dBorder = Color(0xFFEAE5D8);
const dText = Color(0xFF182620);
const dMuted = Color(0xFF7C8A80);
const dGreen = Color(0xFF0F3D2E);
const dGreenSoft = Color(0xFFE7EFE9);
const dGold = Color(0xFFE8A33D);
const dGoldSoft = Color(0xFFFBEDD6);
const dRed = Color(0xFFC1443D);
const dRedSoft = Color(0xFFF8E4E2);

/// Screen shown to the client when they tap the “validate your pickup”
/// notification sent right after the collector taps Done.
///
/// The screen shows the pickup information encoded in a QR code together with
/// two actions:
///  - **Scan code**: plays an animated green scan line over the QR code, then
///    shows a tick — the pickup becomes `verified` and the collector is
///    notified (“Pickup validated from client …”).
///  - **The pickup didn't occur**: lets the client dispute the pickup (which
///    creates an issue for the agency).
class PickupConfirmationScreen extends StatefulWidget {
  const PickupConfirmationScreen({
    super.key,
    FirebaseFirestore? db,
    required this.pickupId,
  }) : _db = db;

  /// Optional Firestore instance for testing.
  final FirebaseFirestore? _db;

  /// The pickup document ID from the notification data.
  final String pickupId;

  @override
  State<PickupConfirmationScreen> createState() =>
      _PickupConfirmationScreenState();
}

const _disputeOptionsList = [
  ('Missed collection', 'The collector did not come'),
  ('Overflowing bin', 'Bin was not emptied'),
  ('Wrong weight', 'Weight seems incorrect'),
  ('Damaged bin', 'Bin was damaged'),
  ('Did not happen', 'No collection took place'),
  ('Other', 'Something else'),
];

class _PickupConfirmationScreenState extends State<PickupConfirmationScreen>
    with SingleTickerProviderStateMixin {
  FirebaseFirestore get _db => widget._db ?? FirebaseFirestore.instance;

  TourneeService get _tourneeService => TourneeService(db: _db);
  NotificationService get _notificationService => NotificationService(db: _db);

  String? _loadedPickupId;
  Map<String, dynamic>? _pickupData;
  bool _loading = true;
  String? _error;

  // Validation state: 'idle' → 'scanning' → 'validated'
  String _phase = 'idle';

  // Animated green scan line over the QR code.
  late final AnimationController _scanCtrl;
  Timer? _scanTimer;

  // Dispute flow
  String? _disputeSelected;
  final _disputeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _loadPickup();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _scanCtrl.dispose();
    _disputeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPickup() async {
    try {
      final user = Provider.of<UserProvider>(context, listen: false).user;

      // Resolve the pickup document: either the id passed in the notification
      // (which may point at a notification doc rather than the pickup) or the
      // latest pending pickup of this client.
      DocumentSnapshot<Map<String, dynamic>>? doc;
      if (widget.pickupId.isNotEmpty) {
        final byId = await _db.collection('pickups').doc(widget.pickupId).get();
        final d = byId.data();
        if (d != null && d['status'] == 'pending_client_confirmation') {
          doc = byId;
        }
      }
      doc ??= await _latestPendingFor(user?.phoneNumber ?? '');

      if (!mounted) return;
      if (doc == null) {
        setState(() {
          _error = user == null
              ? 'You must be logged in.'
              : 'No pickup is waiting for your validation.';
          _loading = false;
        });
        return;
      }
      final resolved = doc;

      final data = resolved.data();
      if (data == null) {
        setState(() {
          _error = 'This pickup is no longer pending validation.';
          _loading = false;
        });
        return;
      }

      // Already validated earlier (e.g. from another device / repeated tap).
      if (data['status'] == 'verified') {
        setState(() {
          _pickupData = data;
          _loadedPickupId = resolved.id;
          _phase = 'validated';
          _loading = false;
        });
        return;
      }
      if (data['status'] != 'pending_client_confirmation') {
        setState(() {
          _error = 'This pickup is no longer pending validation.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _pickupData = data;
        _loadedPickupId = resolved.id;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load pickup details.';
        _loading = false;
      });
    }
  }

  /// Latest `pending_client_confirmation` pickup for [phone], if any.
  Future<DocumentSnapshot<Map<String, dynamic>>?> _latestPendingFor(
    String phone,
  ) async {
    if (phone.isEmpty) return null;
    final q = await _db
        .collection('pickups')
        .where('client_id', isEqualTo: phone)
        .where('status', isEqualTo: 'pending_client_confirmation')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    return q.docs.isEmpty ? null : q.docs.first;
  }

  /// The pickup information encoded inside the QR code.
  String get _qrPayload {
    final d = _pickupData ?? const <String, dynamic>{};
    final clientPhone = d['client_id'] as String? ?? '';
    final collectorName = d['collector_name'] as String? ?? '';
    final poids = (d['poids'] as num?)?.toDouble() ?? 0;
    final date = d['date'] as String? ?? '';
    return 'WastePro|pickup=${_loadedPickupId ?? ''}'
        '|client=$clientPhone|collector=$collectorName'
        '|poids=${poids.toStringAsFixed(1)}kg|date=$date';
  }

  /// Starts the animated “scan” of the QR code, then validates the pickup.
  void _startScan() {
    if (_phase != 'idle' || _loadedPickupId == null) return;
    setState(() => _phase = 'scanning');
    _scanCtrl.repeat(reverse: true); // green line moves to and fro
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(milliseconds: 2600), _completeScan);
  }

  /// Fired when the scan animation finishes: displays the tick and records
  /// the validation (pickup → verified, collector + client notified).
  Future<void> _completeScan() async {
    if (!mounted || _phase != 'scanning') return;
    _scanTimer?.cancel();
    _scanCtrl.stop();
    final pickupId = _loadedPickupId;
    if (pickupId == null) {
      setState(() => _phase = 'idle');
      return;
    }

    final d = _pickupData ?? const <String, dynamic>{};
    final poids = (d['poids'] as num?)?.toDouble() ?? 0;
    final date = d['date'] as String? ?? '';
    final clientPhone = d['client_id'] as String? ?? '';
    final client = Provider.of<UserProvider>(context, listen: false).user;
    final clientName = client?.fullName ?? clientPhone;
    final collectorName = d['collector_name'] as String? ?? 'Collector';
    final collectorId = d['collector_id'] as String? ?? '';

    try {
      await _tourneeService.confirmPickup(pickupId);

      // Confirmation message to the client.
      if (client != null) {
        await _notificationService.sendPickupConfirmed(
          phone: client.phoneNumber,
          clientName: clientName,
          collectorName: collectorName,
          poids: poids,
          date: date,
        );
      }

      // “Pickup validated from client …” notification for the collector.
      if (collectorId.isNotEmpty) {
        await _notificationService.sendPickupValidatedToCollector(
          collectorId: collectorId,
          pickupId: pickupId,
          clientName: clientName,
          clientPhone: clientPhone,
          poids: poids,
          date: date,
        );
      }

      if (!mounted) return;
      setState(() => _phase = 'validated');
    } catch (e) {
      debugPrint('[PickupValidation] Failed to validate pickup: $e');
      if (!mounted) return;
      setState(() => _phase = 'idle');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not validate the pickup. Please try again.'),
        ),
      );
    }
  }

  /// Show the dispute reason selector.
  void _showDisputeDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DisputeSheet(
        selected: _disputeSelected,
        onSelect: (label) {
          setState(() => _disputeSelected = label);
        },
        onDone: () => Navigator.of(context).pop(),
        onReport: () {
          Navigator.of(context).pop();
          _dispute();
        },
      ),
    );
  }

  Future<void> _dispute() async {
    if (_loadedPickupId == null || _loadedPickupId!.isEmpty) return;
    if (_disputeSelected == null) {
      _showDisputeDialog();
      return;
    }

    final desc = _disputeCtrl.text.trim();
    final client = Provider.of<UserProvider>(context, listen: false).user;
    if (client == null) return;

    try {
      await _tourneeService.disputePickup(
        pickupId: _loadedPickupId!,
        clientPhone: client.phoneNumber,
        clientName: client.fullName,
        category: _disputeSelected!,
        description: desc.isNotEmpty ? desc : 'Client reported an issue with this pickup.',
      );

      // Notify the client.
      await _notificationService.sendPickupDisputed(
        phone: client.phoneNumber,
        clientName: client.fullName,
        collectorName: _pickupData!['collector_name'] as String? ?? 'Collector',
        reason: _disputeSelected!,
        date: _pickupData!['date'] as String? ?? '',
      );

      if (!mounted) return;
      _showResult(true, 'Your report has been submitted. The agency will review it.');
    } catch (e) {
      if (!mounted) return;
      _showResult(false, 'Could not submit your report. Please try again.');
    }
  }

  void _showResult(bool success, [String msg = '']) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: success ? BackofficeTheme.greenSoft : BackofficeTheme.redSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error_outline,
              color: success ? BackofficeTheme.success : BackofficeTheme.red,
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              success ? 'Done!' : 'Something went wrong',
              style: BackofficeTheme.sora(
                16,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          msg.isNotEmpty
              ? msg
              : (success ? 'Pickup validated.' : 'Please try again.'),
          style: BackofficeTheme.inter(
            13,
            color: Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: BackofficeTheme.inter(
                13,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ).then((_) {
      Navigator.of(context).pop(); // Return to previous screen
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dBg,
      appBar: AppBar(
        backgroundColor: dBg,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: dGreen),
        ),
        title: Text(
          'Validate Pickup',
          style: BackofficeTheme.sora(
            17,
            color: dText,
            weight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: dGreen))
          : _error != null
              ? _errorState()
              : _pickupData != null
                  ? _pickupDetails()
                  : const SizedBox.shrink(),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: dRed),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: BackofficeTheme.inter(
                14,
                color: dMuted,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loadPickup,
              style: FilledButton.styleFrom(backgroundColor: dGreen),
              child: Text(
                'Retry',
                style: BackofficeTheme.sora(
                  14,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickupDetails() {
    final d = _pickupData!;
    final poids = (d['poids'] as num?)?.toDouble() ?? 0;
    final collector = d['collector_name'] as String? ?? 'Collector';
    final comment = d['commentaire'] as String? ?? '';
    final heureArrivee = d['heure_arrivee'] as String? ?? '';
    final heureDepart = d['heure_depart'] as String? ?? '';

    final validated = _phase == 'validated';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Collector info card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: dGreenSoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: dGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_pin_circle_outlined, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        collector,
                        style: BackofficeTheme.sora(
                          15,
                          weight: FontWeight.w600,
                          color: dText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.check_circle, size: 12, color: dGreen),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Collected your waste today',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: dMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Weight card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: dSurface,
              border: Border.all(color: dBorder),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: dGoldSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.monitor_weight_outlined, color: dGold, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weight collected',
                        style: TextStyle(fontSize: 11, color: dMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        poids > 0 ? '${poids.toStringAsFixed(1)} kg' : '—',
                        style: BackofficeTheme.sora(
                          20,
                          weight: FontWeight.w700,
                          color: dText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: dSurface,
                border: Border.all(color: dBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note_outlined, size: 16, color: dMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Collector note',
                          style: TextStyle(fontSize: 10.5, color: dMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          comment,
                          style: BackofficeTheme.inter(
                            12.5,
                            color: dText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (heureArrivee.isNotEmpty || heureDepart.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: dSurface,
                border: Border.all(color: dBorder),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: dMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Times',
                          style: TextStyle(fontSize: 10.5, color: dMuted),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Arrival: ${heureArrivee.isNotEmpty ? heureArrivee : "—"}  ·  Departure: ${heureDepart.isNotEmpty ? heureDepart : "—"}',
                          style: BackofficeTheme.inter(
                            12.5,
                            color: dText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 22),

          // -----------------------------------------------------------------
          // QR code validation panel
          // -----------------------------------------------------------------
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: dSurface,
              border: Border.all(color: dBorder),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Text(
                  validated
                      ? 'Pickup validated'
                      : 'Did this pickup really happen?',
                  style: BackofficeTheme.sora(
                    14,
                    weight: FontWeight.w700,
                    color: validated ? BackofficeTheme.success : dText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  validated
                      ? 'The collector has been notified. Thank you!'
                      : 'Scan the QR code below to validate the pickup',
                  textAlign: TextAlign.center,
                  style: BackofficeTheme.inter(11.5, color: dMuted),
                ),
                const SizedBox(height: 16),
                _QrScanBox(
                  payload: _qrPayload,
                  phase: _phase,
                  scanCtrl: _scanCtrl,
                ),
                if (!validated) ...[
                  const SizedBox(height: 10),
                  Text(
                    'This code contains the pickup information (client, collector, weight, date).',
                    textAlign: TextAlign.center,
                    style: BackofficeTheme.inter(10, color: dMuted),
                  ),
                ],
                const SizedBox(height: 16),

                if (validated)
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: dGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Done',
                          style: BackofficeTheme.sora(
                            15,
                            weight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_phase == 'scanning')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: dGreen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Scanning the QR code…',
                        style: BackofficeTheme.inter(
                          13,
                          color: dMuted,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else ...[
                  // Scan code — main validation action
                  FilledButton.icon(
                    onPressed: _startScan,
                    style: FilledButton.styleFrom(
                      backgroundColor: dGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 19),
                    label: Text(
                      'Scan code',
                      style: BackofficeTheme.sora(
                        15,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Dispute — the pickup did not occur
                  OutlinedButton(
                    onPressed: _dispute,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: dRed, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.report, color: dRed, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            "The pickup didn't occur",
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: BackofficeTheme.sora(
                              13.5,
                              weight: FontWeight.w600,
                              color: dRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (!validated) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: BackofficeTheme.inter(
                        13,
                        color: dMuted,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// QR code box with an animated green scan line (idle / scanning) and a tick
/// overlay once the pickup has been validated.
class _QrScanBox extends StatelessWidget {
  const _QrScanBox({
    required this.payload,
    required this.phase,
    required this.scanCtrl,
  });

  final String payload;
  final String phase; // 'idle' | 'scanning' | 'validated'
  final AnimationController scanCtrl;

  @override
  Widget build(BuildContext context) {
    final scanning = phase == 'scanning';
    final validated = phase == 'validated';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: validated
              ? BackofficeTheme.success
              : scanning
                  ? dGold
                  : dBorder,
          width: 1.5,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: QrImageView(
              data: payload,
              version: QrVersions.auto,
              size: 200,
              gapless: false,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: dGreen,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: dText,
              ),
            ),
          ),
          // Animated green scan line moving to and fro.
          if (scanning)
            AnimatedBuilder(
              animation: scanCtrl,
              builder: (context, _) {
                return Positioned(
                  left: 16,
                  right: 16,
                  top: 14 + scanCtrl.value * 172,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: BackofficeTheme.success,
                      boxShadow: const [
                        BoxShadow(
                          color: BackofficeTheme.success,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          // Tick overlay once scanning finishes.
          if (validated)
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x330F3D2E),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 64,
                color: BackofficeTheme.success,
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom sheet for choosing a dispute reason.
class _DisputeSheet extends StatefulWidget {
  const _DisputeSheet({
    required this.selected,
    required this.onSelect,
    required this.onDone,
    required this.onReport,
  });

  final String? selected;
  final ValueChanged<String> onSelect;

  /// Closes the sheet without reporting (Cancel).
  final VoidCallback onDone;

  /// Submits the dispute with the currently selected reason.
  final VoidCallback onReport;

  @override
  State<_DisputeSheet> createState() => _DisputeSheetState();
}

class _DisputeSheetState extends State<_DisputeSheet> {
  late TextEditingController _descCtrl;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController();
    _selected = widget.selected;
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.report, color: dRed, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "The pickup didn't occur",
                  maxLines: 2,
                  style: BackofficeTheme.sora(
                    15,
                    weight: FontWeight.w700,
                    color: dText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Why are you disputing this pickup?',
            style: TextStyle(fontSize: 11.5, color: dMuted),
          ),
          const SizedBox(height: 16),
          // Option chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, _) in _disputeOptionsList)
                ChoiceChip(
                  label: Text(
                    label,
                    style: BackofficeTheme.inter(
                      12.5,
                      weight: FontWeight.w600,
                    ),
                  ),
                  selected: _selected == label,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selected = label);
                      widget.onSelect(label);
                    }
                  },
                  selectedColor: dRedSoft,
                  selectedShadowColor: Colors.transparent,
                  labelStyle: BackofficeTheme.inter(
                    12.5,
                    weight: FontWeight.w600,
                    color: _selected == label ? dRed : dText,
                  ),
                  checkmarkColor: dRed,
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Description
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add details (optional)',
              hintStyle: TextStyle(fontSize: 12.5, color: dMuted),
              filled: true,
              fillColor: dSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onDone,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Cancel',
                    style: BackofficeTheme.sora(
                      13.5,
                      weight: FontWeight.w600,
                      color: dMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: widget.onReport,
                  style: FilledButton.styleFrom(
                    backgroundColor: dRed,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Report issue',
                    style: BackofficeTheme.sora(
                      13.5,
                      weight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
