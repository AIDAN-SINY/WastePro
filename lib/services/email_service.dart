import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Email service using Elastic Email REST API.
///
/// Configuration via `.env`:
///   - `ELASTICEMAIL_API_KEY` — your Elastic Email API key
///   - `ELASTICEMAIL_FROM` — sender email (e.g. 'noreply@wastepro.cm')
///   - `ELASTICEMAIL_FROM_NAME` — sender display name (e.g. 'WastePro')
///
/// In production, move API calls to a Cloud Function to protect credentials.
/// This service logs calls in Firestore `email_logs` for audit and debugging.
class EmailService {
  EmailService({FirebaseFirestore? db, http.Client? client})
      : _db = db ?? FirebaseFirestore.instance,
        _client = client ?? http.Client();

  final FirebaseFirestore _db;
  final http.Client _client;

  static const String _apiUrl = 'https://api.elasticemail.com/v4/emails';

  /// Whether the service is configured (env vars present).
  bool get isConfigured {
    final key = const String.fromEnvironment('ELASTICEMAIL_API_KEY');
    return key.isNotEmpty;
  }

  String get _apiKey => const String.fromEnvironment('ELASTICEMAIL_API_KEY');
  String get _from => const String.fromEnvironment(
    'ELASTICEMAIL_FROM',
    defaultValue: 'noreply@wastepro.cm',
  );
  String get _fromName => const String.fromEnvironment(
    'ELASTICEMAIL_FROM_NAME',
    defaultValue: 'WastePro',
  );

  // ------------------------------------------------------------------
  // Public API — notification-specific methods
  // ------------------------------------------------------------------

  /// Sends a pickup reminder email.
  Future<bool> sendPickupReminder({
    required String email,
    required String clientName,
    required String date,
    required String time,
  }) async {
    final subject = 'WastePro - Pickup Scheduled for $date';
    final html = _pickuReminderTemplate(clientName, date, time);
    return sendEmail(
      to: email,
      subject: subject,
      htmlContent: html,
      type: 'pickup_reminder',
    );
  }

  /// Sends a payment confirmation receipt email.
  Future<bool> sendPaymentConfirmation({
    required String email,
    required String clientName,
    required double amount,
    required String plan,
    required String txRef,
  }) async {
    final subject = 'WastePro - Payment Confirmed';
    final html = _paymentConfirmationTemplate(clientName, amount, plan, txRef);
    return sendEmail(
      to: email,
      subject: subject,
      htmlContent: html,
      type: 'payment_confirmation',
    );
  }

  /// Sends a subscription expiry warning email.
  Future<bool> sendSubscriptionExpiry({
    required String email,
    required String clientName,
    required int daysLeft,
    required String expiryDate,
  }) async {
    final subject = 'WastePro - Subscription Expiring Soon';
    final html = _subscriptionExpiryTemplate(clientName, daysLeft, expiryDate);
    return sendEmail(
      to: email,
      subject: subject,
      htmlContent: html,
      type: 'subscription_expiry',
    );
  }

  /// Sends a report email with attachment info.
  Future<bool> sendReport({
    required String email,
    required String recipientName,
    required String reportTitle,
    required String period,
  }) async {
    final subject = 'WastePro - $reportTitle';
    final html = _reportTemplate(recipientName, reportTitle, period);
    return sendEmail(
      to: email,
      subject: subject,
      htmlContent: html,
      type: 'report',
    );
  }

  /// Sends a pickup confirmation request email.
  Future<bool> sendPickupConfirmationRequest({
    required String email,
    required String clientName,
    required String collectorName,
    required double poids,
    required String date,
  }) async {
    final subject = 'WastePro - Confirm your pickup on $date';
    final html = _pickupConfirmationRequestTemplate(clientName, collectorName, poids, date);
    return sendEmail(
      to: email,
      subject: subject,
      htmlContent: html,
      type: 'pickup_confirmation_request',
    );
  }

  /// Sends a pickup confirmed email.
  Future<bool> sendPickupConfirmed({
    required String email,
    required String clientName,
    required String collectorName,
    required double poids,
    required String date,
  }) async {
    final subject = 'WastePro - Pickup Confirmed';
    final html = _pickupConfirmedTemplate(clientName, collectorName, poids, date);
    return sendEmail(
      to: email,
      subject: subject,
      htmlContent: html,
      type: 'pickup_confirmed',
    );
  }

  /// Sends a pickup disputed email.
  Future<bool> sendPickupDisputed({
    required String email,
    required String clientName,
    required String collectorName,
    required String reason,
    required String date,
  }) async {
    final subject = 'WastePro - Pickup Issue Reported';
    final html = _pickupDisputedTemplate(clientName, collectorName, reason, date);
    return sendEmail(
      to: email,
      subject: subject,
      htmlContent: html,
      type: 'pickup_disputed',
    );
  }

  /// Sends a general notification email.
  Future<bool> sendGeneral({
    required String email,
    required String subject,
    required String message,
  }) async {
    final html = _generalTemplate(subject, message);
    return sendEmail(
      to: email,
      subject: 'WastePro - $subject',
      htmlContent: html,
      type: 'general',
    );
  }

  // ------------------------------------------------------------------
  // Core email sending
  // ------------------------------------------------------------------

  /// Sends an email via Elastic Email API and logs the result in Firestore.
  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String htmlContent,
    required String type,
  }) async {
    if (!isConfigured) {
      debugPrint('[EmailService] Not configured — skipping email to $to');
      _logEmail(to: to, subject: subject, type: type, status: 'skipped');
      return false;
    }

    try {
      final response = await _client.post(
        Uri.parse(_apiUrl),
        headers: {
          'X-ElasticEmail-ApiKey': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'From': '$_fromName <$_from>',
          'To': to,
          'Subject': subject,
          'Html': htmlContent,
        }),
      );

      final success = response.statusCode == 200;
      final body = response.statusCode == 200
          ? jsonDecode(response.body) as Map<String, dynamic>
          : null;

      _logEmail(
        to: to,
        subject: subject,
        type: type,
        status: success ? 'sent' : 'failed',
        response: body,
      );

      debugPrint('[EmailService] Email to $to: success=$success');
      return success;
    } catch (e) {
      debugPrint('[EmailService] Error sending email: $e');
      _logEmail(
        to: to,
        subject: subject,
        type: type,
        status: 'error',
        error: e.toString(),
      );
      return false;
    }
  }

  // ------------------------------------------------------------------
  // HTML Templates
  // ------------------------------------------------------------------

  String _pickuReminderTemplate(
    String name,
    String date,
    String time,
  ) {
    return '''
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background-color: #0F3D2E; padding: 20px; border-radius: 10px 10px 0 0;">
        <h1 style="color: #E8A33D; margin: 0; font-size: 24px;">🗑️ WastePro</h1>
      </div>
      <div style="background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd;">
        <h2 style="color: #0F3D2E;">Pickup Reminder</h2>
        <p>Hello <strong>$name</strong>,</p>
        <p>This is a reminder that your waste collection is scheduled for:</p>
        <div style="background-color: #E7EFE9; padding: 15px; border-radius: 8px; margin: 15px 0;">
          <p style="margin: 0; font-size: 18px;"><strong>📅 $date</strong></p>
          <p style="margin: 5px 0 0 0; color: #666;">⏰ $time</p>
        </div>
        <p>Please ensure your waste bin is placed outside by the scheduled time.</p>
        <p style="color: #666; font-size: 12px;">Thank you for choosing WastePro!</p>
      </div>
      <div style="background-color: #0F3D2E; padding: 15px; border-radius: 0 0 10px 10px; text-align: center;">
        <p style="color: #aec0b7; margin: 0; font-size: 12px;">© 2026 WastePro — Smart Waste Collection</p>
      </div>
    </div>
    ''';
  }

  String _paymentConfirmationTemplate(
    String name,
    double amount,
    String plan,
    String txRef,
  ) {
    final amountStr = amount.toStringAsFixed(0);
    return '''
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background-color: #0F3D2E; padding: 20px; border-radius: 10px 10px 0 0;">
        <h1 style="color: #E8A33D; margin: 0; font-size: 24px;">🗑️ WastePro</h1>
      </div>
      <div style="background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd;">
        <h2 style="color: #0F3D2E;">Payment Confirmed ✅</h2>
        <p>Hello <strong>$name</strong>,</p>
        <p>Your payment has been successfully processed.</p>
        <div style="background-color: #E7EFE9; padding: 15px; border-radius: 8px; margin: 15px 0;">
          <table style="width: 100%; border-collapse: collapse;">
            <tr><td style="padding: 5px 0; color: #666;">Amount:</td><td style="padding: 5px 0; font-weight: bold;">$amountStr XAF</td></tr>
            <tr><td style="padding: 5px 0; color: #666;">Plan:</td><td style="padding: 5px 0; font-weight: bold;">$plan</td></tr>
            <tr><td style="padding: 5px 0; color: #666;">Reference:</td><td style="padding: 5px 0; font-weight: bold;">$txRef</td></tr>
          </table>
        </div>
        <p>Your subscription is now active. Thank you for choosing WastePro!</p>
      </div>
      <div style="background-color: #0F3D2E; padding: 15px; border-radius: 0 0 10px 10px; text-align: center;">
        <p style="color: #aec0b7; margin: 0; font-size: 12px;">© 2026 WastePro — Smart Waste Collection</p>
      </div>
    </div>
    ''';
  }

  String _subscriptionExpiryTemplate(
    String name,
    int daysLeft,
    String expiryDate,
  ) {
    return '''
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background-color: #0F3D2E; padding: 20px; border-radius: 10px 10px 0 0;">
        <h1 style="color: #E8A33D; margin: 0; font-size: 24px;">🗑️ WastePro</h1>
      </div>
      <div style="background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd;">
        <h2 style="color: #C1443D;">⚠️ Subscription Expiring</h2>
        <p>Hello <strong>$name</strong>,</p>
        <p>Your WastePro subscription will expire in <strong>$daysLeft day(s)</strong> (on $expiryDate).</p>
        <div style="background-color: #F8E4E2; padding: 15px; border-radius: 8px; margin: 15px 0;">
          <p style="margin: 0; color: #C1443D;"><strong>Action Required:</strong> Renew your subscription to continue receiving waste collection services.</p>
        </div>
        <p>To renew, open the WastePro app and go to Subscription > Choose Plan.</p>
        <p style="color: #666; font-size: 12px;">If you've already renewed, please disregard this email.</p>
      </div>
      <div style="background-color: #0F3D2E; padding: 15px; border-radius: 0 0 10px 10px; text-align: center;">
        <p style="color: #aec0b7; margin: 0; font-size: 12px;">© 2026 WastePro — Smart Waste Collection</p>
      </div>
    </div>
    ''';
  }

  String _reportTemplate(String name, String title, String period) {
    return '''
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background-color: #0F3D2E; padding: 20px; border-radius: 10px 10px 0 0;">
        <h1 style="color: #E8A33D; margin: 0; font-size: 24px;">🗑️ WastePro</h1>
      </div>
      <div style="background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd;">
        <h2 style="color: #0F3D2E;">📊 $title</h2>
        <p>Hello <strong>$name</strong>,</p>
        <p>Your <strong>$title</strong> for <strong>$period</strong> has been generated.</p>
        <p>Please find the report attached or download it from the Reports section in the admin console.</p>
        <p style="color: #666; font-size: 12px;">This is an automated report from WastePro.</p>
      </div>
      <div style="background-color: #0F3D2E; padding: 15px; border-radius: 0 0 10px 10px; text-align: center;">
        <p style="color: #aec0b7; margin: 0; font-size: 12px;">© 2026 WastePro — Smart Waste Collection</p>
      </div>
    </div>
    ''';
  }

  String _pickupConfirmationRequestTemplate(
    String clientName,
    String collectorName,
    double poids,
    String date,
  ) {
    return '''
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background-color: #0F3D2E; padding: 20px; border-radius: 10px 10px 0 0;">
        <h1 style="color: #E8A33D; margin: 0; font-size: 24px;">🗑️ WastePro</h1>
      </div>
      <div style="background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd;">
        <h2 style="color: #0F3D2E;">Validate Your Pickup</h2>
        <p>Hello <strong>$clientName</strong>,</p>
        <p>$collectorName collected <strong>${poids.toStringAsFixed(1)} kg</strong> of waste from you on <strong>$date</strong>.</p>
        <div style="background-color: #E7EFE9; padding: 15px; border-radius: 8px; margin: 15px 0;">
          <p style="margin: 0; color: #0F3D2E;"><strong>Did this pickup actually happen?</strong></p>
        </div>
        <p>Open the WastePro app, tap the notification and <strong>scan the QR code</strong> to validate the pickup. If it did not happen, tap “The pickup didn't occur”.</p>
        <p style="color: #666; font-size: 12px;">Thank you for choosing WastePro!</p>
      </div>
      <div style="background-color: #0F3D2E; padding: 15px; border-radius: 0 0 10px 10px; text-align: center;">
        <p style="color: #aec0b7; margin: 0; font-size: 12px;">© 2026 WastePro — Smart Waste Collection</p>
      </div>
    </div>
    ''';
  }

  String _pickupConfirmedTemplate(
    String clientName,
    String collectorName,
    double poids,
    String date,
  ) {
    return '''
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background-color: #0F3D2E; padding: 20px; border-radius: 10px 10px 0 0;">
        <h1 style="color: #E8A33D; margin: 0; font-size: 24px;">🗑️ WastePro</h1>
      </div>
      <div style="background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd;">
        <h2 style="color: #0F3D2E;">Pickup Confirmed ✅</h2>
        <p>Hello <strong>$clientName</strong>,</p>
        <p>You confirmed the pickup of <strong>${poids.toStringAsFixed(1)} kg</strong> by <strong>$collectorName</strong> on <strong>$date</strong>.</p>
        <div style="background-color: #E7EFE9; padding: 15px; border-radius: 8px; margin: 15px 0;">
          <p style="margin: 0; color: #0F3D2E;"><strong>Thank you for validating your pickup!</strong></p>
        </div>
        <p>The collector has been credited for this collection.</p>
        <p style="color: #666; font-size: 12px;">Thank you for choosing WastePro!</p>
      </div>
      <div style="background-color: #0F3D2E; padding: 15px; border-radius: 0 0 10px 10px; text-align: center;">
        <p style="color: #aec0b7; margin: 0; font-size: 12px;">© 2026 WastePro — Smart Waste Collection</p>
      </div>
    </div>
    ''';
  }

  String _pickupDisputedTemplate(
    String clientName,
    String collectorName,
    String reason,
    String date,
  ) {
    return '''
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background-color: #0F3D2E; padding: 20px; border-radius: 10px 10px 0 0;">
        <h1 style="color: #E8A33D; margin: 0; font-size: 24px;">🗑️ WastePro</h1>
      </div>
      <div style="background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd;">
        <h2 style="color: #C1443D;">⚠️ Pickup Issue Reported</h2>
        <p>Hello <strong>$clientName</strong>,</p>
        <p>You reported an issue with <strong>$collectorName</strong>'s pickup on <strong>$date</strong>.</p>
        <div style="background-color: #F8E4E2; padding: 15px; border-radius: 8px; margin: 15px 0;">
          <p style="margin: 0; color: #C1443D;"><strong>Reason:</strong> $reason</p>
        </div>
        <p>Your report has been submitted to the agency for review. You will be notified when there is an update.</p>
        <p style="color: #666; font-size: 12px;">Thank you for choosing WastePro!</p>
      </div>
      <div style="background-color: #0F3D2E; padding: 15px; border-radius: 0 0 10px 10px; text-align: center;">
        <p style="color: #aec0b7; margin: 0; font-size: 12px;">© 2026 WastePro — Smart Waste Collection</p>
      </div>
    </div>
    ''';
  }

  String _generalTemplate(String title, String message) {
    return '''
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background-color: #0F3D2E; padding: 20px; border-radius: 10px 10px 0 0;">
        <h1 style="color: #E8A33D; margin: 0; font-size: 24px;">🗑️ WastePro</h1>
      </div>
      <div style="background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd;">
        <h2 style="color: #0F3D2E;">$title</h2>
        <p>$message</p>
        <p style="color: #666; font-size: 12px;">Thank you for choosing WastePro!</p>
      </div>
      <div style="background-color: #0F3D2E; padding: 15px; border-radius: 0 0 10px 10px; text-align: center;">
        <p style="color: #aec0b7; margin: 0; font-size: 12px;">© 2026 WastePro — Smart Waste Collection</p>
      </div>
    </div>
    ''';
  }

  // ------------------------------------------------------------------
  // Logging
  // ------------------------------------------------------------------

  /// Logs an email attempt in Firestore for audit trail.
  Future<void> _logEmail({
    required String to,
    required String subject,
    required String type,
    required String status,
    Map<String, dynamic>? response,
    String? error,
  }) async {
    try {
      await _db.collection('email_logs').add({
        'to': to,
        'subject': subject,
        'type': type,
        'status': status,
        'response': response,
        'error': error,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Non-critical: logging failure should not block the flow.
      debugPrint('[EmailService] Failed to log email: $e');
    }
  }
}
