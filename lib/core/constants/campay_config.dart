/// CamPay API configuration (loaded from `.env`).
///
/// Demo keys live in `.env` (gitignored). See `.env.example`.
/// Optional override: `--dart-define=CAMPAY_TOKEN=...`
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';

class CampayConfig {
  CampayConfig._();

  static String _env(String key, {String fallback = ''}) {
    const defines = {
      'CAMPAY_APP_ID': String.fromEnvironment('CAMPAY_APP_ID'),
      'CAMPAY_USERNAME': String.fromEnvironment('CAMPAY_USERNAME'),
      'CAMPAY_PASSWORD': String.fromEnvironment('CAMPAY_PASSWORD'),
      'CAMPAY_TOKEN': String.fromEnvironment('CAMPAY_TOKEN'),
      'CAMPAY_WEBHOOK_KEY': String.fromEnvironment('CAMPAY_WEBHOOK_KEY'),
      'CAMPAY_USE_DEMO': String.fromEnvironment('CAMPAY_USE_DEMO'),
    };

    final fromDefine = defines[key] ?? '';
    if (fromDefine.isNotEmpty) return fromDefine;

    if (dotenv.isInitialized) {
      final value = dotenv.env[key];
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return fallback;
  }

  static String get appId => _env('CAMPAY_APP_ID');

  static String get username => _env('CAMPAY_USERNAME');

  static String get password => _env('CAMPAY_PASSWORD');

  /// Permanent app token (optional). If set, `/token` is skipped.
  static String get permanentToken => _env('CAMPAY_TOKEN');

  static String get webhookKey => _env('CAMPAY_WEBHOOK_KEY');

  /// `true` = https://demo.campay.net — `false` = https://www.campay.net
  static bool get useDemo {
    final raw = _env('CAMPAY_USE_DEMO', fallback: 'true').toLowerCase();
    return raw != 'false' && raw != '0';
  }

  static String get baseUrl =>
      useDemo ? 'https://demo.campay.net/api' : 'https://www.campay.net/api';

  static bool get isConfigured =>
      permanentToken.isNotEmpty || (username.isNotEmpty && password.isNotEmpty);
}
