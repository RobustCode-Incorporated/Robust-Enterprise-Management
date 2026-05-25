import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:isar/isar.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rem_sales_mobile/main.dart';
import 'package:rem_sales_mobile/features/sales/data/datasources/sync_manager.dart';

// Création des mocks nécessaires pour simuler le démarrage de MyApp
class MockIsar extends Mock implements Isar {}
class MockSyncManager extends Mock implements SyncManager {}
class MockHttpClient extends Mock implements http.Client {}
class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  testWidgets('🚀 [CORE TEST] L\'application charge l\'infrastructure REM initiale avec succès', (WidgetTester tester) async {
    final mockIsar = MockIsar();
    final mockSyncManager = MockSyncManager();
    final mockHttpClient = MockHttpClient();
    final mockSecureStorage = MockSecureStorage();

    // On simule une lecture vide dans le stockage chiffré pour forcer l'état Unauthenticated au boot
    when(() => mockSecureStorage.read(key: 'jwt_token')).thenAnswer((_) => Future.value(null));

    // Lancement virtuel de l'application complète
    await tester.pumpWidget(MyApp(
      isar: mockIsar,
      syncManager: mockSyncManager,
      httpClient: mockHttpClient,
      secureStorage: mockSecureStorage,
    ));

    // Simple vérification que le moteur de rendu a démarré sans planter
    expect(find.byType(MyApp), findsOneWidget);
  });
}