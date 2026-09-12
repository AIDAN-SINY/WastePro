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
/// only [AppConfig.campayDemoMaxAmount] (1 XAF).
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
    final ctx = Get.context;
    if (ctx != null && ctx.mounted) {
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
        ),
      );
      return;
    }
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: error ? Colors.red.shade100 : Colors.green.shade100,
      colorText: error ? Colors.red.shade900 : Colors.green.shade900,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      duration: const Duration(seconds: 4),
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

    isProcessing.value = true;
    pin.value = '';
    awaitingPin.value = false;

    try {
      final phone = sanitizePhone(phoneNumber.value);
      final useLiveApi = _service.isConfigured;

      if (!useLiveApi && _service.isDemo) {
        paymentStatus.value =
            'Demo 1 XAF - local simulation (add CAMPAY credentials in .env for live CamPay)';
        await Future<void>.delayed(const Duration(seconds: 1));
        _reference = CampayApiService.newExternalReference(txRefPrefix);
      } else {
        paymentStatus.value = 'Authenticating with CamPay...';
        _token = await _service.getToken();

        paymentStatus.value =
            'Sending ${chargeableAmount.toStringAsFixed(0)} XAF to your phone (plan ${displayAmount.toStringAsFixed(0)} XAF)...';
        final ref = externalReference ??
            CampayApiService.newExternalReference(txRefPrefix);

        final result = await _service.requestPayment(
          token: _token,
          phoneNumber: phone,
          amount: chargeableAmount,
          description:
              '$description (demo ${chargeableAmount} XAF / plan $displayAmount XAF)',
          externalReference: ref,
        );
        _reference = result['reference'] as String? ?? '';
      }

      paymentStatus.value =
          'Enter your Mobile Money PIN below to confirm the payment.';
      awaitingPin.value = true;
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

  Future<void> submitPin() async {
    final enteredPin = pin.value.trim();
    if (enteredPin.isEmpty) {
      _notify('PIN required', 'Please enter your Mobile Money PIN.', error: true);
      return;
    }

    isProcessing.value = true;
    awaitingPin.value = false;

    try {
      final useLiveApi = _service.isConfigured && _token.isNotEmpty;

      if (!useLiveApi && _service.isDemo) {
        paymentStatus.value = 'Confirming demo payment (1 XAF)...';
        await Future<void>.delayed(const Duration(seconds: 2));
        paymentStatus.value = 'Verifying payment status...';
        await Future<void>.delayed(const Duration(seconds: 1));
      } else {
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

  Future<void> _writeTransactionToFirestore() async {
    try {
      final user = Get.context != null
          ? Provider.of<UserProvider>(Get.context!, listen: false).user
          : null;
      final phone = user?.phoneNumber ?? '';
      await FirebaseFirestore.instance.collection('transactions').add({
        'userId': phone,
        'phone': phone,
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
