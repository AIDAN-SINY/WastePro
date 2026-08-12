import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/notification_model.dart';

/// Écran « Notifications » du dashboard client — liste les notifications
/// in-app reçues (décisions du chef d'agence sur la candidature, futures
/// notifications produit…).
///
/// Ouvert depuis la cloche du dashboard : les notifications sont marquées
/// comme lues à l'ouverture (le badge de la cloche disparaît).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    FirebaseFirestore? db,
    required this.phone,
  }) : _db = db;

  /// Base injectée par les tests ; sinon l'instance par défaut.
  final FirebaseFirestore? _db;

  /// Numéro de téléphone du client connecté (canonique).
  final String phone;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  FirebaseFirestore get _db => widget._db ?? FirebaseFirestore.instance;

  // Palette du dashboard client (fond clair).
  static const Color dBg = Color(0xFFF6F4EE);
  static const Color dSurface = Color(0xFFFFFFFF);
  static const Color dBorder = Color(0xFFEAE5D8);
  static const Color dText = Color(0xFF182620);
  static const Color dMuted = Color(0xFF7C8A80);
  static const Color dGreen = Color(0xFF0F3D2E);
  static const Color dGreenSoft = Color(0xFFE7EFE9);
  static const Color dRed = Color(0xFFC1443D);

  @override
  void initState() {
    super.initState();
    // Marque tout comme lu à l'ouverture (fire-and-forget).
    _markAllRead();
  }

  Future<void> _markAllRead() async {
    try {
      final snap = await _db
          .collection('notifications')
          .where('phone', isEqualTo: widget.phone)
          .get();
      final unread = snap.docs.where(
        (d) => (d.data()['read'] as bool? ?? false) != true,
      );
      if (unread.isEmpty) return;
      final batch = _db.batch();
      for (final doc in unread) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (_) {
      // Silencieux : un échec de lecture ne doit pas bloquer l'écran.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dBg,
      appBar: AppBar(
        backgroundColor: dBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, color: dGreen),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.sora(
            color: dText,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _db
              .collection('notifications')
              .where('phone', isEqualTo: widget.phone)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(
                child: Text(
                  'Could not load notifications.',
                  style: TextStyle(color: dMuted),
                ),
              );
            }
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data?.docs ?? const [];
            if (docs.isEmpty) return _emptyState();
            final items = docs.map(
              (d) => NotificationModel.fromMap(d.id, d.data()),
            ).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _item(items[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: dGreenSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 32,
              color: dGreen,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: GoogleFonts.sora(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: dText,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'You will be notified here when something needs your attention.',
            textAlign: TextAlign.center,
            style: TextStyle(color: dMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _item(NotificationModel n) {
    final approved = n.type == 'approved';
    final iconColor = approved ? dGreen : dRed;
    final iconBg = approved ? dGreenSoft : dRed.withValues(alpha: 0.1);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dSurface,
        border: Border.all(color: dBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(
              approved ? Icons.check_rounded : Icons.close_rounded,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        n.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: dText,
                        ),
                      ),
                    ),
                    Text(
                      n.createdAt,
                      style: const TextStyle(fontSize: 10.5, color: dMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  n.message,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: dMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
