import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'features/sales/data/models/product_model.dart';
import 'features/sales/data/models/local_sales_document.dart';

import 'core/session/session_service.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/reseller_shell.dart';

// Imports Feature SALES
import 'features/sales/presentation/bloc/sales_bloc.dart';
import 'features/sales/data/repositories/sales_repository.dart';
import 'features/sales/data/datasources/sync_manager.dart';

// Imports Feature AUTH (Adaptés à ta nouvelle structure !)
import 'features/auth/presentation/pages/auth_bloc.dart';
import 'features/auth/presentation/pages/auth_event.dart';
import 'features/auth/presentation/pages/auth_state.dart';
import 'features/auth/presentation/pages/login_screen_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialisation Base Isar
  final isarInstance = Isar.getInstance();
  late final Isar finalIsar;

  if (isarInstance != null) {
    finalIsar = isarInstance;
  } else {
    final directory = await getApplicationDocumentsDirectory();
    finalIsar = await Isar.open(
      // ProductModelSchema : catalogue local (démo/offline).
      // LocalSalesDocumentSchema : ventes en attente de synchro — était
      // absent ici alors que SalesRepository/SyncManager l'utilisent déjà,
      // ce qui faisait planter tout accès à isar.localSalesDocuments.
      [ProductModelSchema, LocalSalesDocumentSchema],
      directory: directory.path,
    );
  }

  // 2. Initialisation des services requis
  final client = http.Client();
  const secureStorageInstance = FlutterSecureStorage(); // Coffre-fort JWT
  final sessionService = SessionService(storage: secureStorageInstance);
  final syncManagerInstance = SyncManager(
    isar: finalIsar,
    httpClient: client,
    session: sessionService,
  );

  runApp(MyApp(
    isar: finalIsar,
    syncManager: syncManagerInstance,
    httpClient: client,
    secureStorage: secureStorageInstance,
    session: sessionService,
  ));
}

class MyApp extends StatelessWidget {
  final Isar isar;
  final SyncManager syncManager;
  final http.Client httpClient;
  final FlutterSecureStorage secureStorage;
  final SessionService session;

  const MyApp({
    super.key,
    required this.isar,
    required this.syncManager,
    required this.httpClient,
    required this.secureStorage,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      // 📦 Injection globale des deux Blocs au sommet de l'application
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(
            httpClient: httpClient,
            session: session,
          )..add(AppStartedEvent()), // Vérifie dès le démarrage si le token existe
        ),
        BlocProvider<SalesBloc>(
          create: (context) => SalesBloc(
            salesRepository: SalesRepository(
              isar: isar,
              syncManager: syncManager,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Robust Enterprise Management',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.themeData,
        // 🔒 Aiguillage dynamique basé sur l'état d'authentification
        home: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is Authenticated) {
              return const ResellerShell(); // Connecté ➔ Coquille à onglets (Caisse incluse)
            }
            if (state is AuthLoading) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ); // Entre-deux ➔ Écran de chargement
            }
            // Par défaut (Initial ou Unauthenticated) ➔ Écran de Login
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}