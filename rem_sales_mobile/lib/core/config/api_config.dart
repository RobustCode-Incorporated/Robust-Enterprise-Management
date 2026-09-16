/// Point d'entrée unique de l'URL de base de l'API REM.
///
/// Avant ce fichier, 3 URLs différentes et incohérentes coexistaient dans le
/// code (une URL Codespaces morte dans AuthBloc, `localhost:3000` en dur
/// dans ClientRepository, un hôte fictif dans SyncManager). Toute nouvelle
/// requête HTTP doit construire son URL à partir de [ApiConfig.baseUrl].
class ApiConfig {
  ApiConfig._();

  /// Même valeur que `VITE_API_URL` côté web en production
  /// (rem_sales_web/.env : `https://rem-core-backend.onrender.com/api`).
  static const String baseUrl = String.fromEnvironment(
    'REM_API_BASE_URL',
    defaultValue: 'https://rem-core-backend.onrender.com/api',
  );

  static Uri path(String segment, [Map<String, String>? query]) {
    final normalized = segment.startsWith('/') ? segment : '/$segment';
    return Uri.parse('$baseUrl$normalized').replace(
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
  }
}
