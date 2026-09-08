/// Central app configuration.
///
/// The CamPay API key is a PERMANENT access token for the CamPay application
/// (visible under APP KEYS in the demo.campay.net dashboard). It is
/// injected at build time via `--dart-define`; when no environment variable
/// is present, the fallback value (test key) is used.
class AppConfig {
  AppConfig._();

  /// Permanent CamPay access token (test/demo).
  ///
  /// Injected at build time:
  /// ```
  /// flutter run --dart-define=CAMPAY_TOKEN=ts8iA9l6iFonQ0afyCYmRr1FKhCIdrnJ9C.1nvsb
  /// ```
  /// Otherwise the fallback value (demo key provided by the user)
  /// is used.
  static const String campayToken = String.fromEnvironment(
    'CAMPAY_TOKEN',
    defaultValue: 'ts8iA9l6iFonQ0afyCYmRr1FKhCIdrnJ9C.1nvsb',
  );

  static bool get hasCampayToken => campayToken.isNotEmpty;

  /// CamPay API host. `demo.campay.net` = test environment;
  /// `www.campay.net` = production.
  static const String campayBaseUrl = String.fromEnvironment(
    'CAMPAY_BASE_URL',
    defaultValue: 'https://demo.campay.net',
  );

  /// True when the app is running against the CamPay sandbox (demo).
  static bool get isCampayDemo => campayBaseUrl.contains('demo');

  /// CamPay sandbox ceiling: each transaction is limited to
  /// 25 XAF (server response `ER201` beyond that). In production
  /// (`www.campay.net`) there is no ceiling.
  static const double campayDemoMaxAmount = 25;

  /// Default currency (Cameroon).
  static const String currency = 'XAF';
}
