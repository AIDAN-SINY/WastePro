import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'email_service.dart';
import 'sms_service.dart';

/// Two-factor authentication service for General Administrators.
///
/// Flow:
///   1. User logs in with phone + password (Firebase Auth)
///   2. If role requires 2FA → service generates 6-digit OTP
///   3. OTP is sent via SMS + Email (multi-channel for reliability)
///   4. OTP is stored in Firestore `two_factor_codes/{uid}` with 5-min expiry
///   5. User enters OTP → service verifies → grants access
///   6. Failed attempts are tracked; account locked after 5 failures
class TwoFactorService {
  TwoFactorService({
    FirebaseFirestore? db,
    SmsService? smsService,
    EmailService? emailService,
    this.devBypass = false,
  })  : _db = db ?? FirebaseFirestore.instance,
        _sms = smsService ?? SmsService(),
        _email = emailService ?? EmailService();

  final FirebaseFirestore _db;
  final SmsService _sms;
  final EmailService _email;

  /// DEV/TEST ONLY — quand `true`, le flux 2FA est entièrement local :
  /// aucun OTP n'est stocké dans Firestore ni envoyé par SMS/email
  /// (numéros de démo, et la collection `two_factor_codes` peut être
  /// restreinte par les règles déployées), et [verify] accepte n'importe
  /// quel code à 6 chiffres. Toujours `false` par défaut ; l'app ne
  /// l'active qu'en build de debug (`kDebugMode`). Jamais en production.
  final bool devBypass;

  /// OTP validity duration.
  static const Duration _otpTtl = Duration(minutes: 5);

  /// Max failed attempts before lockout.
  static const int _maxAttempts = 5;

  /// Lockout duration after max failed attempts.
  static const Duration _lockoutDuration = Duration(minutes: 15);

  /// Generates a 6-digit OTP code.
  String _generateOtp() {
    final rng = Random.secure();
    return List.generate(6, (_) => rng.nextInt(10)).join();
  }

  /// Checks if a user role requires 2FA.
  static bool requires2FA(String role) {
    return role.toLowerCase() == 'general_admin' ||
        role.toLowerCase() == 'super_admin';
  }

  /// Initiates 2FA: generates OTP, stores it, and sends via SMS + email.
  ///
  /// Returns `true` if OTP was sent successfully, `false` if the user is
  /// temporarily locked out.
  Future<bool> initiate({
    required String uid,
    required String phone,
    String? email,
    required String fullName,
  }) async {
    // DEV/TEST ONLY : rien à stocker ni envoyer — aucun accès Firestore
    // (les règles déployées peuvent refuser `two_factor_codes`), aucun SMS.
    if (devBypass) {
      debugPrint('[2FA] DEV BYPASS — OTP storage/sending skipped for $uid');
      return true;
    }

    // Check if user is locked out.
    final lockDoc = await _db.collection('two_factor_codes').doc(uid).get();
    if (lockDoc.exists) {
      final data = lockDoc.data()!;
      final lockedUntil = (data['lockedUntil'] as Timestamp?)?.toDate();
      if (lockedUntil != null && lockedUntil.isAfter(DateTime.now())) {
        final minsLeft = lockedUntil.difference(DateTime.now()).inMinutes;
        debugPrint('[2FA] User $uid is locked out for $minsLeft more minutes');
        return false;
      }
    }

    // Generate OTP.
    final otp = _generateOtp();
    final now = DateTime.now();
    final expiresAt = now.add(_otpTtl);

    // Store OTP in Firestore.
    await _db.collection('two_factor_codes').doc(uid).set({
      'uid': uid,
      'otp': otp,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'attempts': 0,
      'verified': false,
    });

    debugPrint('[2FA] OTP generated for $uid, sending via SMS + Email');

    // Send via SMS.
    final smsMessage = 'Your WastePro verification code is: $otp '
        'It expires in 5 minutes. Do not share this code.';
    _sms.sendSms(phone: phone, message: smsMessage, type: '2fa_otp');

    // Send via Email (if email is available).
    if (email != null && email.isNotEmpty) {
      _email.sendEmail(
        to: email,
        subject: 'WastePro — Your Verification Code',
        htmlContent: _otpEmailTemplate(fullName, otp),
        type: '2fa_otp',
      );
    }

    return true;
  }

  /// Verifies the OTP entered by the user.
  ///
  /// Returns `null` on success (OTP verified), or an error message string.
  /// After `_maxAttempts` failures, the user is temporarily locked out.
  Future<String?> verify({
    required String uid,
    required String enteredOtp,
  }) async {
    // DEV/TEST ONLY : en bypass, n'importe quel code à 6 chiffres passe —
    // aucun accès Firestore (les règles déployées peuvent refuser la
    // lecture), ni expiration, ni verrouillage. Ne s'applique jamais en
    // production (`devBypass` false par défaut).
    if (devBypass) {
      if (!RegExp(r'^\d{6}$').hasMatch(enteredOtp.trim())) {
        return 'Please enter the full 6-digit code.';
      }
      debugPrint('[2FA] DEV BYPASS — any code accepted for $uid');
      return null; // null = success
    }

    final doc = await _db.collection('two_factor_codes').doc(uid).get();
    if (!doc.exists) {
      return 'No verification code found. Please try logging in again.';
    }

    final data = doc.data()!;
    final storedOtp = data['otp'] as String? ?? '';
    final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
    int attempts = (data['attempts'] as num?)?.toInt() ?? 0;

    // Check if expired.
    if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
      await _db.collection('two_factor_codes').doc(uid).delete();
      return 'Verification code has expired. Please log in again to receive a new code.';
    }

    // Check if already verified.
    if (data['verified'] == true) {
      await _db.collection('two_factor_codes').doc(uid).delete();
      return null;
    }

    // Check if locked out.
    if (attempts >= _maxAttempts) {
      final lockedUntil = DateTime.now().add(_lockoutDuration);
      await _db.collection('two_factor_codes').doc(uid).update({
        'lockedUntil': Timestamp.fromDate(lockedUntil),
      });
      final minsLeft = _lockoutDuration.inMinutes;
      return 'Too many failed attempts. Please wait $minsLeft minutes and try again.';
    }

    // Verify OTP.
    if (enteredOtp.trim() == storedOtp) {
      // Success — mark as verified and clean up.
      await _db.collection('two_factor_codes').doc(uid).update({
        'verified': true,
      });
      // Delete after a short delay (allow the read to propagate).
      Future.delayed(const Duration(seconds: 2), () {
        _db.collection('two_factor_codes').doc(uid).delete();
      });
      debugPrint('[2FA] OTP verified successfully for $uid');
      return null; // null = success
    }

    // Wrong OTP — increment attempts.
    attempts++;
    await _db.collection('two_factor_codes').doc(uid).update({
      'attempts': attempts,
    });

    final remaining = _maxAttempts - attempts;
    if (remaining <= 0) {
      final lockedUntil = DateTime.now().add(_lockoutDuration);
      await _db.collection('two_factor_codes').doc(uid).update({
        'lockedUntil': Timestamp.fromDate(lockedUntil),
      });
      return 'Too many failed attempts. Account locked for ${_lockoutDuration.inMinutes} minutes.';
    }

    debugPrint('[2FA] Wrong OTP for $uid ($attempts/$_maxAttempts)');
    return 'Incorrect verification code. $remaining attempt(s) remaining.';
  }

  /// Resends the OTP (generates a new one).
  Future<bool> resend({
    required String uid,
    required String phone,
    String? email,
    required String fullName,
  }) async {
    // DEV/TEST ONLY : rien à supprimer ni régénérer côté Firestore.
    if (devBypass) return true;

    // Delete old OTP first.
    await _db.collection('two_factor_codes').doc(uid).delete();
    // Generate new one.
    return initiate(uid: uid, phone: phone, email: email, fullName: fullName);
  }

  /// Cleans up the 2FA record (called on logout).
  Future<void> cleanup(String uid) async {
    // DEV/TEST ONLY : aucun enregistrement n'a été écrit.
    if (devBypass) return;
    await _db.collection('two_factor_codes').doc(uid).delete();
  }

  /// HTML template for the OTP email.
  String _otpEmailTemplate(String name, String otp) {
    return '''
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background-color: #0F3D2E; padding: 20px; border-radius: 10px 10px 0 0;">
        <h1 style="color: #E8A33D; margin: 0; font-size: 24px;"> WastePro</h1>
      </div>
      <div style="background-color: #f9f9f9; padding: 20px; border: 1px solid #ddd;">
        <h2 style="color: #0F3D2E;"> Verification Code</h2>
        <p>Hello <strong>$name</strong>,</p>
        <p>Your two-factor authentication verification code is:</p>
        <div style="background-color: #E7EFE9; padding: 20px; border-radius: 8px; margin: 20px 0; text-align: center;">
          <p style="margin: 0; font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #0F3D2E;">$otp</p>
        </div>
        <p style="color: #666;">This code expires in <strong>5 minutes</strong>.</p>
        <p style="color: #666;">If you did not request this code, please secure your account immediately.</p>
      </div>
      <div style="background-color: #0F3D2E; padding: 15px; border-radius: 0 0 10px 10px; text-align: center;">
        <p style="color: #aec0b7; margin: 0; font-size: 12px;">© 2026 WastePro — Smart Waste Collection</p>
      </div>
    </div>
    ''';
  }
}
