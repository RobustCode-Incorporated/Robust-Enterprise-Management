import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../../../core/session/session_service.dart';
import '../models/client_model.dart';

class ClientRepository {
  final http.Client client;
  // Optionnel pour rester compatible avec les tests existants qui
  // construisent ClientRepository sans session ; en usage réel, main.dart
  // fournit toujours la session connectée. Sans session, la requête part
  // simplement sans en-tête Authorization plutôt que d'utiliser un faux JWT
  // admin codé en dur comme avant.
  final SessionService? session;

  ClientRepository({required this.client, this.session});

  Future<ClientModel> createClient({
    required String name,
    String? email,
    String? phone,
  }) async {
    final url = ApiConfig.path('/sales/clients');

    final bodyData = {
      'name': name,
      'email': email,
      'phone': phone,
    };

    try {
      final response = await client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (session?.token != null) 'Authorization': 'Bearer ${session!.token}',
        },
        body: jsonEncode(bodyData),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);
        return ClientModel.fromJson(decodedData['client'] as Map<String, dynamic>);
      } else {
        throw Exception('Échec API (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur de connexion réseau : $e');
    }
  }
}