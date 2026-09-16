import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import 'package:rem_sales_mobile/features/sales/data/models/local_sales_document.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/session/session_service.dart';

class SyncManager {
  final Isar isar;
  final http.Client httpClient;
  // Optionnel pour rester compatible avec les tests existants qui
  // construisent SyncManager sans session ; en usage réel, main.dart
  // fournit toujours la session connectée.
  final SessionService? session;

  SyncManager({
    required this.isar,
    required this.httpClient,
    this.session,
  });

  /// Tente de synchroniser un document spécifique avec le serveur central
  Future<void> synchronizeDocument(String documentId) async {
    // 1. Récupération du document dans le coffre-fort local Isar
    final localDoc = await isar.localSalesDocuments
        .filter()
        .idEqualTo(documentId)
        .findFirst();

    if (localDoc == null || localDoc.isSynced) {
      return; // Rien à faire si le document n'existe pas ou est déjà synchronisé
    }

    try {
      // 2. Préparation du payload JSON (transformation snake_case pour le backend PostgreSQL)
      final Map<String, dynamic> payload = {
        'id': localDoc.id,
        'type': localDoc.type,
        'number': localDoc.number,
        'status': localDoc.status,
        'total_amount': localDoc.totalAmount,
        'created_at': localDoc.createdAt.toIso8601String(),
      };

      // 3. Expédition de la requête avec clé d'idempotence pour éviter les doublons au backend
      // NOTE : le backend expose aussi POST /api/sales/sync (idempotent, dédié à
      // ce flux offline) dont le format de payload exact n'a pas encore été
      // vérifié ici — cible laissée sur /sales/documents pour cette phase
      // (correction de l'hôte/auth uniquement) ; à réévaluer séparément.
      final response = await httpClient.post(
        ApiConfig.path('/sales/documents'),
        headers: {
          'Content-Type': 'application/json',
          'X-Idempotency-Key': localDoc.id, // L'UUID local sert de clé d'idempotence
          if (session?.token != null) 'Authorization': 'Bearer ${session!.token}',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      // 4. Validation de la réponse du serveur
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Le serveur a traité et persisté la donnée. On passe au vert localement !
        await isar.writeTxn(() async {
          localDoc.isSynced = true;
          await isar.localSalesDocuments.put(localDoc);
        });
      } else {
        // Le serveur a répondu avec une erreur (ex: 500, 400).
        // On garde le document au chaud en local (isSynced = false) pour un retry ultérieur.
        _logError('Serveur a renvoyé un code ${response.statusCode}');
      }
    } on SocketException catch (e) {
      // Interception de la panne réseau (plus de 4G au marché de Sandaga)
      _logError('Panne réseau détectée, stockage local conservé : ${e.message}');
    } on http.ClientException catch (e) {
      _logError('Erreur client HTTP : ${e.message}');
    } catch (e) {
      // Sécurité générale pour éviter tout crash de l'application
      _logError('Erreur critique lors de la synchronisation : $e');
    }
  }

  void _logError(String message) {
    // Remplacé par un vrai logger (ex: Talker ou Logger package) en production
    print('[SyncManager] ⚠️ $message');
  }
}