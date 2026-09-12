import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../core/config.dart';

/// Exception levée par l'API Campay (message exploitable côté UI).
class CampayApiException implements Exception {
  const CampayApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Client REST Campay — encaissement Mobile Money Cameroun.
class CampayApiService {
  CampayApiService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  String get _baseUrl {
    final env = dotenv.env['CAMPAY_ENV'] ?? 'demo';
    return env == 'production'
        ? 'https://www.campay.net/api'
        : 'https://demo.campay.net/api';
  }

  String get _username => dotenv.env['CAMPAY_USERNAME'] ?? '';
  String get _password => dotenv.env['CAMPAY_PASSWORD'] ?? '';
  String get _permanentToken =>
      (dotenv.env['CAMPAY_TOKEN'] ?? AppConfig.campayToken).trim();

  bool get isConfigured {
    if (_permanentToken.isNotEmpty) return true;
    final user = _username.trim();
    final pass = _password.trim();
    if (user.isEmpty || pass.isEmpty) return false;
    if (user.startsWith('your_') || pass.startsWith('your_')) return false;
    return true;
  }

  bool get isDemo => (dotenv.env['CAMPAY_ENV'] ?? 'demo') != 'production';

  Future<String> getToken() async {
    _ensureConfigured();
    if (_permanentToken.isNotEmpty) return _permanentToken;

    try {
      final response = await _dio.post(
        '$_baseUrl/token/',
        data: {
          'username': _username,
          'password': _password,
        },
      );
      final token = response.data['token'] as String?;
      if (token == null || token.isEmpty) {
        throw const CampayApiException(
          'Failed to obtain payment token. Check your Campay credentials.',
        );
      }
      return token;
    } on DioException catch (e) {
      throw CampayApiException(_dioErrorMessage(e));
    }
  }

  /// Envoie une demande de paiement via `POST /collect/`.
  ///
  /// Le client recevra une invite USSD sur son téléphone (MTN MoMo ou
  /// Orange Money) et devra confirmer avec son PIN.
  ///
  /// Retourne un map contenant notamment `reference` et `ussd_code`.
  Future<Map<String, dynamic>> requestPayment({
    required String token,
    required String phoneNumber,
    required num amount,
    String description = '',
    String? externalReference,
    String? pin,
  }) async {
    try {
      final body = <String, dynamic>{
        'amount': amount.toStringAsFixed(0), // Entiers uniquement (ER201).
        'currency': 'XAF',
        'from': phoneNumber,
        'description': description,
        'external_reference': externalReference ?? '',
      };
      if (pin != null && pin.isNotEmpty) {
        body['pin'] = pin;
      }
      final response = await _dio.post(
        '$_baseUrl/collect/',
        options: Options(headers: {'Authorization': 'Token $token'}),
        data: body,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['reference'] == null) {
        throw CampayApiException(
          data['message'] as String? ??
              data['detail'] as String? ??
              'Payment request failed (no reference returned).',
        );
      }
      return data;
    } on DioException catch (e) {
      throw CampayApiException(_dioErrorMessage(e));
    }
  }

  /// Interroge le statut d'une transaction via `GET /transaction/<ref>/`.
  ///
  /// Retourne un map contenant `status` (`PENDING`, `SUCCESSFUL`, `FAILED`).
  Future<Map<String, dynamic>> checkStatus({
    required String token,
    required String reference,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/transaction/$reference/',
        options: Options(headers: {'Authorization': 'Token $token'}),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw CampayApiException(_dioErrorMessage(e));
    }
  }

  /// Interroge périodiquement le statut d'une transaction jusqu'à un état
  /// final.
  ///
  /// - `interval` : délai entre chaque requête (défaut 4 s).
  /// - `timeoutSeconds` : durée maximale d'attente (défaut 120 s).
  ///
  /// Retourne `SUCCESSFUL`, `FAILED` ou `TIMEOUT`.
  Future<String> pollUntilResolved({
    required String token,
    required String reference,
    Duration interval = const Duration(seconds: 4),
    int timeoutSeconds = 120,
  }) async {
    final stopwatch = Stopwatch()..start();

    while (stopwatch.elapsed.inSeconds < timeoutSeconds) {
      await Future<void>.delayed(interval);

      try {
        final data = await checkStatus(token: token, reference: reference);
        final status = data['status'] as String? ?? '';
        if (status == 'SUCCESSFUL' || status == 'FAILED') {
          return status;
        }
        // PENDING → on continue à poller.
      } catch (_) {
        // Erreur réseau transitoire : on retente au prochain tick.
      }
    }

    return 'TIMEOUT';
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Normalise un numéro pour Campay : retire le `+` et les espaces.
  ///
  /// `+237 6XX XXX XXX` → `2376XXXXXXXX`
  static String normalizePhone(String phone) =>
      phone.replaceAll(RegExp(r'[^0-9]'), '');

  /// Génère une référence externe unique (préfixe + horodatage + aléatoire).
  static String newExternalReference(String prefix) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = (ts % 0xFFFFFF).toRadixString(16);
    return '$prefix-$ts-$rand';
  }

  void _ensureConfigured() {
    if (!isConfigured) {
      throw const CampayApiException(
        'Campay is not configured. Set CAMPAY_TOKEN or '
        'CAMPAY_USERNAME / CAMPAY_PASSWORD in your .env file.',
      );
    }
  }

  String _dioErrorMessage(DioException e) {
    if (e.response?.data != null) {
      final body = e.response!.data;
      if (body is Map<String, dynamic>) {
        return body['message'] as String? ??
            body['detail'] as String? ??
            'Campay API error (HTTP ${e.response?.statusCode}).';
      }
    }
    if (e.message?.contains('SocketException') == true ||
        e.message?.contains('Connection') == true) {
      return 'Network error. Check your internet connection.';
    }
    return 'Campay API error: ${e.message ?? "Unknown error"}';
  }
}
