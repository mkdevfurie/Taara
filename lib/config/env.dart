/// Configuration injectée à la compilation via `--dart-define`.
///
/// ```bash
/// flutter run \
///   --dart-define=GEMINI_API_KEY=xxxx \
///   --dart-define=TAARA_API_URL=https://api.taara.app/api/v1
/// ```
///
/// Aucun secret n'est versionné : sans clé, l'app fonctionne en mode
/// hors-ligne (cache + base de connaissances embarquée).
class Env {
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// URL de l'API TAARA (backend NestJS). Par défaut : backend local vu
  /// depuis l'émulateur Android (10.0.2.2 = localhost de la machine hôte).
  static const String apiBaseUrl = String.fromEnvironment(
    'TAARA_API_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );

  /// Site vitrine (politique de confidentialité). Vide = lien masqué dans l'app.
  static const String siteUrl = String.fromEnvironment('TAARA_SITE_URL');
}
