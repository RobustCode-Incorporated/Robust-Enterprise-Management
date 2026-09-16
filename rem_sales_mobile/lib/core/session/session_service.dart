import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _tokenKey = 'jwt_token';

/// Session partagée par toute l'app : le token JWT et les claims qu'il
/// transporte (`id`, `companyId`, `role`), décodées une seule fois à la
/// connexion — exactement ce que fait déjà `DashboardStats.vue` côté web
/// (le backend ne renvoie pas ces champs à part, ils sont uniquement dans
/// le payload du JWT).
///
/// Avant ce service, aucune des repositories existantes ne lisait le vrai
/// token connecté (`ClientRepository` avait un JWT de test en dur), et
/// `companyId`/`resellerId` n'étaient stockés nulle part côté mobile.
class SessionService {
  SessionService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  /// Construit une session déjà peuplée, sans toucher au stockage — pour les
  /// tests (`SessionService.withSession(token: 'fake', role: 'STAFF')`).
  SessionService.withSession({
    required String token,
    String? userId,
    String? companyId,
    String? role,
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _token = token,
       _userId = userId,
       _companyId = companyId,
       _role = role;

  final FlutterSecureStorage _storage;

  String? _token;
  String? _userId;
  String? _companyId;
  String? _role;

  String? get token => _token;

  /// Identifiant utilisateur — aussi l'identifiant revendeur : le backend
  /// crée la ligne `resellers` avec le même UUID que la ligne `users`
  /// (voir `resellers.controller.createResellerWithAccess` côté backend).
  String? get userId => _userId;
  String? get companyId => _companyId;
  String? get role => _role;

  /// Les comptes revendeur/terrain portent le rôle `STAFF` côté backend
  /// (pas `RESELLER` — ce rôle existe dans le schéma mais son chemin de
  /// création n'est pas branché sur les routes réellement montées).
  bool get isReseller => _role == 'STAFF';

  bool get isLoggedIn => _token != null;

  /// À appeler au démarrage de l'app pour restaurer une session existante.
  Future<void> loadFromStorage() async {
    final storedToken = await _storage.read(key: _tokenKey);
    if (storedToken != null) _applyToken(storedToken);
  }

  /// À appeler juste après un login réussi.
  Future<void> persistSession(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    _applyToken(token);
  }

  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    _token = null;
    _userId = null;
    _companyId = null;
    _role = null;
  }

  void _applyToken(String token) {
    _token = token;
    final claims = _decodeClaims(token);
    _userId = claims?['id'] as String?;
    _companyId = claims?['companyId'] as String?;
    _role = claims?['role'] as String?;
  }

  /// Décode le payload d'un JWT sans vérifier la signature (le serveur l'a
  /// déjà vérifiée à l'émission) — juste pour lire `id`/`companyId`/`role`.
  Map<String, dynamic>? _decodeClaims(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      final decoded = jsonDecode(payload);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
