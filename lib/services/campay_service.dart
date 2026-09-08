import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../core/config.dart';

/// Exception raised by the CamPay API (UI-friendly message).
class CampayException implements Exception {
  const CampayException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Transaction initiated by [CampayService.initCollect].
class CampayInitiatedTransaction {
  const CampayInitiatedTransaction({
    required this.reference,
    required this.ussdCode,
    required this.operator,
  });

  /// CamPay reference — used to query the status.
  final String reference;

  /// USSD code displayed to the client (e.g. `*126#` MTN, `#150*50#` Orange).
  final String ussdCode;

  /// Detected operator (`MTN` | `ORANGE`).
  final String operator;
}

/// Status of a queried CamPay transaction.
class CampayTransactionStatus {
  const CampayTransactionStatus({
    required this.reference,
    required this.status,
    this.amount = 0,
    this.currency = 'XAF',
    this.operator = '',
    this.code = '',
    this.operatorReference = '',
  });

  final String reference;

  /// `PENDING` | `SUCCESSFUL` | `FAILED`.
  final String status;

  final num amount;
  final String currency;
  final String operator;

  /// CamPay transaction code (e.g. `CP201027T00005`).
  final String code;

  /// Operator-side reference (MTN/Orange).
  final String operatorReference;

  bool get isPending => status == 'PENDING';
  bool get isSuccessful => status == 'SUCCESSFUL';
  bool get isFailed => status == 'FAILED';
}

/// REST client for CamPay — Cameroon Mobile Money collection (MTN MoMo /
/// Orange Money) via the public API.
///
/// Flow: [initCollect] sends a payment request to the client's number;
/// CamPay triggers a USSD prompt on their phone (they confirm with their
/// PIN). The app then polls [getTransactionStatus] until a terminal state
/// (SUCCESSFUL / FAILED).
///
/// Authentication: PERMANENT access token for the CamPay application
/// (APP KEYS), sent in the `Authorization: Token <token>` header.
class CampayService {
  CampayService({
    this.token = AppConfig.campayToken,
    this.baseUrl = AppConfig.campayBaseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Permanent CamPay access token.
  final String token;

  /// API host (demo.campay.net in test).
  final String baseUrl;

  final http.Client _client;

  /// True when a token has been configured.
  bool get isConfigured => token.isNotEmpty;

  /// Common headers.
  Map<String, String> _headers({bool json = true}) => {
        'Authorization': 'Token $token',
        if (json) 'Content-Type': 'application/json',
      };

  /// Initiates a collection for the number [from] (format `2376xxxxxxxx`,
  /// without `+`). Returns immediately with the reference + USSD code; the
  /// client must confirm on their phone.
  Future<CampayInitiatedTransaction> initCollect({
    required num amount,
    required String currency,
    required String from,
    required String description,
    required String externalReference,
  }) async {
    _ensureConfigured();
    final response = await _client.post(
      Uri.parse('$baseUrl/api/collect/'),
      headers: _headers(),
      body: jsonEncode({
        'amount': amount.toStringAsFixed(0), // Integers only (ER201).
        'currency': currency,
        'from': from,
        'description': description,
        'external_reference': externalReference,
      }),
    );
    final data = _decode(response);
    if (data['reference'] == null) {
      throw CampayException(_errorMessage(data, response));
    }
    return CampayInitiatedTransaction(
      reference: data['reference'] as String,
      ussdCode: data['ussd_code'] as String? ?? '',
      operator: data['operator'] as String? ?? '',
    );
  }

  /// Queries the status of an initiated transaction.
  Future<CampayTransactionStatus> getTransactionStatus(
    String reference,
  ) async {
    _ensureConfigured();
    final response = await _client.get(
      Uri.parse('$baseUrl/api/transaction/$reference/'),
      headers: _headers(json: false),
    );
    final data = _decode(response);
    if (data['status'] == null) {
      throw CampayException(_errorMessage(data, response));
    }
    return CampayTransactionStatus(
      reference: data['reference'] as String? ?? reference,
      status: data['status'] as String,
      amount: data['amount'] as num? ?? 0,
      currency: data['currency'] as String? ?? 'XAF',
      operator: data['operator'] as String? ?? '',
      code: data['code'] as String? ?? '',
      operatorReference: data['operator_reference'] as String? ?? '',
    );
  }

  /// Normalizes a phone number for CamPay: strips `+` and spaces
  /// (`+237 6XX XXX XXX` → `2376XXXXXXXX`).
  static String normalizePhone(String phone) =>
      phone.replaceAll(RegExp(r'[^0-9]'), '');

  /// Generates a unique external reference (prefix + ms timestamp + random).
  static String newExternalReference(String prefix) {
    final rand = Random().nextInt(0xFFFFFF);
    return '$prefix-${DateTime.now().millisecondsSinceEpoch}-$rand';
  }

  void _ensureConfigured() {
    if (!isConfigured) {
      throw const CampayException(
        'CamPay is not configured. Build the app with '
        '--dart-define=CAMPAY_TOKEN=<your app token>.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return const {};
  }

  String _errorMessage(
    Map<String, dynamic> data,
    http.Response response,
  ) {
    final message = data['message'] ?? data['detail'] ?? '';
    if (message is String && message.isNotEmpty) return message;
    return 'CamPay error (HTTP ${response.statusCode}).';
  }
}
