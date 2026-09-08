import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// SMS service using Vonage (Nexmo) REST API.
///
/// Configuration via `.env`:
///   - `VONAGE_API_KEY` — your Vonage API key
///   - `VONAGE_API_SECRET` — your Vonage API secret
///   - `VONAGE_SENDER` — sender name/number (e.g. 'WastePro')
///
/// In production, move API calls to a Cloud Function to protect credentials.
/// This service logs calls in Firestore `sms_logs` for audit and debugging.
class SmsService {
  SmsService({FirebaseFirestore? db, http.Client? client})
      : _db = db ?? FirebaseFirestore.instance,
        _client = client ?? http.Client();

  final FirebaseFirestore _db;
  final http.Client _client;

  static const String _apiUrl = 'https://rest.nexmo.com/sms/json';

  /// Whether the service is configured (env vars present).
  bool get isConfigured {
    final key = const String.fromEnvironment('VONAGE_API_KEY');
    final secret = const String.fromEnvironment('VONAGE_API_SECRET');
    return key.isNotEmpty && secret.isNotEmpty;
  }

  String get _apiKey => const String.fromEnvironment('VONAGE_API_KEY');
  String get _apiSecret => const String.fromEnvironment('VONAGE_API_SECRET');
  String get _sender => const String.fromEnvironment(
    'VONAGE_SENDER',
    defaultValue: 'WastePro',
  );

  // ------------------------------------------------------------------
  // Public API — notification-specific methods
  // ------------------------------------------------------------------

  /// Sends a pickup reminder: "Your collection is scheduled for tomorrow."
  Future<bool> sendPickupReminder({
    required String phone,
    required String clientName,
    required String date,
    required String time,
  }) async {
    final message = 'Hi $clientName, your waste collection is scheduled '
        'for $date at $time. Please ensure your bin is ready. — WastePro';
    return sendSms(phone: phone, message: message, type: 'pickup_reminder');
  }

  /// Sends a payment confirmation receipt.
  Future<bool> sendPaymentConfirmation({
    required String phone,
    required String clientName,
    required double amount,
    required String plan,
  }) async {
    final amountStr = amount.toStringAsFixed(0);
    final message = 'Hi $clientName, your payment of $amountStr XAF for '
        'the $plan plan has been confirmed. Thank you! — WastePro';
    return sendSms(phone: phone, message: message, type: 'payment_confirmation');
  }

  /// Sends a subscription expiry warning.
  Future<bool> sendSubscriptionExpiry({
    required String phone,
    required String clientName,
    required int daysLeft,
  }) async {
    final message = 'Hi $clientName, your WastePro subscription expires '
        'in $daysLeft day(s). Renew now to avoid service interruption. — WastePro';
    return sendSms(phone: phone, message: message, type: 'subscription_expiry');
  }

  /// Sends a missed collection notification.
  Future<bool> sendMissedCollection({
    required String phone,
    required String clientName,
    required String reason,
  }) async {
    final message = 'Hi $clientName, we were unable to collect your waste '
        'today ($reason). We will retry on the next scheduled day. — WastePro';
    return sendSms(phone: phone, message: message, type: 'missed_collection');
  }

  /// Sends a pickup confirmation request: asks the client to confirm or dispute.
  Future<bool> sendPickupConfirmationRequest({
    required String phone,
    required String clientName,
    required String collectorName,
    required double poids,
    required String date,
  }) async {
    final message = 'Hi $clientName, $collectorName collected '
        '${poids.toStringAsFixed(1)} kg from you on $date.\nOpen the WastePro app, tap the notification and scan the QR code to validate your pickup. Did not happen? Tap "The pickup didn\'t occur". - WastePro';
    return sendSms(phone: phone, message: message, type: 'pickup_confirmation_request');
  }

  /// Sends a pickup confirmed notification.
  Future<bool> sendPickupConfirmed({
    required String phone,
    required String clientName,
    required String collectorName,
    required double poids,
    required String date,
  }) async {
    final message = 'Hi $clientName, you confirmed the pickup of '
        '${poids.toStringAsFixed(1)} kg by $collectorName on $date. Thank you! - WastePro';
    return sendSms(phone: phone, message: message, type: 'pickup_confirmed');
  }

  /// Sends a pickup disputed notification.
  Future<bool> sendPickupDisputed({
    required String phone,
    required String clientName,
    required String collectorName,
    required String reason,
    required String date,
  }) async {
    final message = 'Hi $clientName, you reported an issue with '
        '$collectorName\'s pickup on $date ($reason). - WastePro';
    return sendSms(phone: phone, message: message, type: 'pickup_disputed');
  }

  /// Sends a general notification SMS.
  Future<bool> sendGeneral({
    required String phone,
    required String message,
  }) async {
    return sendSms(phone: phone, message: message, type: 'general');
  }

  // ------------------------------------------------------------------
  // Core SMS sending
  // ------------------------------------------------------------------

  /// Sends an SMS via Vonage API and logs the result in Firestore.
  ///
  /// [phone] should be in international format (e.g. '+237677123456').
  /// [type] categorizes the SMS for logging (e.g. 'pickup_reminder').
  Future<bool> sendSms({
    required String phone,
    required String message,
    required String type,
  }) async {
    if (!isConfigured) {
      debugPrint('[SmsService] Not configured — skipping SMS to $phone');
      _logSms(phone: phone, message: message, type: type, status: 'skipped');
      return false;
    }

    final normalizedPhone = _normalizePhone(phone);

    try {
      final response = await _client.post(
        Uri.parse(_apiUrl),
        body: {
          'api_key': _apiKey,
          'api_secret': _apiSecret,
          'from': _sender,
          'to': normalizedPhone,
          'text': message,
        },
      );

      final success = response.statusCode == 200;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final messages = body['messages'] as List<dynamic>?;
      final status = messages?.isNotEmpty == true
          ? (messages!.first['status'] as String? ?? 'unknown')
          : 'error';

      _logSms(
        phone: normalizedPhone,
        message: message,
        type: type,
        status: success && status == '0' ? 'sent' : 'failed',
        response: body,
      );

      debugPrint('[SmsService] SMS to $normalizedPhone: status=$status');
      return success && status == '0';
    } catch (e) {
      debugPrint('[SmsService] Error sending SMS: $e');
      _logSms(
        phone: normalizedPhone,
        message: message,
        type: type,
        status: 'error',
        error: e.toString(),
      );
      return false;
    }
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  /// Normalizes a phone number to Vonage format (digits only, with country code).
  String _normalizePhone(String phone) {
    final cleaned = phone.trim().replaceAll(RegExp(r'[\s\-+]'), '');
    if (cleaned.startsWith('237') && cleaned.length >= 12) {
      return cleaned;
    }
    if (cleaned.length == 9 && cleaned.startsWith('6')) {
      return '237$cleaned';
    }
    return cleaned;
  }

  /// Logs an SMS attempt in Firestore for audit trail.
  Future<void> _logSms({
    required String phone,
    required String message,
    required String type,
    required String status,
    Map<String, dynamic>? response,
    String? error,
  }) async {
    try {
      await _db.collection('sms_logs').add({
        'phone': phone,
        'message': message,
        'type': type,
        'status': status,
        'response': response,
        'error': error,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Non-critical: logging failure should not block the flow.
      debugPrint('[SmsService] Failed to log SMS: $e');
    }
  }
}
