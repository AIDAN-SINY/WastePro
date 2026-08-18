import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../core/config.dart';

/// Exception levée par l'API CamPay (message exploitable côté UI).
class CampayException implements Exception {
  const CampayException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Transaction initiée par [CampayService.initCollect].
class CampayInitiatedTransaction {
  const CampayInitiatedTransaction({
    required this.reference,
    required this.ussdCode,
    required this.operator,
  });

  /// Référence CamPay — sert à interroger le statut.
  final String reference;

  /// Code USSD affiché au client (ex. `*126#` MTN, `#150*50#` Orange).
  final String ussdCode;

  /// Opérateur détecté (`MTN` | `ORANGE`).
  final String operator;
}

/// Statut d'une transaction CamPay interrogée.
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

  /// Code de transaction CamPay (ex. `CP201027T00005`).
  final String code;

  /// Référence côté opérateur (MTN/Orange).
  final String operatorReference;

  bool get isPending => status == 'PENDING';
  bool get isSuccessful => status == 'SUCCESSFUL';
  bool get isFailed => status == 'FAILED';
}

/// Client REST CamPay — encaissement Mobile Money Cameroun (MTN MoMo /
/// Orange Money) via l'API publique.
///
/// Flux : [initCollect] envoie une demande de paiement au numéro du client ;
/// CamPay déclenche une invite USSD sur son téléphone (il confirme avec son
/// PIN). L'app interroge ensuite [getTransactionStatus] jusqu'à un état
/// final (SUCCESSFUL / FAILED).
///
/// Authentification : jeton d'accès PERMANENT de l'application CamPay
/// (APP KEYS), envoyé dans l'en-tête `Authorization: Token <jeton>`.
class CampayService {
  CampayService({
    this.token = AppConfig.campayToken,
    this.baseUrl = AppConfig.campayBaseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Jeton d'accès permanent CamPay.
  final String token;

  /// Hôte API (demo.campay.net en test).
  final String baseUrl;

  final http.Client _client;

  /// Vrai quand un jeton a été configuré.
  bool get isConfigured => token.isNotEmpty;

  /// En-têtes communs.
  Map<String, String> _headers({bool json = true}) => {
        'Authorization': 'Token $token',
        if (json) 'Content-Type': 'application/json',
      };

  /// Initie un encaissement auprès du numéro [from] (format `2376xxxxxxxx`,
  /// sans `+`). Retourne immédiatement la référence + code USSD ; le client
  /// doit confirmer sur son téléphone.
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
        'amount': amount.toStringAsFixed(0), // Entiers uniquement (ER201).
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

  /// Interroge le statut d'une transaction initiée.
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

  /// Normalise un numéro pour CamPay : retire le `+` et les espaces
  /// (`+237 6XX XXX XXX` → `2376XXXXXXXX`).
  static String normalizePhone(String phone) =>
      phone.replaceAll(RegExp(r'[^0-9]'), '');

  /// Génère une référence externe unique (préfixe + horodatage ms + aléa).
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
