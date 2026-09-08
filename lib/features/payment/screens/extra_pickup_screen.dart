import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/config.dart';
import '../../../providers/user_provider.dart';
import 'checkout_screen.dart';

/// Collecte supplémentaire à la demande — payée via CamPay (Mobile Money).
class ExtraPickupScreen extends StatefulWidget {
  const ExtraPickupScreen({super.key, FirebaseFirestore? db}) : _db = db;

  final FirebaseFirestore? _db;

  /// Prix du forfait collecte supplémentaire (XAF).
  static const double price = 1000;

  @override
  State<ExtraPickupScreen> createState() => _ExtraPickupScreenState();
}

class _ExtraPickupScreenState extends State<ExtraPickupScreen> {
  // Design System Colors
  final Color dBg = const Color(0xFFF6F4EE);
  final Color dSurface = const Color(0xFFFFFFFF);
  final Color dGreen = const Color(0xFF0F3D2E);
  final Color dGold = const Color(0xFFE8A33D);
  final Color dMuted = const Color(0xFF7C8A80);
  final Color dBorder = const Color(0xFFEAE5D8);
  final Color dText = const Color(0xFF182620);
  final Color dGoldSoft = const Color(0xFFFBEDD6);

  FirebaseFirestore get _db => widget._db ?? FirebaseFirestore.instance;

  Future<void> _handlePay() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    if (user == null) return;

    // Navigate to the CheckoutScreen — handles Campay Mobile Money flow.
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(
          amount: ExtraPickupScreen.price,
          description: 'Extra pickup',
          txRefPrefix: 'PICKUP',
          onPaymentSuccess: () => _finalizePickup(
            phone: user.phoneNumber,
            collecteurId: user.collecteurId,
          ),
        ),
      ),
    );
  }

  /// Creates the pickup request after a confirmed payment.
  Future<void> _finalizePickup({
    required String phone,
    required String collecteurId,
  }) async {
    try {
      await _createPickupRequest(phone, collecteurId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Payment confirmed! Your extra pickup has been requested.',
          ),
          backgroundColor: dGreen,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _createPickupRequest(String phone, String collecteurId) async {
    final id = 'PKP-${DateTime.now().millisecondsSinceEpoch}';
    await _db.collection('pickups').doc(id).set({
      'pickup_id': id,
      'client_id': phone,
      'collector_id': collecteurId,
      'type': 'extra',
      'status': 'paid',
      'amount': ExtraPickupScreen.price,
      'currency': AppConfig.currency,
      'timestamp': FieldValue.serverTimestamp(),
    });
    try {
      await _db.collection('users').doc(phone).update({'needsPickup': true});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dBg,
      appBar: AppBar(
        title: Text(
          'Request Pickup',
          style: GoogleFonts.sora(
            fontWeight: FontWeight.w600,
            color: dGreen,
            fontSize: 16,
          ),
        ),
        backgroundColor: dSurface,
        elevation: 0,
        foregroundColor: dGreen,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero icon + title
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: dGoldSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.local_shipping_rounded,
                      color: dGold,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Need an extra pickup?',
                    style: GoogleFonts.sora(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: dText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Request a one-time collection outside your regular schedule.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: dMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Price card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: dSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: dBorder),
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
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: dGold,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Extra pickup (1 bag)',
                                style: GoogleFonts.sora(
                                  color: dText,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'One-time on-demand collection',
                                style: TextStyle(
                                  color: dMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${ExtraPickupScreen.price.toStringAsFixed(0)} XAF',
                          style: GoogleFonts.sora(
                            color: dGreen,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // What's included
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: dSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: dBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What\'s included',
                          style: GoogleFonts.sora(
                            color: dText,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _includedItem(Icons.check_circle_outline, '1 bag collected within 24 hours'),
                        const SizedBox(height: 8),
                        _includedItem(Icons.check_circle_outline, 'Assigned to your regular collector'),
                        const SizedBox(height: 8),
                        _includedItem(Icons.check_circle_outline, 'Secure payment via Mobile Money'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Pay button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _handlePay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: dGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'PAY & REQUEST PICKUP',
                        style: GoogleFonts.sora(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline, size: 13, color: dMuted),
                        const SizedBox(width: 5),
                        Text(
                          'Secure payment via CamPay',
                          style: TextStyle(color: dMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _includedItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: dGreen, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: dText, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}
