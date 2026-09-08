import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'email_service.dart';
import 'sms_service.dart';
import 'whatsapp_service.dart';

/// Background message handler — must be a top-level function.
///
/// Called when a notification arrives while the app is in the background or
/// terminated.  Keep this lightweight: just log or persist; the foreground
/// listener handles UI updates.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  debugPrint(
    '[FCM] background message: ${message.messageId} '
    'title=${message.notification?.title}',
  );
}

/// Push notification service backed by Firebase Cloud Messaging (FCM).
///
/// Responsibilities:
///   1. Request permission (iOS / web).
///   2. Obtain and persist the FCM token in the user's Firestore profile
///      (`users/{phone}.fcmToken`) so the backend / Cloud Functions can
///      send targeted push messages.
///   3. Listen for foreground messages and expose them via a stream.
///   4. Handle notification taps (foreground, background, terminated).
class NotificationService {
  NotificationService({
    FirebaseFirestore? db,
    FirebaseMessaging? messaging,
    SmsService? smsService,
    EmailService? emailService,
    WhatsAppService? whatsappService,
  })  : _db = db ?? FirebaseFirestore.instance,
        _messaging = messaging ?? FirebaseMessaging.instance,
        _sms = smsService ?? SmsService(),
        _email = emailService ?? EmailService(),
        _whatsapp = whatsappService ?? WhatsAppService();

  final FirebaseFirestore _db;
  final FirebaseMessaging _messaging;
  final SmsService _sms;
  final EmailService _email;
  final WhatsAppService _whatsapp;

  // ------------------------------------------------------------------
  // Foreground message stream
  // ------------------------------------------------------------------

  /// Controller for foreground messages.
  final _foregroundController =
      StreamController<RemoteMessage>.broadcast();

  /// Stream of messages received while the app is in the foreground.
  Stream<RemoteMessage> get onForegroundMessage =>
      _foregroundController.stream;

  // ------------------------------------------------------------------
  // Initialization
  // ------------------------------------------------------------------

  /// Initializes FCM: requests permission, retrieves the token, stores it
  /// in Firestore, and sets up listeners.
  ///
  /// Call once after login (when we know the user's phone number).
  Future<void> initialize({required String userPhone}) async {
    try {
      // 1. Request permission (no-op on Android, critical on iOS / web).
      await _requestPermission();

      // 2. Get and persist the FCM token.
      final token = await _messaging.getToken();
      if (token != null) {
        await _persistToken(userPhone: userPhone, token: token);
      }

      // 3. Listen for token refresh (device re-registration, etc.).
      _messaging.onTokenRefresh.listen((newToken) {
        _persistToken(userPhone: userPhone, token: newToken);
      });

      // 4. Listen for foreground messages.
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
          '[FCM] foreground message: ${message.messageId} '
          'title=${message.notification?.title}',
        );
        _foregroundController.add(message);
      });

      // 5. Handle notification taps when the app is in the background.
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint(
          '[FCM] message opened from background: ${message.messageId}',
        );
        handleNotificationTap(message);
      });

      // 6. Check if the app was opened from a terminated state via a
      //    notification tap.
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint(
          '[FCM] app opened from terminated via notification: '
          '${initialMessage.messageId}',
        );
        // Delay slightly so the widget tree is ready.
        Future.delayed(
          const Duration(milliseconds: 500),
          () => handleNotificationTap(initialMessage),
        );
      }
    } catch (e) {
      debugPrint('[FCM] initialization error: $e');
    }
  }

  // ------------------------------------------------------------------
  // Permission
  // ------------------------------------------------------------------

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint(
      '[FCM] permission status: ${settings.authorizationStatus}',
    );
  }

  // ------------------------------------------------------------------
  // Token persistence
  // ------------------------------------------------------------------

  /// Stores the FCM token in the user's Firestore profile so Cloud
  /// Functions / backend can target this device.
  Future<void> _persistToken({
    required String userPhone,
    required String token,
  }) async {
    try {
      await _db.collection('users').doc(userPhone).set(
        {'fcmToken': token},
        SetOptions(merge: true),
      );
      debugPrint('[FCM] token persisted for $userPhone');
    } catch (e) {
      debugPrint('[FCM] failed to persist token: $e');
    }
  }

  // ------------------------------------------------------------------
  // Token retrieval
  // ------------------------------------------------------------------

  /// Returns the current FCM token (useful for debugging / testing).
  Future<String?> getFCMToken() => _messaging.getToken();

  // ------------------------------------------------------------------
  // Topic management
  // ------------------------------------------------------------------

  /// Subscribes this device to a broadcast topic (e.g. `'all_clients'`,
  /// `'agency_ag1'`).
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('[FCM] subscribed to topic: $topic');
  }

  /// Unsubscribes this device from a broadcast topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('[FCM] unsubscribed from topic: $topic');
  }

  // ------------------------------------------------------------------
  // Server-side helpers (called from Cloud Functions / admin SDK, not
  // from the client app — included here for documentation)
  // ------------------------------------------------------------------

  /// Sends a push notification to a specific user via Firestore.
  ///
  /// In production this should be done by a Cloud Function, not from the
  /// client.  Included here so the flow is documented and testable.
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _db.collection('push_notifications').add({
        'to': userId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[FCM] failed to queue notification: $e');
    }
  }

  /// Convenience: notify a collector that a new job is available.
  Future<void> sendJobNotification({
    required String collectorId,
    required String jobId,
    required String location,
  }) async {
    await sendNotificationToUser(
      userId: collectorId,
      title: 'New Pickup Available',
      body: 'A new waste collection job is available at $location.',
      data: {'type': 'job', 'jobId': jobId, 'location': location},
    );
  }

  // ------------------------------------------------------------------
  // Multi-channel notifications
  // ------------------------------------------------------------------

  /// Sends a pickup reminder across all configured channels.
  Future<void> sendPickupReminder({
    required String phone,
    required String clientName,
    required String date,
    required String time,
    String? email,
  }) async {
    // Push notification
    await sendNotificationToUser(
      userId: phone,
      title: 'Pickup Reminder',
      body: 'Your collection is scheduled for $date at $time.',
      data: {'type': 'pickup_reminder'},
    );

    // WhatsApp
    await _whatsapp.sendPickupReminder(
      phone: phone,
      clientName: clientName,
      date: date,
      time: time,
    );

    // SMS
    await _sms.sendPickupReminder(
      phone: phone,
      clientName: clientName,
      date: date,
      time: time,
    );

    // Email
    if (email != null && email.isNotEmpty) {
      await _email.sendPickupReminder(
        email: email,
        clientName: clientName,
        date: date,
        time: time,
      );
    }
  }

  /// Sends a payment confirmation across all configured channels.
  Future<void> sendPaymentConfirmation({
    required String phone,
    required String clientName,
    required double amount,
    required String plan,
    required String txRef,
    String? email,
  }) async {
    // Push notification
    await sendNotificationToUser(
      userId: phone,
      title: 'Payment Confirmed',
      body: 'Your payment of ${amount.toStringAsFixed(0)} XAF for $plan has been confirmed.',
      data: {'type': 'payment_confirmation'},
    );

    // WhatsApp
    await _whatsapp.sendPaymentConfirmation(
      phone: phone,
      clientName: clientName,
      amount: amount,
      plan: plan,
      txRef: txRef,
    );

    // SMS
    await _sms.sendPaymentConfirmation(
      phone: phone,
      clientName: clientName,
      amount: amount,
      plan: plan,
    );

    // Email
    if (email != null && email.isNotEmpty) {
      await _email.sendPaymentConfirmation(
        email: email,
        clientName: clientName,
        amount: amount,
        plan: plan,
        txRef: txRef,
      );
    }
  }

  /// Sends a subscription expiry warning across all configured channels.
  Future<void> sendSubscriptionExpiry({
    required String phone,
    required String clientName,
    required int daysLeft,
    required String expiryDate,
    String? email,
  }) async {
    // Push notification
    await sendNotificationToUser(
      userId: phone,
      title: 'Subscription Expiring',
      body: 'Your subscription expires in $daysLeft day(s). Renew now!',
      data: {'type': 'subscription_expiry'},
    );

    // WhatsApp
    await _whatsapp.sendSubscriptionExpiry(
      phone: phone,
      clientName: clientName,
      daysLeft: daysLeft,
      expiryDate: expiryDate,
    );

    // SMS
    await _sms.sendSubscriptionExpiry(
      phone: phone,
      clientName: clientName,
      daysLeft: daysLeft,
    );

    // Email
    if (email != null && email.isNotEmpty) {
      await _email.sendSubscriptionExpiry(
        email: email,
        clientName: clientName,
        daysLeft: daysLeft,
        expiryDate: expiryDate,
      );
    }
  }

  /// Sends a notification to the client asking them to validate a pickup
  /// that the collector has just completed.
  ///
  /// The client opens the app, sees the QR code containing the pickup info
  /// and taps “Scan code” to validate that the pickup actually happened.
  Future<void> sendPickupConfirmationRequest({
    required String phone,
    required String clientName,
    required String collectorName,
    required double poids,
    required String date,
    String pickupId = '',
    String? email,
  }) async {
    // Push notification
    await sendNotificationToUser(
      userId: phone,
      title: 'Validate your pickup',
      body: '$collectorName collected ${poids.toStringAsFixed(1)} kg from you today ($date).\r\nOpen the app and scan the QR code to validate — or report it if the pickup did not happen.',
      data: {
        'type': 'pickup_to_confirm',
        'pickupId': pickupId,
        'clientName': clientName,
        'collectorName': collectorName,
        'poids': poids.toString(),
        'date': date,
      },
    );

    // WhatsApp (free-form since the client already has an active session)
    await _whatsapp.sendPickupConfirmationRequest(
      phone: phone,
      clientName: clientName,
      collectorName: collectorName,
      poids: poids,
      date: date,
    );

    // SMS
    await _sms.sendPickupConfirmationRequest(
      phone: phone,
      clientName: clientName,
      collectorName: collectorName,
      poids: poids,
      date: date,
    );

    // Email
    if (email != null && email.isNotEmpty) {
      await _email.sendPickupConfirmationRequest(
        email: email,
        clientName: clientName,
        collectorName: collectorName,
        poids: poids,
        date: date,
      );
    }
  }

  /// Notifies the collector that the client scanned the QR code and
  /// validated the pickup (queued push — in-app tick handled live by the
  /// collector dashboard when it sees the pickup become `verified`).
  Future<void> sendPickupValidatedToCollector({
    required String collectorId,
    required String pickupId,
    required String clientName,
    required String clientPhone,
    required double poids,
    required String date,
  }) async {
    await sendNotificationToUser(
      userId: collectorId,
      title: 'Pickup validated from client $clientName ✓',
      body: 'The QR code was scanned: ${poids.toStringAsFixed(1)} kg collected on $date is confirmed by the client.',
      data: {
        'type': 'pickup_validated',
        'pickupId': pickupId,
        'clientName': clientName,
        'clientPhone': clientPhone,
        'poids': poids.toString(),
        'date': date,
      },
    );
  }

  /// Sends a pickup confirmation success notification when the client validates.
  Future<void> sendPickupConfirmed({
    required String phone,
    required String clientName,
    required String collectorName,
    required double poids,
    required String date,
    String? email,
  }) async {
    await sendNotificationToUser(
      userId: phone,
      title: 'Pickup confirmed',
      body: 'You confirmed the pickup of ${poids.toStringAsFixed(1)} kg by $collectorName.',
      data: {'type': 'pickup_confirmed'},
    );

    if (email != null && email.isNotEmpty) {
      await _email.sendPickupConfirmed(
        email: email,
        clientName: clientName,
        collectorName: collectorName,
        poids: poids,
        date: date,
      );
    }
  }

  /// Sends a pickup disputed notification.
  Future<void> sendPickupDisputed({
    required String phone,
    required String clientName,
    required String collectorName,
    required String reason,
    required String date,
    String? email,
  }) async {
    await sendNotificationToUser(
      userId: phone,
      title: 'Pickup disputed',
      body: 'You reported an issue with $collectorName\'s pickup ($date).',
      data: {'type': 'pickup_disputed'},
    );

    if (email != null && email.isNotEmpty) {
      await _email.sendPickupDisputed(
        email: email,
        clientName: clientName,
        collectorName: collectorName,
        reason: reason,
        date: date,
      );
    }
  }

  /// Sends a missed collection notification across all configured channels.
  Future<void> sendMissedCollection({
    required String phone,
    required String clientName,
    required String reason,
    String? email,
  }) async {
    // Push notification
    await sendNotificationToUser(
      userId: phone,
      title: 'Missed Collection',
      body: 'We were unable to collect your waste today ($reason).',
      data: {'type': 'missed_collection'},
    );

    // WhatsApp
    await _whatsapp.sendMissedCollection(
      phone: phone,
      clientName: clientName,
      reason: reason,
    );

    // SMS
    await _sms.sendMissedCollection(
      phone: phone,
      clientName: clientName,
      reason: reason,
    );

    // Email
    if (email != null && email.isNotEmpty) {
      await _email.sendGeneral(
        email: email,
        subject: 'Missed Collection',
        message: 'We were unable to collect your waste today ($reason). We will retry on the next scheduled day.',
      );
    }
  }

  /// Sends a general notification across all configured channels.
  Future<void> sendGeneralNotification({
    required String phone,
    required String title,
    required String message,
    String? email,
  }) async {
    // Push notification
    await sendNotificationToUser(
      userId: phone,
      title: title,
      body: message,
      data: {'type': 'general'},
    );

    // WhatsApp
    await _whatsapp.sendGeneral(
      phone: phone,
      message: '$title: $message',
    );

    // SMS
    await _sms.sendGeneral(phone: phone, message: '$title: $message');

    // Email
    if (email != null && email.isNotEmpty) {
      await _email.sendGeneral(
        email: email,
        subject: title,
        message: message,
      );
    }
  }

  // ------------------------------------------------------------------
  // Notification tap handling
  // ------------------------------------------------------------------

  /// Handles a notification tap — routes the user to the relevant screen.
  ///
  /// Uses the `data` payload to determine routing.  Extend this method as
  /// new notification types are added.
  ///
  /// Returns the screen constructor arguments needed, or null if no special
  /// routing is required.
  Map<String, dynamic>? handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String? ?? '';
    debugPrint('[FCM] notification tap: type=$type, data=$data');

    switch (type) {
      case 'pickup_to_confirm':
        return {
          'pickupId': data['pickupId'] as String? ?? '',
          'screen': 'pickup_confirmation',
        };
      default:
        return null;
    }
  }

  // ------------------------------------------------------------------
  // Cleanup
  // ------------------------------------------------------------------

  void dispose() {
    _foregroundController.close();
  }

  /// Removes the FCM token from Firestore on logout.
  Future<void> clearToken(String userPhone) async {
    try {
      await _db.collection('users').doc(userPhone).update({
        'fcmToken': FieldValue.delete(),
      });
      await _messaging.deleteToken();
      debugPrint('[FCM] token cleared for $userPhone');
    } catch (e) {
      debugPrint('[FCM] failed to clear token: $e');
    }
  }
}
