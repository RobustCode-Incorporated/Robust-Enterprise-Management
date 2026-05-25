import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final http.Client httpClient;
  final FlutterSecureStorage secureStorage;
  
  // URL de ton serveur backend (à adapter selon ton déploiement)
  // En local Codespace, on utilise souvent l'URL publique générée ou l'IP du conteneur
  final String authUrl = 'https://animated-lamp-pjppjx9p9pqg367vg-3000.app.github.dev/'; 

  AuthBloc({
    required this.httpClient,
    required this.secureStorage,
  }) : super(AuthInitial()) {
    
    // Gestion de l'événement de démarrage
    on<AppStartedEvent>((event, emit) async {
      final token = await secureStorage.read(key: 'jwt_token');
      if (token != null) {
        emit(Authenticated(token: token));
      } else {
        emit(const Unauthenticated());
      }
    });

    // Gestion de la soumission du formulaire
    on<LoginSubmittedEvent>((event, emit) async {
      emit(AuthLoading());
      try {
        final response = await httpClient.post(
          Uri.parse(authUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': event.email,
            'password': event.password,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final token = data['token']; // On extrait le token du JSON du backend

          // 🔐 Sauvegarde chiffrée immédiate dans le téléphone
          await secureStorage.write(key: 'jwt_token', value: token);
          
          emit(Authenticated(token: token));
        } else {
          final data = jsonDecode(response.body);
          emit(Unauthenticated(errorMessage: data['message'] ?? 'Identifiants invalides'));
        }
      } catch (e) {
        emit(const Unauthenticated(errorMessage: 'Impossible de joindre le serveur de sécurité.'));
      }
    });

    // Gestion de la déconnexion
    on<LogoutRequestedEvent>((event, emit) async {
      emit(AuthLoading());
      await secureStorage.delete(key: 'jwt_token');
      emit(const Unauthenticated());
    });
  }
}