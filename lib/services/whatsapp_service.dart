import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// WhatsApp notification service using Meta Cloud API (WhatsApp Business Platform).
///
/// Configuration via `.env` / dart-define:
///   - `WHATSAPP_API_URL` — Meta Graph API base URL
///     (default: 'https://graph.facebook.com/v19.0')
///   - `WHATSAPP_PHONE_NUMBER_ID` — WhatsApp Business phone number ID
///   - `WHATSAPP_ACCESS_TOKEN` — Meta API access token (System User or App)
///   - `WHATSAPP_BUSINESS_ACCOUNT_ID` — WhatsApp Business Account (WABA) ID
///
/// Message types:
///   - **Template messages**: pre-approved by Meta, required for first contact
///     or marketing messages. Used for reminders, confirmations, alerts.
///   - **Free-form messages**: within the 24-hour customer service window.
///     Used for replies and follow-ups.
///
/// In production, move API calls to a Cloud Function to protect credentials.
/// This service logs all attempts in Firestore `whatsapp_logs` for audit.
class WhatsAppService {
  WhatsAppService({FirebaseFirestore? db, http.Client? client})
      : _db = db ?? FirebaseFirestore.instance,
        _client = client ?? http.Client();

  final FirebaseFirestore _db;
  final http.Client _client;

  // ------------------------------------------------------------------
  // Configuration
  // ------------------------------------------------------------------

  bool get isConfigured {
    final phoneNumberId = const String.fromEnvironment('WHATSAPP_PHONE_NUMBER_ID');
    final accessToken = const String.fromEnvironment('WHATSAPP_ACCESS_TOKEN');
    return phoneNumberId.isNotEmpty && accessToken.isNotEmpty;
  }

  String get _apiUrl => const String.fromEnvironment(
        'WHATSAPP_API_URL',
        defaultValue: 'https://graph.facebook.com/v19.0',
      );

  String get _phoneNumberId =>
      const String.fromEnvironment('WHATSAPP_PHONE_NUMBER_ID');

  String get _accessToken =>
      const String.fromEnvironment('WHATSAPP_ACCESS_TOKEN');

  String get _businessAccountId =>
      const String.fromEnvironment('WHATSAPP_BUSINESS_ACCOUNT_ID');

  // ------------------------------------------------------------------
  // Public API — notification-specific methods
  // ------------------------------------------------------------------

  /// Sends a pickup reminder via WhatsApp.
  Future<bool> sendPickupReminder({
    required String phone,
    required String clientName,
    required String date,
    required String time,
  }) async {
    return sendTemplateMessage(
      phone: phone,
      templateName: 'pickup_reminder',
      languageCode: 'en',
      parameters: [
        {'type': 'text', 'text': clientName},
        {'type': 'text', 'text': date},
        {'type': 'text', 'text': time},
      ],
      fallbackText:
          'Hi $clientName, your waste collection is scheduled for $date at $time. '
          'Please ensure your bin is ready. — WastePro',
      type: 'pickup_reminder',
    );
  }

  /// Sends a payment confirmation via WhatsApp.
  Future<bool> sendPaymentConfirmation({
    required String phone,
    required String clientName,
    required double amount,
    required String plan,
    required String txRef,
  }) async {
    final amountStr = amount.toStringAsFixed(0);
    return sendTemplateMessage(
      phone: phone,
      templateName: 'payment_confirmation',
      languageCode: 'en',
      parameters: [
        {'type': 'text', 'text': clientName},
        {'type': 'text', 'text': '$amountStr XAF'},
        {'type': 'text', 'text': plan},
        {'type': 'text', 'text': txRef},
      ],
      fallbackText:
          'Hi $clientName, your payment of $amountStr XAF for the $plan plan '
          'has been confirmed (Ref: $txRef). Thank you! — WastePro',
      type: 'payment_confirmation',
    );
  }

  /// Sends a subscription expiry warning via WhatsApp.
  Future<bool> sendSubscriptionExpiry({
    required String phone,
    required String clientName,
    required int daysLeft,
    required String expiryDate,
  }) async {
    return sendTemplateMessage(
      phone: phone,
      templateName: 'subscription_expiry',
      languageCode: 'en',
      parameters: [
        {'type': 'text', 'text': clientName},
        {'type': 'text', 'text': '$daysLeft'},
        {'type': 'text', 'text': expiryDate},
      ],
      fallbackText:
          'Hi $clientName, your WastePro subscription expires in $daysLeft '
          'day(s) (on $expiryDate). Renew now to avoid service interruption. — WastePro',
      type: 'subscription_expiry',
    );
  }

  /// Sends a missed collection notification via WhatsApp.
  Future<bool> sendMissedCollection({
    required String phone,
    required String clientName,
    required String reason,
  }) async {
    return sendTemplateMessage(
      phone: phone,
      templateName: 'missed_collection',
      languageCode: 'en',
      parameters: [
        {'type': 'text', 'text': clientName},
        {'type': 'text', 'text': reason},
      ],
      fallbackText:
          'Hi $clientName, we were unable to collect your waste today '
          '($reason). We will retry on the next scheduled day. — WastePro',
      type: 'missed_collection',
    );
  }

  /// Sends a pickup confirmation request via WhatsApp.
  Future<bool> sendPickupConfirmationRequest({
    required String phone,
    required String clientName,
    required String collectorName,
    required double poids,
    required String date,
  }) async {
    return sendFreeFormMessage(
      phone: phone,
      message: 'Hi $clientName, $collectorName collected '
          '${poids.toStringAsFixed(1)} kg from you on $date.\nOpen the WastePro app, tap the notification and scan the QR code to validate your pickup. Did not happen? Tap "The pickup didn\'t occur". - WastePro',
      type: 'pickup_confirmation_request',
    );
  }

  /// Sends a pickup confirmed message via WhatsApp.
  Future<bool> sendPickupConfirmed({
    required String phone,
    required String clientName,
    required String collectorName,
    required double poids,
    required String date,
  }) async {
    return sendFreeFormMessage(
      phone: phone,
      message: 'Hi $clientName, you confirmed the pickup of '
          '${poids.toStringAsFixed(1)} kg by $collectorName on $date. Thank you! - WastePro',
      type: 'pickup_confirmed',
    );
  }

  /// Sends a pickup disputed message via WhatsApp.
  Future<bool> sendPickupDisputed({
    required String phone,
    required String clientName,
    required String collectorName,
    required String reason,
    required String date,
  }) async {
    return sendFreeFormMessage(
      phone: phone,
      message: 'Hi $clientName, you reported an issue with '
          '$collectorName\'s pickup on $date ($reason). - WastePro',
      type: 'pickup_disputed',
    );
  }

  /// Sends a general notification via WhatsApp (free-form, within 24h window).
  Future<bool> sendGeneral({
    required String phone,
    required String message,
  }) async {
    return sendFreeFormMessage(
      phone: phone,
      message: message,
      type: 'general',
    );
  }

  // ------------------------------------------------------------------
  // Template messages (for first contact / proactive notifications)
  // ------------------------------------------------------------------

  /// Sends a pre-approved template message via the WhatsApp Business API.
  ///
  /// Template messages are required for:
  ///   - First message to a customer (outside 24h window)
  ///   - Proactive notifications (reminders, alerts, confirmations)
  ///   - Marketing messages
  ///
  /// Templates must be created and approved in the WhatsApp Business Manager.
  Future<bool> sendTemplateMessage({
    required String phone,
    required String templateName,
    required String languageCode,
    required List<Map<String, dynamic>> parameters,
    String? fallbackText,
    required String type,
  }) async {
    if (!isConfigured) {
      debugPrint('[WhatsApp] Not configured — skipping template to $phone');
      _logMessage(
        phone: phone,
        message: fallbackText ?? templateName,
        type: type,
        status: 'skipped',
        messageType: 'template',
      );
      return false;
    }

    final normalizedPhone = _normalizePhone(phone);

    try {
      final body = {
        'messaging_product': 'whatsapp',
        'to': normalizedPhone,
        'type': 'template',
        'template': {
          'name': templateName,
          'language': {'code': languageCode},
          if (parameters.isNotEmpty)
            'components': [
              {
                'type': 'body',
                'parameters': parameters,
              },
            ],
        },
      };

      final response = await _client.post(
        Uri.parse('$_apiUrl/$_phoneNumberId/messages'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final success = response.statusCode == 200;
      final responseBody = success
          ? jsonDecode(response.body) as Map<String, dynamic>
          : null;

      // Check for API errors.
      final errorMsg = responseBody?['error']?['message'] as String?;

      _logMessage(
        phone: normalizedPhone,
        message: fallbackText ?? templateName,
        type: type,
        status: success ? 'sent' : 'failed',
        messageType: 'template',
        response: responseBody,
        error: errorMsg,
      );

      debugPrint('[WhatsApp] Template "$templateName" to $normalizedPhone: '
          'success=$success${errorMsg != null ? ', error=$errorMsg' : ''}');
      return success;
    } catch (e) {
      debugPrint('[WhatsApp] Error sending template: $e');
      _logMessage(
        phone: normalizedPhone,
        message: fallbackText ?? templateName,
        type: type,
        status: 'error',
        messageType: 'template',
        error: e.toString(),
      );
      return false;
    }
  }

  // ------------------------------------------------------------------
  // Free-form messages (within 24-hour customer service window)
  // ------------------------------------------------------------------

  /// Sends a free-form text message via WhatsApp.
  ///
  /// Only works within the 24-hour customer service window (after the
  /// customer has sent a message to the business). Outside this window,
  /// only template messages are allowed.
  Future<bool> sendFreeFormMessage({
    required String phone,
    required String message,
    required String type,
  }) async {
    if (!isConfigured) {
      debugPrint('[WhatsApp] Not configured — skipping message to $phone');
      _logMessage(
        phone: phone,
        message: message,
        type: type,
        status: 'skipped',
        messageType: 'text',
      );
      return false;
    }

    final normalizedPhone = _normalizePhone(phone);

    try {
      final body = {
        'messaging_product': 'whatsapp',
        'to': normalizedPhone,
        'type': 'text',
        'text': {'body': message},
      };

      final response = await _client.post(
        Uri.parse('$_apiUrl/$_phoneNumberId/messages'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      final success = response.statusCode == 200;
      final responseBody = success
          ? jsonDecode(response.body) as Map<String, dynamic>
          : null;

      final errorMsg = responseBody?['error']?['message'] as String?;

      _logMessage(
        phone: normalizedPhone,
        message: message,
        type: type,
        status: success ? 'sent' : 'failed',
        messageType: 'text',
        response: responseBody,
        error: errorMsg,
      );

      debugPrint('[WhatsApp] Text to $normalizedPhone: '
          'success=$success${errorMsg != null ? ', error=$errorMsg' : ''}');
      return success;
    } catch (e) {
      debugPrint('[WhatsApp] Error sending text: $e');
      _logMessage(
        phone: normalizedPhone,
        message: message,
        type: type,
        status: 'error',
        messageType: 'text',
        error: e.toString(),
      );
      return false;
    }
  }

  // ------------------------------------------------------------------
  // Template management helpers
  // ------------------------------------------------------------------

  /// Lists all registered templates for this WhatsApp Business Account.
  ///
  /// Useful for debugging and verifying template names before sending.
  /// Returns a list of template names and their statuses.
  Future<List<Map<String, dynamic>>> listTemplates() async {
    if (!isConfigured || _businessAccountId.isEmpty) return [];

    try {
      final response = await _client.get(
        Uri.parse(
          '$_apiUrl/$_businessAccountId/message_templates'
          '?fields=name,status,category,language',
        ),
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = body['data'] as List<dynamic>? ?? [];
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[WhatsApp] Error listing templates: $e');
      return [];
    }
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  /// Normalizes a phone number to WhatsApp format (E.164 without '+').
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

  /// Logs a WhatsApp message attempt in Firestore for audit trail.
  Future<void> _logMessage({
    required String phone,
    required String message,
    required String type,
    required String status,
    required String messageType,
    Map<String, dynamic>? response,
    String? error,
  }) async {
    try {
      await _db.collection('whatsapp_logs').add({
        'phone': phone,
        'message': message,
        'type': type,
        'message_type': messageType,
        'status': status,
        'response': response,
        'error': error,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Non-critical: logging failure should not block the flow.
      debugPrint('[WhatsApp] Failed to log message: $e');
    }
  }
}
