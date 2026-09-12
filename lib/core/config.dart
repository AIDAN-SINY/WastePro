/// Central app configuration.
///
/// CamPay credentials can come from:
/// - `--dart-define=CAMPAY_TOKEN=...`
/// - `.env` (`CAMPAY_TOKEN`, `CAMPAY_USERNAME`, `CAMPAY_PASSWORD`, `CAMPAY_ENV`)
class AppConfig {
  AppConfig._();

  /// Permanent CamPay access token (test/demo).
  static const String campayToken = String.fromEnvironment(
    'CAMPAY_TOKEN',
    defaultValue: '',
  );

  static bool get hasCampayToken => campayToken.isNotEmpty;

  /// CamPay API host. `demo.campay.net` = test; `www.campay.net` = production.
  static const String campayBaseUrl = String.fromEnvironment(
    'CAMPAY_BASE_URL',
    defaultValue: 'https://demo.campay.net',
  );

  /// True when the app is running against the CamPay sandbox (demo).
  static bool get isCampayDemo => campayBaseUrl.contains('demo');

  /// Demo charge sent to CamPay while UI still shows full plan prices.
  static const double campayDemoMaxAmount = 1;

  /// Default currency (Cameroon).
  static const String currency = 'XAF';
}
