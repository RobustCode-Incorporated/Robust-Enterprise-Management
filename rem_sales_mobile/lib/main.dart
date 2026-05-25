import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http; // 🛡️ CORRECTION : Import du client HTTP standard
import 'features/sales/presentation/bloc/sales_bloc.dart';
import 'features/sales/presentation/pages/sales_screen_page.dart';
import 'features/sales/data/repositories/sales_repository.dart';
import 'features/sales/data/datasources/sync_manager.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final isarInstance = Isar.getInstance();
  late final Isar finalIsar;
  
  if (isarInstance != null) {
    finalIsar = isarInstance;
  } else {
    final directory = await getApplicationDocumentsDirectory();
    finalIsar = await Isar.open(
      [], // Insère tes schémas ici si nécessaire
      directory: directory.path, 
    );
  }

  // 🛡️ CORRECTION FINALE : On instancie le client HTTP standard
  final client = http.Client();

  // 🛡️ CORRECTION FINALE : On fournit à la fois Isar ET le httpClient requis !
  final syncManagerInstance = SyncManager(
    isar: finalIsar,
    httpClient: client, 
  ); 

  runApp(MyApp(isar: finalIsar, syncManager: syncManagerInstance));
}

class MyApp extends StatelessWidget {
  final Isar isar;
  final SyncManager syncManager;
  
  const MyApp({super.key, required this.isar, required this.syncManager});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Robust Enterprise Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: BlocProvider<SalesBloc>(
        create: (context) => SalesBloc(
          salesRepository: SalesRepository(
            isar: isar,
            syncManager: syncManager,
          ),
        ),
        child: const SalesScreen(),
      ),
    );
  }
}