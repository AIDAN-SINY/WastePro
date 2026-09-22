/// Payment Service — CamPay (Cameroon Mobile Money)
///
/// Flow:
/// 1. POST /token/          → temporary access token
/// 2. POST /collect/        → USSD push to subscriber phone (MTN / Orange)
/// 3. GET  /transaction/id/ → poll until SUCCESSFUL | FAILED
///
/// Docs: https://documenter.getpostman.com/view/2391374/T1LV8PVA
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../core/constants/campay_config.dart';
import '../models/transaction_model.dart';

class CampayException implements Exception {
  final String message;
  final int? statusCode;

  CampayException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class CampayCollectResult {
  final String reference;
  final String? ussdCode;
  final String? operator;
  final String? code;
  final String? operatorReference;
  final String status;
  final String externalReference;

  const CampayCollectResult({
    required this.reference,
    required this.status,
    required this.externalReference,
    this.ussdCode,
    this.operator,
    this.code,
    this.operatorReference,
  });

  bool get isSuccessful => status.toUpperCase() == 'SUCCESSFUL';
  bool get isFailed => status.toUpperCase() == 'FAILED';
  bool get isPending => status.toUpperCase() == 'PENDING';
}

class PaymentService {
  PaymentService({
    FirebaseFirestore? firestore,
    http.Client? httpClient,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _http = httpClient ?? http.Client();

  final FirebaseFirestore _db;
  final http.Client _http;
  final _uuid = const Uuid();

  String? _cachedToken;
  DateTime? _tokenExpiry;

  /// Collect payment via MTN MoMo or Orange Money (CamPay auto-detects operator).
  Future<CampayCollectResult> collectPayment({
    required String phone,
    required double amount,
    required String description,
    String currency = 'XAF',
    String? userId,
    bool waitForConfirmation = true,
    Duration timeout = const Duration(minutes: 2),
    Duration pollInterval = const Duration(seconds: 5),
  }) async {
    _ensureConfigured();

    final normalizedPhone = normalizeCameroonPhone(phone);
    final externalRef = _uuid.v4();
    final amountInt = amount.round();

    if (amountInt < 1) {
      throw CampayException('Amount must be at least 1 XAF');
    }

    final token = await _getAccessToken();
    final collectBody = {
      'amount': amountInt.toString(),
      'currency': currency,
      'from': normalizedPhone,
      'description': description,
      'external_reference': externalRef,
    };

    final response = await _http.post(
      Uri.parse('${CampayConfig.baseUrl}/collect/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(collectBody),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CampayException(
        _extractError(response.body) ??
            'CamPay collect failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final reference = (data['reference'] ?? '').toString();
    if (reference.isEmpty) {
      throw CampayException('CamPay did not return a transaction reference');
    }

    var result = CampayCollectResult(
      reference: reference,
      status: (data['status'] ?? 'PENDING').toString(),
      externalReference: externalRef,
      ussdCode: data['ussd_code']?.toString(),
      operator: data['operator']?.toString(),
    );

    if (userId != null) {
      await _saveTransaction(
        TransactionModel(
          id: reference,
          userId: userId,
          type: 'subscription',
          amount: amountInt.toDouble(),
          currency: currency,
          status: 'pending',
          paymentMethod: 'campay',
          createdAt: DateTime.now(),
          description: description,
        ),
        extra: {
          'externalReference': externalRef,
          'phone': normalizedPhone,
          'operator': result.operator,
          'ussdCode': result.ussdCode,
          'provider': 'campay',
        },
      );
    }

    if (waitForConfirmation) {
      result = await waitForPayment(
        reference: reference,
        timeout: timeout,
        pollInterval: pollInterval,
        userId: userId,
      );
    }

    return result;
  }

  /// Poll CamPay until the transaction is SUCCESSFUL or FAILED.
  Future<CampayCollectResult> waitForPayment({
    required String reference,
    Duration timeout = const Duration(minutes: 2),
    Duration pollInterval = const Duration(seconds: 5),
    String? userId,
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final status = await getTransactionStatus(reference);

      if (userId != null) {
        await _updateTransactionStatus(
          reference,
          _mapStatus(status.status),
          extra: {
            if (status.operator != null) 'operator': status.operator,
            if (status.code != null) 'campayCode': status.code,
            if (status.operatorReference != null)
              'operatorReference': status.operatorReference,
          },
        );
      }

      if (status.isSuccessful || status.isFailed) {
        return status;
      }

      await Future.delayed(pollInterval);
    }

    throw CampayException(
      'Payment timed out. Confirm on your phone (MTN *126# / Orange #150*50#) '
      'then retry status check. Ref: $reference',
    );
  }

  Future<CampayCollectResult> getTransactionStatus(String reference) async {
    _ensureConfigured();
    final token = await _getAccessToken();

    final response = await _http.get(
      Uri.parse('${CampayConfig.baseUrl}/transaction/$reference/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CampayException(
        _extractError(response.body) ??
            'Unable to check payment status (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return CampayCollectResult(
      reference: reference,
      status: (data['status'] ?? 'PENDING').toString(),
      externalReference: (data['external_reference'] ?? '').toString(),
      operator: data['operator']?.toString(),
      ussdCode: data['ussd_code']?.toString(),
      code: data['code']?.toString(),
      operatorReference: data['operator_reference']?.toString(),
    );
  }

  Future<Map<String, dynamic>> initiateMoMoPayment({
    required String phone,
    required double amount,
    required String currency,
    required String description,
    String? userId,
  }) async {
    final result = await collectPayment(
      phone: phone,
      amount: amount,
      currency: currency,
      description: description,
      userId: userId,
      waitForConfirmation: false,
    );
    return {
      'reference': result.reference,
      'status': result.status,
      'ussd_code': result.ussdCode,
      'operator': result.operator,
      'external_reference': result.externalReference,
    };
  }

  Future<Map<String, dynamic>> initiateOMPayment({
    required String phone,
    required double amount,
    required String currency,
    required String description,
    String? userId,
  }) {
    return initiateMoMoPayment(
      phone: phone,
      amount: amount,
      currency: currency,
      description: description,
      userId: userId,
    );
  }

  Future<bool> verifyPaymentStatus(String transactionId) async {
    final status = await getTransactionStatus(transactionId);
    return status.isSuccessful;
  }

  Future<List<Map<String, dynamic>>> getTransactionHistory(String userId) async {
    final snap = await _db
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .limit(100)
        .get();

    final rows = snap.docs.map((d) {
      final data = d.data();
      data['id'] = d.id;
      return data;
    }).toList();

    rows.sort((a, b) {
      final aTs = a['createdAt'];
      final bTs = b['createdAt'];
      final aDate = aTs is Timestamp ? aTs.toDate() : DateTime(1970);
      final bDate = bTs is Timestamp ? bTs.toDate() : DateTime(1970);
      return bDate.compareTo(aDate);
    });
    return rows;
  }

  Future<void> refundTransaction(String transactionId, double amount) async {
    throw CampayException(
      'Refunds are handled from the CamPay dashboard for reference $transactionId',
    );
  }

  /// Normalize to CamPay format: 2376XXXXXXXX
  static String normalizeCameroonPhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.startsWith('00237')) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('237') && digits.length >= 12) {
      return digits;
    }
    if (digits.startsWith('6') && digits.length == 9) {
      return '237$digits';
    }
    if (digits.length == 9) {
      return '237$digits';
    }

    throw CampayException(
      'Invalid Cameroon phone number. Use format 6XXXXXXXX or 2376XXXXXXXX',
    );
  }

  void _ensureConfigured() {
    if (!CampayConfig.isConfigured) {
      throw CampayException(
        'CamPay is not configured. Run with '
        '--dart-define=CAMPAY_USERNAME=... --dart-define=CAMPAY_PASSWORD=... '
        '(or CAMPAY_TOKEN=...)',
      );
    }
  }

  Future<String> _getAccessToken() async {
    if (CampayConfig.permanentToken.isNotEmpty) {
      return CampayConfig.permanentToken;
    }

    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken!;
    }

    final response = await _http.post(
      Uri.parse('${CampayConfig.baseUrl}/token/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': CampayConfig.username,
        'password': CampayConfig.password,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CampayException(
        _extractError(response.body) ??
            'Unable to authenticate with CamPay (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = (data['token'] ?? data['access_token'] ?? '').toString();
    if (token.isEmpty) {
      throw CampayException('CamPay token response was empty');
    }

    _cachedToken = token;
    _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));
    return token;
  }

  Future<void> _saveTransaction(
    TransactionModel tx, {
    Map<String, dynamic>? extra,
  }) async {
    await _db.collection('transactions').doc(tx.id).set({
      ...tx.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      ...?extra,
    });
  }

  Future<void> _updateTransactionStatus(
    String reference,
    String status, {
    Map<String, dynamic>? extra,
  }) async {
    await _db.collection('transactions').doc(reference).set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
      ...?extra,
    }, SetOptions(merge: true));
  }

  String _mapStatus(String campayStatus) {
    switch (campayStatus.toUpperCase()) {
      case 'SUCCESSFUL':
        return 'completed';
      case 'FAILED':
        return 'failed';
      default:
        return 'pending';
    }
  }

  String? _extractError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return (decoded['message'] ??
                decoded['detail'] ??
                decoded['error'] ??
                decoded['non_field_errors'])
            ?.toString();
      }
      if (decoded is List && decoded.isNotEmpty) {
        return decoded.first.toString();
      }
    } catch (_) {
      // ignore parse errors
    }
    if (body.trim().isEmpty) return null;
    return body.length > 180 ? '${body.substring(0, 180)}…' : body;
  }
}
