import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../../../core/session/session_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final http.Client httpClient;
  final SessionService session;

  AuthBloc({
    required this.httpClient,
    required this.session,
  }) : super(AuthInitial()) {

    // Gestion de l'événement de démarrage
    on<AppStartedEvent>((event, emit) async {
      await session.loadFromStorage();
      if (session.token != null) {
        emit(Authenticated(token: session.token!));
      } else {
        emit(const Unauthenticated());
      }
    });

    // Gestion de la soumission du formulaire
    on<LoginSubmittedEvent>((event, emit) async {
      emit(AuthLoading());
      try {
        final response = await httpClient.post(
          ApiConfig.path('/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': event.email,
            'password': event.password,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final String token = data['token']; // On extrait le token du JSON du backend

          // 🔐 Sauvegarde chiffrée immédiate + décode des claims (companyId/role)
          await session.persistSession(token);

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
      await session.clear();
      emit(const Unauthenticated());
    });
  }
}