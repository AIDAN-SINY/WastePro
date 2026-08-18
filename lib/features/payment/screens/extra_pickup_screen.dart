import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/config.dart';
import '../../../providers/user_provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/payment_service.dart';

/// Collecte supplémentaire à la demande — payée via CamPay (Mobile Money).
///
/// L'utilisateur paie un forfait (1 000 XAF) pour une collecte en plus du
/// contrat : une transaction est enregistrée (`transactions`) et une
/// demande de collecte est créée (`pickups`) avec `needsPickup` sur le
/// profil client.
class ExtraPickupScreen extends StatefulWidget {
  const ExtraPickupScreen({super.key, FirebaseFirestore? db}) : _db = db;

  /// Base injectée par les tests ; sinon l'instance par défaut.
  final FirebaseFirestore? _db;

  /// Prix du forfait collecte supplémentaire (XAF).
  static const double price = 1000;

  @override
  State<ExtraPickupScreen> createState() => _ExtraPickupScreenState();
}

class _ExtraPickupScreenState extends State<ExtraPickupScreen> {
  bool _isProcessing = false;

  // Design System Colors
  final Color dBg = const Color(0xFFF5F7F6);
  final Color dSurface = const Color(0xFFFFFFFF);
  final Color dGreen = const Color(0xFF0F3D2E);
  final Color dGold = const Color(0xFFD4A853);
  final Color dMuted = const Color(0xFF7C8A80);
  final Color dBorder = const Color(0xFFE8EBE9);

  FirebaseFirestore get _db => widget._db ?? FirebaseFirestore.instance;

  Future<void> _handlePay() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    if (user == null) return;

    setState(() => _isProcessing = true);
    try {
      final result = await PaymentService(db: _db).charge(
        context: context,
        amount: ExtraPickupScreen.price,
        currency: AppConfig.currency,
        email: AuthService.emailFor(user.phoneNumber),
        phone: user.phoneNumber,
        name: user.fullName,
        title: 'Extra pickup',
        type: 'pickup',
        description: 'On-demand waste collection (1 bag)',
        txRefPrefix: 'PICKUP',
      );

      if (!mounted) return;
      if (result.success) {
        await _createPickupRequest(user.phoneNumber, user.collecteurId);
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment not completed — no charge was made.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Crée la demande de collecte supplémentaire et marque le client comme
  /// ayant besoin d'une collecte (visible côté collecteur/backoffice).
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
    } catch (_) {
      // Profil absent (legacy) : la demande de collecte suffit.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dBg,
      appBar: AppBar(
        title: Text(
          'Extra Pickup',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: dGreen,
          ),
        ),
        backgroundColor: dSurface,
        elevation: 0,
        foregroundColor: dGreen,
      ),
      body: _isProcessing
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F3D2E)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need an extra collection?',
                    style: GoogleFonts.sora(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: dGreen,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Request a one-time pickup outside your regular schedule. '
                    'Pay securely with MTN MoMo or Orange Money.',
                    style: GoogleFonts.inter(fontSize: 14, color: dMuted),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: dSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: dBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: dGold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.local_shipping_rounded,
                            color: Color(0xFFD4A853),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Extra pickup (1 bag)',
                                style: GoogleFonts.sora(
                                  color: dGreen,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'One-time collection, on demand',
                                style: GoogleFonts.inter(
                                  color: dMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${ExtraPickupScreen.price.toStringAsFixed(0)} XAF',
                          style: GoogleFonts.sora(
                            color: dGreen,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _handlePay,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: dGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'PAY AND REQUEST',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 14, color: dMuted),
                        const SizedBox(width: 6),
                        Text(
                          'Secure checkout via CamPay (MTN MoMo / Orange Money)',
                          style: GoogleFonts.inter(
                            color: dMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (AppConfig.isCampayDemo) ...[ 
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: dGold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Demo mode — CamPay sandbox caps payments at '
                        '${AppConfig.campayDemoMaxAmount.toStringAsFixed(0)} XAF. '
                        'Real price applies in production.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: dMuted, fontSize: 11, height: 1.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
