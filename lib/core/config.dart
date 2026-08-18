/// Configuration centrale de l'app.
///
/// La clé d'API CamPay est un jeton d'accès PERMANENT de l'application
/// CamPay (visible sous APP KEYS dans le dashboard demo.campay.net). Il est
/// injecté au build via `--dart-define` ; en l'absence de variable
/// d'environnement, on retombe sur la valeur de secours (clé de test).
class AppConfig {
  AppConfig._();

  /// Jeton d'accès permanent CamPay (test/demo).
  ///
  /// Injecté au build :
  /// ```
  /// flutter run --dart-define=CAMPAY_TOKEN=ts8iA9l6iFonQ0afyCYmRr1FKhCIdrnJ9C.1nvsb
  /// ```
  /// Sinon la valeur de secours (clé de démo fournie par l'utilisateur)
  /// est utilisée.
  static const String campayToken = String.fromEnvironment(
    'CAMPAY_TOKEN',
    defaultValue: 'ts8iA9l6iFonQ0afyCYmRr1FKhCIdrnJ9C.1nvsb',
  );

  static bool get hasCampayToken => campayToken.isNotEmpty;

  /// Hôte de l'API CamPay. `demo.campay.net` = environnement de test ;
  /// `www.campay.net` = production.
  static const String campayBaseUrl = String.fromEnvironment(
    'CAMPAY_BASE_URL',
    defaultValue: 'https://demo.campay.net',
  );

  /// Vrai quand l'app tourne contre le bac à sable CamPay (demo).
  static bool get isCampayDemo => campayBaseUrl.contains('demo');

  /// Plafond du bac à sable CamPay : chaque transaction est limitée à
  /// 25 XAF (réponse serveur `ER201` au-delà). En production
  /// (`www.campay.net`) il n'y a pas de plafond.
  static const double campayDemoMaxAmount = 25;

  /// Devise par défaut (Cameroun).
  static const String currency = 'XAF';
}
