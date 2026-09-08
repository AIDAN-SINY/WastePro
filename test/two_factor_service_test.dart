import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_pro/services/email_service.dart';
import 'package:waste_pro/services/sms_service.dart';
import 'package:waste_pro/services/two_factor_service.dart';

/// Helper to create a TwoFactorService with fake Firestore.
TwoFactorService _makeService(FakeFirebaseFirestore db) => TwoFactorService(
      db: db,
      smsService: SmsService(db: db),
      emailService: EmailService(db: db),
    );

/// Extracts the OTP that was stored in Firestore by looking at the document.
Future<String?> _storedOtp(FakeFirebaseFirestore db, String uid) async {
  final doc = await db.collection('two_factor_codes').doc(uid).get();
  return doc.exists ? doc.data()!['otp'] as String? : null;
}

void main() {
  group('TwoFactorService.requires2FA', () {
    test('returns true for general_admin', () {
      expect(TwoFactorService.requires2FA('general_admin'), isTrue);
    });

    test('returns true for super_admin', () {
      expect(TwoFactorService.requires2FA('super_admin'), isTrue);
    });

    test('returns false for other roles', () {
      expect(TwoFactorService.requires2FA('client'), isFalse);
      expect(TwoFactorService.requires2FA('collector'), isFalse);
      expect(TwoFactorService.requires2FA('agency_manager'), isFalse);
    });

    test('is case-insensitive', () {
      expect(TwoFactorService.requires2FA('General_Admin'), isTrue);
      expect(TwoFactorService.requires2FA('SUPER_ADMIN'), isTrue);
    });
  });

  group('TwoFactorService.initiate', () {
    test('stores a 6-digit OTP in Firestore', () async {
      final db = FakeFirebaseFirestore();
      final service = _makeService(db);

      final sent = await service.initiate(
        uid: 'uid-123',
        phone: '+237677123456',
        fullName: 'Test Admin',
      );

      expect(sent, isTrue);
      final otp = await _storedOtp(db, 'uid-123');
      expect(otp, isNotNull);
      expect(otp!.length, 6);
      expect(int.tryParse(otp), isNotNull);
    });

    test('stores expiry and created timestamps', () async {
      final db = FakeFirebaseFirestore();
      final service = _makeService(db);

      await service.initiate(
        uid: 'uid-123',
        phone: '+237677123456',
        fullName: 'Test Admin',
      );

      final doc = await db.collection('two_factor_codes').doc('uid-123').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['createdAt'], isNotNull);
      expect(doc.data()!['expiresAt'], isNotNull);
      expect(doc.data()!['attempts'], 0);
      expect(doc.data()!['verified'], false);
    });
  });

  group('TwoFactorService.verify', () {
    test('returns null on correct OTP (success)', () async {
      final db = FakeFirebaseFirestore();
      final service = _makeService(db);

      await service.initiate(
        uid: 'uid-123',
        phone: '+237677123456',
        fullName: 'Test Admin',
      );

      final otp = await _storedOtp(db, 'uid-123');
      final error = await service.verify(uid: 'uid-123', enteredOtp: otp!);

      expect(error, isNull);
    });

    test('returns error on wrong OTP', () async {
      final db = FakeFirebaseFirestore();
      final service = _makeService(db);

      await service.initiate(
        uid: 'uid-123',
        phone: '+237677123456',
        fullName: 'Test Admin',
      );

      final error = await service.verify(uid: 'uid-123', enteredOtp: '000000');

      expect(error, isNotNull);
      expect(error, contains('Incorrect'));
    });

    test('returns error when no OTP exists', () async {
      final db = FakeFirebaseFirestore();
      final service = _makeService(db);

      final error = await service.verify(uid: 'nonexistent', enteredOtp: '123456');

      expect(error, contains('No verification code found'));
    });

    test('locks out after 5 failed attempts', () async {
      final db = FakeFirebaseFirestore();
      final service = _makeService(db);

      await service.initiate(
        uid: 'uid-123',
        phone: '+237677123456',
        fullName: 'Test Admin',
      );

      for (var i = 0; i < 5; i++) {
        await service.verify(uid: 'uid-123', enteredOtp: '000000');
      }

      final error = await service.verify(uid: 'uid-123', enteredOtp: '000000');
      expect(error, contains('wait'));
    });

    test('increments attempt counter on wrong OTP', () async {
      final db = FakeFirebaseFirestore();
      final service = _makeService(db);

      await service.initiate(
        uid: 'uid-123',
        phone: '+237677123456',
        fullName: 'Test Admin',
      );

      await service.verify(uid: 'uid-123', enteredOtp: '000000');
      await service.verify(uid: 'uid-123', enteredOtp: '000000');

      final doc = await db.collection('two_factor_codes').doc('uid-123').get();
      expect(doc.data()!['attempts'], 2);
    });

    test('marks as verified on success', () async {
      final db = FakeFirebaseFirestore();
      final service = _makeService(db);

      await service.initiate(
        uid: 'uid-123',
        phone: '+237677123456',
        fullName: 'Test Admin',
      );

      final otp = await _storedOtp(db, 'uid-123');
      await service.verify(uid: 'uid-123', enteredOtp: otp!);

      final doc = await db.collection('two_factor_codes').doc('uid-123').get();
      expect(doc.data()!['verified'], true);
    });
  });

  group('TwoFactorService devBypass (debug builds)', () {
    test('accepts ANY 6-digit code when devBypass is enabled', () async {
      final db = FakeFirebaseFirestore();
      final service = TwoFactorService(
        db: db,
        smsService: SmsService(db: db),
        emailService: EmailService(db: db),
        devBypass: true,
      );

      await service.initiate(
        uid: 'uid-123',
        phone: '+237677123456',
        fullName: 'Test Admin',
      );

      // A code that is NOT the stored one still passes.
      final error = await service.verify(uid: 'uid-123', enteredOtp: '000000');
      expect(error, isNull);
    });

    test('devBypass initiate performs NO Firestore write at all', () async {
      final db = FakeFirebaseFirestore();
      final service = TwoFactorService(
        db: db,
        smsService: SmsService(db: db),
        emailService: EmailService(db: db),
        devBypass: true,
      );

      final sent = await service.initiate(
        uid: 'uid-123',
        phone: '+237677123456',
        fullName: 'Test Admin',
      );

      expect(sent, isTrue);
      // Nothing stored — works even when Firestore rules deny writes.
      expect(
        (await db.collection('two_factor_codes').doc('uid-123').get()).exists,
        isFalse,
      );
    });

    test('devBypass verify performs NO Firestore read (rules may deny)',
        () async {
          final db = FakeFirebaseFirestore();
          final service = TwoFactorService(
            db: db,
            smsService: SmsService(db: db),
            emailService: EmailService(db: db),
            devBypass: true,
          );

          // No initiate() at all — verify still succeeds without any doc.
          final error = await service.verify(
            uid: 'never-written',
            enteredOtp: '987654',
          );
          expect(error, isNull);
        });



    test('still requires a 6-digit code when devBypass is enabled', () async {
      final db = FakeFirebaseFirestore();
      final service = TwoFactorService(
        db: db,
        smsService: SmsService(db: db),
        emailService: EmailService(db: db),
        devBypass: true,
      );

      final error = await service.verify(uid: 'uid-123', enteredOtp: '123');
      expect(error, isNotNull);
    });
  });

  group('TwoFactorService.resend', () {
    test('generates a new OTP (different from previous)', () async {
      final db = FakeFirebaseFirestore();
      final service = _makeService(db);

      await service.initiate(
        uid: 'uid-123',
        phone: '+237677123456',
        fullName: 'Test Admin',
      );
      final firstOtp = await _storedOtp(db, 'uid-123');

      await service.resend(
        uid: 'uid-123',
        phone: '+237677123456',
        fullName: 'Test Admin',
      );
      final secondOtp = await _storedOtp(db, 'uid-123');

      expect(firstOtp, isNotNull);
      expect(secondOtp, isNotNull);
      expect(secondOtp!.length, 6);
    });
  });

  group('TwoFactorService.cleanup', () {
    test('removes the OTP document', () async {
      final db = FakeFirebaseFirestore();
      final service = _makeService(db);

      await service.initiate(
        uid: 'uid-123',
        phone: '+237677123456',
        fullName: 'Test Admin',
      );

      expect(
        (await db.collection('two_factor_codes').doc('uid-123').get()).exists,
        isTrue,
      );

      await service.cleanup('uid-123');

      expect(
        (await db.collection('two_factor_codes').doc('uid-123').get()).exists,
        isFalse,
      );
    });
  });

  group('TwoFactorService locked-out user', () {
    test('returns false (locked) when initiate finds active lockout', () async {
      final db = FakeFirebaseFirestore();
      final service = _makeService(db);

      await db.collection('two_factor_codes').doc('uid-123').set({
        'uid': 'uid-123',
        'otp': '123456',
        'lockedUntil': DateTime.now().add(const Duration(minutes: 10)),
        'attempts': 5,
        'verified': false,
      });

      final sent = await service.initiate(
        uid: 'uid-123',
        phone: '+237677123456',
        fullName: 'Test Admin',
      );

      expect(sent, isFalse);
    });
  });
}
