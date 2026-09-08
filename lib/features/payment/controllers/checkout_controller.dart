import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_provider.dart';
import '../../../services/campay_api_service.dart';

/// Modes de paiement disponibles.
enum PaymentMethod {
  /// Orange Money Cameroun.
  orangeMoney,

  /// MTN Mobile Money.
  mtnMomo,

  /// Credit / Debit card.
  creditCard,

  /// Cash payment (paid on collection).
  cash,
}

/// Extension pour le label affiché dans l'UI.
extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.orangeMoney => 'Orange Money',
        PaymentMethod.mtnMomo => 'MTN Mobile Money',
        PaymentMethod.creditCard => 'Credit Card',
        PaymentMethod.cash => 'Cash',
      };

  String get shortLabel => switch (this) {
        PaymentMethod.orangeMoney => 'Orange Money',
        PaymentMethod.mtnMomo => 'MTN MoMo',
        PaymentMethod.creditCard => 'Card',
        PaymentMethod.cash => 'Cash',
      };

  IconData get icon => switch (this) {
        PaymentMethod.orangeMoney => Icons.phone_iphone,
        PaymentMethod.mtnMomo => Icons.phone_iphone,
        PaymentMethod.creditCard => Icons.credit_card,
        PaymentMethod.cash => Icons.money,
      };

  /// Whether this method requires the Campay / USSD flow.
  bool get requiresMobileMoney => switch (this) {
        PaymentMethod.orangeMoney || PaymentMethod.mtnMomo => true,
        PaymentMethod.creditCard || PaymentMethod.cash => false,
      };
}

/// Contrôleur GetX gérant le flux de paiement Mobile Money (MTN MoMo /
/// Orange Money) via l'API REST Campay.
///
/// Flux :
/// 1. Valider le numéro → obtenir le token
/// 2. Envoyer la demande de paiement (sans PIN)
/// 3. Afficher le champ PIN dans l'app
/// 4. Soumettre le PIN → confirmer le paiement
/// 5. Poll jusqu'à confirmation ou échec
class CheckoutController extends GetxController {
  CheckoutController({
    required this.amount,
    required this.description,
    this.externalReference,
    this.txRefPrefix = 'WP',
    CampayApiService? service,
    this.onPaymentSuccess,
  }) : _service = service ?? CampayApiService();

  /// Montant à payer (XAF).
  final num amount;

  /// Description de la transaction (affichée dans le journal Campay).
  final String description;

  /// Référence externe optionnelle (sinon générée automatiquement).
  final String? externalReference;

  /// Préfixe de la référence externe (ex. `WP`, `PICKUP`).
  final String txRefPrefix;

  /// Callback appelé lorsque le paiement est confirmé avec succès.
  final VoidCallback? onPaymentSuccess;

  final CampayApiService _service;

  // -------------------------------------------------------------------
  // Reactive State
  // -------------------------------------------------------------------

  /// `true` pendant que le paiement est en cours (affiche l'overlay).
  final isProcessing = false.obs;

  /// Texte du statut affiché pendant le traitement.
  final paymentStatus = ''.obs;

  /// Mode de paiement sélectionné (Orange Money par défaut).
  final selectedMethod = PaymentMethod.orangeMoney.obs;

  /// Numéro de téléphone saisi par l'utilisateur.
  final phoneNumber = ''.obs;

  /// PIN Mobile Money saisi par l'utilisateur dans l'app.
  final pin = ''.obs;

  /// `true` quand le champ PIN doit être affiché.
  final awaitingPin = false.obs;

  /// Token Campay (stocké entre les phases).
  String _token = '';

  /// Référence de la transaction (stockée entre les phases).
  String _reference = '';

  /// Montant réellement facturé (peut être différent en mode démo).
  num get chargeableAmount {
    if (_service.isDemo && amount > 10) return 10;
    return amount;
  }

  // -------------------------------------------------------------------
  // Phone Sanitizer
  // -------------------------------------------------------------------

  /// Formate un numéro en format international camerounais (`237XXXXXXXXX`).
  String sanitizePhone(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.startsWith('237') && digits.length >= 12) {
      return digits.substring(0, 12);
    }
    if (digits.length == 9 && digits.startsWith('6')) {
      return '237$digits';
    }
    if (digits.length == 10 && digits.startsWith('6')) {
      return '237${digits.substring(1)}';
    }
    return digits;
  }

  // -------------------------------------------------------------------
  // Payment Execution — Phase 1: Request
  // -------------------------------------------------------------------

  /// Phase 1 — Valide le numéro, obtient le token, envoie la demande de
  /// paiement, puis affiche le champ PIN.
  Future<void> executePayment() async {
    final method = selectedMethod.value;

    // --- Credit Card: redirect to card payment form ---
    if (method == PaymentMethod.creditCard) {
      await _executeCreditCardPayment();
      return;
    }

    // --- Cash: confirm immediately (payment on delivery) ---
    if (method == PaymentMethod.cash) {
      await _executeCashPayment();
      return;
    }

    // --- Mobile Money: validate phone and start Campay flow ---
    if (phoneNumber.value.trim().isEmpty) {
      Get.snackbar(
        'Phone number required',
        'Please enter your mobile money phone number.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
      );
      return;
    }

    isProcessing.value = true;
    pin.value = '';
    awaitingPin.value = false;

    try {
      final phone = sanitizePhone(phoneNumber.value);

      if (_service.isDemo) {
        paymentStatus.value = 'Sending payment request...';
        await Future<void>.delayed(const Duration(seconds: 1));
        _reference = CampayApiService.newExternalReference(txRefPrefix);
      } else {
        paymentStatus.value = 'Authenticating with payment server...';
        _token = await _service.getToken();

        paymentStatus.value = 'Sending payment request to your phone...';
        final ref = externalReference ??
            CampayApiService.newExternalReference(txRefPrefix);

        final result = await _service.requestPayment(
          token: _token,
          phoneNumber: phone,
          amount: chargeableAmount,
          description: description,
          externalReference: ref,
        );
        _reference = result['reference'] as String? ?? '';
      }

      paymentStatus.value =
          '📱 Please enter your Mobile Money PIN below to confirm the payment.';
      awaitingPin.value = true;
    } on CampayApiException catch (e) {
      _showError('Payment Error', e.message);
    } catch (e) {
      _showError('Error', 'An unexpected error occurred: $e');
    } finally {
      isProcessing.value = false;
    }
  }

  // --- Credit Card Payment (via Stripe or similar) ---
  Future<void> _executeCreditCardPayment() async {
    isProcessing.value = true;
    pin.value = '';
    awaitingPin.value = false;

    try {
      paymentStatus.value = 'Processing card payment...';
      _reference = externalReference ??
          CampayApiService.newExternalReference(txRefPrefix);

      // Simulate card payment processing.
      // In production, integrate with Stripe / Paystack / Flutterwave.
      await Future<void>.delayed(const Duration(seconds: 2));

      paymentStatus.value = '✅ Card payment confirmed!';
      await _writeTransactionToFirestore();
      await Future<void>.delayed(const Duration(milliseconds: 800));
      onPaymentSuccess?.call();
    } catch (e) {
      _showError('Payment Error', 'Card payment failed: $e');
    } finally {
      isProcessing.value = false;
    }
  }

  // --- Cash Payment (pay on collection) ---
  Future<void> _executeCashPayment() async {
    isProcessing.value = true;
    pin.value = '';
    awaitingPin.value = false;

    try {
      paymentStatus.value = 'Recording cash payment...';
      _reference = externalReference ??
          CampayApiService.newExternalReference(txRefPrefix);

      // Cash payments are recorded immediately — no external API call.
      await _writeTransactionToFirestore();

      paymentStatus.value = '✅ Cash payment recorded!';
      await Future<void>.delayed(const Duration(milliseconds: 800));
      onPaymentSuccess?.call();
    } catch (e) {
      _showError('Payment Error', 'Failed to record cash payment: $e');
    } finally {
      isProcessing.value = false;
    }
  }

  // -------------------------------------------------------------------
  // Payment Execution — Phase 2: Confirm with PIN
  // -------------------------------------------------------------------

  /// Phase 2 — Soumet le PIN saisi par l'utilisateur pour confirmer le
  /// paiement, puis lance le polling.
  Future<void> submitPin() async {
    final enteredPin = pin.value.trim();
    if (enteredPin.isEmpty) {
      Get.snackbar(
        'PIN required',
        'Please enter your Mobile Money PIN.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade100,
        colorText: Colors.red.shade900,
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
      );
      return;
    }

    isProcessing.value = true;
    awaitingPin.value = false;

    try {
      if (_service.isDemo) {
        // --- DEMO: simulate confirmation & success ---
        paymentStatus.value = 'Confirming payment with your PIN...';
        await Future<void>.delayed(const Duration(seconds: 2));

        paymentStatus.value = 'Verifying payment status...';
        await Future<void>.delayed(const Duration(seconds: 1));
      } else {
        // --- PRODUCTION: real Campay API flow ---
        paymentStatus.value = 'Confirming payment with your PIN...';
        await _service.requestPayment(
          token: _token,
          phoneNumber: sanitizePhone(phoneNumber.value),
          amount: chargeableAmount,
          description: description,
          externalReference: _reference.isNotEmpty ? _reference : null,
          pin: enteredPin,
        );

        paymentStatus.value = 'Verifying payment status...';
        final status = await _service.pollUntilResolved(
          token: _token,
          reference: _reference,
        );

        if (status != 'SUCCESSFUL') {
          final msg = status == 'TIMEOUT'
              ? 'Payment timed out. No charge was made.'
              : 'Payment failed. No charge was made.';
          _showError('Payment Issue', msg);
          return;
        }
      }

      // Succès (demo ou prod)
      paymentStatus.value = '✅ Payment confirmed!';
      await _writeTransactionToFirestore();
      await Future<void>.delayed(const Duration(milliseconds: 800));
      onPaymentSuccess?.call();
    } on CampayApiException catch (e) {
      _showError('Payment Error', e.message);
    } catch (e) {
      _showError('Error', 'An unexpected error occurred: $e');
    } finally {
      isProcessing.value = false;
    }
  }

  // -------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------

  Future<void> _writeTransactionToFirestore() async {
    try {
      final user = Get.context != null
          ? Provider.of<UserProvider>(Get.context!, listen: false).user
          : null;
      await FirebaseFirestore.instance.collection('transactions').add({
        'phone': user?.phoneNumber ?? '',
        'amount': chargeableAmount,
        'currency': 'XAF',
        'description': description,
        'status': 'successful',
        'method': selectedMethod.value.label,
        'reference': _reference,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Non-critical: payment succeeded even if Firestore write fails.
    }
  }

  void _showError(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.shade100,
      colorText: Colors.red.shade900,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      duration: const Duration(seconds: 4),
    );
    paymentStatus.value = '';
  }
}
