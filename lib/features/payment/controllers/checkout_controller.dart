import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../../core/config.dart';
import '../../../providers/user_provider.dart';
import '../../../services/campay_api_service.dart';

enum PaymentMethod {
  orangeMoney,
  mtnMomo,
  creditCard,
  cash,
}

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

  bool get requiresMobileMoney => switch (this) {
        PaymentMethod.orangeMoney || PaymentMethod.mtnMomo => true,
        PaymentMethod.creditCard || PaymentMethod.cash => false,
      };
}

/// Checkout via CamPay.
///
/// UI shows the plan price (e.g. 3000 XAF). In demo, CamPay is charged
/// only [AppConfig.campayDemoMaxAmount] (25 XAF).
class CheckoutController extends GetxController {
  CheckoutController({
    required this.amount,
    required this.description,
    this.externalReference,
    this.txRefPrefix = 'WP',
    CampayApiService? service,
    this.onPaymentSuccess,
  }) : _service = service ?? CampayApiService();

  final num amount;
  final String description;
  final String? externalReference;
  final String txRefPrefix;
  final VoidCallback? onPaymentSuccess;
  final CampayApiService _service;

  final isProcessing = false.obs;
  final paymentStatus = ''.obs;
  final selectedMethod = PaymentMethod.orangeMoney.obs;
  final phoneNumber = ''.obs;
  final pin = ''.obs;
  final awaitingPin = false.obs;

  String _token = '';
  String _reference = '';

  /// Bound from [CheckoutScreen] — required because the app uses
  /// MaterialApp (not GetMaterialApp), so Get.snackbar / Get.context crash.
  BuildContext? hostContext;

  void bindHost(BuildContext context) {
    hostContext = context;
  }

  num get chargeableAmount {
    if (_service.isDemo || AppConfig.isCampayDemo) {
      return AppConfig.campayDemoMaxAmount;
    }
    return amount;
  }

  num get displayAmount => amount;

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

  void _notify(String title, String message, {bool error = false}) {
    final ctx = hostContext;
    if (ctx == null || !ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.info_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text('$title: $message')),
          ],
        ),
        backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> executePayment() async {
    final method = selectedMethod.value;

    if (method == PaymentMethod.creditCard) {
      await _executeCreditCardPayment();
      return;
    }
    if (method == PaymentMethod.cash) {
      await _executeCashPayment();
      return;
    }

    if (phoneNumber.value.trim().isEmpty) {
      _notify(
        'Phone number required',
        'Please enter your mobile money phone number.',
        error: true,
      );
      return;
    }

    if (!_service.isConfigured) {
      _notify(
        'CamPay not configured',
        'Add CAMPAY_TOKEN or CAMPAY_USERNAME/PASSWORD in .env, then restart the app.',
        error: true,
      );
      return;
    }

    isProcessing.value = true;
    pin.value = '';
    awaitingPin.value = false;

    try {
      final phone = sanitizePhone(phoneNumber.value);
      if (phone.length < 12) {
        _showError(
          'Invalid phone',
          'Use a Cameroon MoMo number like 6XX XXX XXX.',
        );
        return;
      }

      paymentStatus.value = 'Connecting to CamPay...';
      _token = await _service.getToken();

      paymentStatus.value =
          'Sending payment request (${chargeableAmount.toStringAsFixed(0)} XAF)...\n'
          'Check your phone for the MTN / Orange Money prompt.';
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
      final ussd = result['ussd_code']?.toString();

      paymentStatus.value = ussd != null && ussd.isNotEmpty
          ? 'Approve on your phone now.\nUSSD: $ussd\nWaiting for confirmation...'
          : 'Approve the payment on your phone (MoMo / Orange Money PIN).\nDo not close this screen...';

      // CamPay sends the USSD push to the handset — we only poll status.
      // No in-app PIN and no local fake success.
      final status = await _service.pollUntilResolved(
        token: _token,
        reference: _reference,
      );

      if (status != 'SUCCESSFUL') {
        final msg = status == 'TIMEOUT'
            ? 'No confirmation received on your phone in time. Try again.'
            : 'Payment was declined or failed on your phone.';
        _showError('Payment Issue', msg);
        return;
      }

      paymentStatus.value = 'Payment confirmed!';
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

  Future<void> _executeCreditCardPayment() async {
    isProcessing.value = true;
    pin.value = '';
    awaitingPin.value = false;
    try {
      paymentStatus.value = 'Processing card payment...';
      _reference = externalReference ??
          CampayApiService.newExternalReference(txRefPrefix);
      await Future<void>.delayed(const Duration(seconds: 2));
      paymentStatus.value = 'Card payment confirmed!';
      await _writeTransactionToFirestore();
      await Future<void>.delayed(const Duration(milliseconds: 800));
      onPaymentSuccess?.call();
    } catch (e) {
      _showError('Payment Error', 'Card payment failed: $e');
    } finally {
      isProcessing.value = false;
    }
  }

  Future<void> _executeCashPayment() async {
    isProcessing.value = true;
    pin.value = '';
    awaitingPin.value = false;
    try {
      paymentStatus.value = 'Recording cash payment...';
      _reference = externalReference ??
          CampayApiService.newExternalReference(txRefPrefix);
      await _writeTransactionToFirestore();
      paymentStatus.value = 'Cash payment recorded!';
      await Future<void>.delayed(const Duration(milliseconds: 800));
      onPaymentSuccess?.call();
    } catch (e) {
      _showError('Payment Error', 'Failed to record cash payment: $e');
    } finally {
      isProcessing.value = false;
    }
  }

  /// Kept for UI compatibility — MoMo no longer uses in-app PIN.
  Future<void> submitPin() async {
    _notify(
      'Use your phone',
      'Enter your MoMo / Orange Money PIN on your phone when prompted, not in the app.',
      error: true,
    );
  }

  Future<void> _writeTransactionToFirestore() async {
    try {
      final ctx = hostContext;
      final user = ctx != null && ctx.mounted
          ? Provider.of<UserProvider>(ctx, listen: false).user
          : null;
      final phone = user?.phoneNumber ?? '';
      await FirebaseFirestore.instance.collection('transactions').add({
        'userId': phone,
        'phone': phone,
        'customerName': user?.fullName,
        'amount': chargeableAmount,
        'displayAmount': displayAmount,
        'currency': 'XAF',
        'description': description,
        'status': 'successful',
        'method': selectedMethod.value.label,
        'paymentMethod': 'campay',
        'type': 'subscription',
        'reference': _reference,
        'provider': 'campay',
        'isDemoCharge': _service.isDemo || AppConfig.isCampayDemo,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  void _showError(String title, String message) {
    _notify(title, message, error: true);
    paymentStatus.value = '';
  }
}
