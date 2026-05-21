import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sales_document_model.dart';

class SalesRepository {
  // En local ou Codespaces, ajustez l'URL de votre API Express
  final String baseUrl = 'http://localhost:3000/api/sales';
  
  // Token de test temporaire mis à jour qui simule un ADMIN connecté (Boutique Africa)
  final String tempToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6InVzZXItdXVpZC05OTkiLCJlbWFpbCI6InRlc3RAYm91dGlxdWUuc24iLCJjb21wYW55SWQiOiJiZjMwY2QxMi05YzFkLTQwNzQtYjRhMC0wMDAwMDAwMDAwMDAiLCJyb2xlIjoiQURNSU4iLCJpYXQiOjE3NzkzODU1NDcsImV4cCI6MTc3OTM4OTE0N30.aYUAUn9-rISigHu4mj6tnGJIqFfsLXESeYKmG9oRook';

  Future<SalesDocument> sendDocumentToBackend({
    required String clientId,
    required String type,
    required double amount,
  }) async {
    final url = Uri.parse('$baseUrl/documents');

    // Préparation du corps de la requête attendu par votre contrôleur Node.js
    final Map<String, dynamic> bodyData = {
      'clientId': clientId,
      'type': type,
      'items': [
        {
          'description': 'Article Facturé via Mobile',
          'quantity': 1,
          'unitPrice': amount
        }
      ]
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tempToken',
        },
        body: jsonEncode(bodyData),
      );

      // Le code de succès d'une création HTTP est souvent 201 ou 200 selon le contrôleur
      if (response.statusCode == 201 || response.statusCode == 200) {
        final dynamic decodedData = jsonDecode(response.body);
        
        // Sécurisation PM : Extraction intelligente du document
        // Si le backend encapsule dans {'document': {...}} ou s'il l'envoie en direct à la racine
        Map<String, dynamic> documentJson;
        if (decodedData is Map<String, dynamic> && decodedData.containsKey('document')) {
          documentJson = decodedData['document'] as Map<String, dynamic>;
        } else if (decodedData is Map<String, dynamic>) {
          documentJson = decodedData;
        } else {
          throw Exception('Format de réponse JSON inconnu');
        }

        // On convertit le JSON nettoyé en modèle Dart
        return SalesDocument.fromJson(documentJson);
      } else {
        throw Exception('Échec API (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion réseau : $e');
    }
  }
}