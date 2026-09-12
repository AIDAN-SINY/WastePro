import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config.dart';
import '../../../services/campay_service.dart';

/// Résultat rapporté par [PaymentWaitingScreen] via `Navigator.pop`.
class PaymentWaitingResult {
  const PaymentWaitingResult({required this.status, this.transaction});

  /// `successful` | `failed` | `cancelled`.
  final String status;

  /// Statut final CamPay (null si annulé par l'utilisateur).
  final CampayTransactionStatus? transaction;
}

/// Écran d'attente de confirmation — le client reçoit une invite USSD sur
/// son téléphone (MTN MoMo / Orange Money) et confirme avec son PIN.
///
/// L'écran interroge CamPay toutes les 3 s jusqu'à un état final
/// (SUCCESSFUL / FAILED), puis revient dans l'app avec [PaymentWaitingResult].
/// Un bouton « Annuler » referme l'écran sans charge (statut `cancelled`).
class PaymentWaitingScreen extends StatefulWidget {
  const PaymentWaitingScreen({
    super.key,
    required this.service,
    required this.reference,
    required this.amount,
    required this.currency,
    required this.ussdCode,
    required this.operator,
  });

  final CampayService service;
  final String reference;

  /// Montant affiché au client (déjà payé côté UI).
  final num amount;
  final String currency;

  /// Code USSD retourné par CamPay (ex. `*126#`).
  final String ussdCode;

  /// Opérateur détecté (`MTN` | `ORANGE`).
  final String operator;

  @override
  State<PaymentWaitingScreen> createState() => _PaymentWaitingScreenState();
}

class _PaymentWaitingScreenState extends State<PaymentWaitingScreen> {
  Timer? _timer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _poll();
    // Interrogation toutes les 3 secondes (convention du SDK officiel).
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_done) return;
    try {
      final status =
          await widget.service.getTransactionStatus(widget.reference);
      if (!mounted || _done) return;
      if (!status.isPending) {
        _finish(status.isSuccessful ? 'successful' : 'failed', status);
      }
    } catch (_) {
      // Erreur réseau transitoire : on retente au prochain tick.
    }
  }

  void _finish(String status, CampayTransactionStatus? transaction) {
    _done = true;
    _timer?.cancel();
    Navigator.of(context).pop(
      PaymentWaitingResult(status: status, transaction: transaction),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dGreen = const Color(0xFF0F3D2E);
    final dGold = const Color(0xFFD4A853);
    final dMuted = const Color(0xFF7C8A80);
    final dSurface = const Color(0xFFFFFFFF);
    final dBg = const Color(0xFFF5F7F6);

    return Scaffold(
      backgroundColor: dBg,
      appBar: AppBar(
        title: Text(
          'Confirm Payment',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: dGreen,
          ),
        ),
        backgroundColor: dSurface,
        elevation: 0,
        foregroundColor: dGreen,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: dGold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smartphone,
                color: Color(0xFFD4A853),
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Check your phone',
              style: GoogleFonts.sora(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: dGreen,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'CamPay sent a payment request to your phone. '
              'Dial the code below and confirm with your PIN.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 14, color: dMuted, height: 1.5),
            ),
            const SizedBox(height: 20),
            if (widget.ussdCode.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: dSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8EBE9)),
                ),
                child: Text(
                  widget.ussdCode,
                  style: GoogleFonts.sora(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: dGreen,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              '${widget.operator.isEmpty ? '' : '${widget.operator} · '}'
              '${widget.amount.toStringAsFixed(0)} ${widget.currency}',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: dMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (AppConfig.isCampayDemo) ...[ 
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: dGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Demo sandbox - CamPay charge is '
                  '${AppConfig.campayDemoMaxAmount.toStringAsFixed(0)} XAF '
                  '(plan price is display-only).',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: dMuted, fontSize: 11),
                ),
              ),
            ],
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: Color(0xFF0F3D2E)),
            const SizedBox(height: 16),
            Text(
              'Waiting for confirmation…',
              style: GoogleFonts.inter(fontSize: 13, color: dMuted),
            ),
            const SizedBox(height: 40),
            TextButton(
              onPressed: () => _finish('cancelled', null),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF7C8A80), fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
