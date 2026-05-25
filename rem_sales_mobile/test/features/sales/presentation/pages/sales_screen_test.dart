import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rem_sales_mobile/features/sales/presentation/bloc/sales_bloc.dart';
import 'package:rem_sales_mobile/features/sales/presentation/bloc/sales_event.dart';
import 'package:rem_sales_mobile/features/sales/presentation/bloc/sales_state.dart';
import 'package:rem_sales_mobile/features/sales/presentation/pages/sales_screen_page.dart';
import 'package:rem_sales_mobile/features/sales/data/models/sales_document_model.dart';

// Mock du SalesBloc pour contrôler ses états pendant le test de l'UI
class MockSalesBloc extends Mock implements SalesBloc {}

void main() {
  late MockSalesBloc mockSalesBloc;

  setUpAll(() {
    registerFallbackValue(SaveDocumentEvent(SalesDocument(
      id: '1',
      type: 'INVOICE',
      number: 'FACT-TEST',
      status: 'DRAFT',
      totalAmount: 0,
      createdAt: DateTime.now(),
    )));
  });

  setUp(() {
    mockSalesBloc = MockSalesBloc();
    // Par défaut, le Bloc est à l'état initial
    when(() => mockSalesBloc.state).thenReturn(SalesInitial());
    when(() => mockSalesBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  testWidgets('📱 [UI TEST] Le panier affiche la devise sélectionnée et émet l\'événement d\'encaissement', (WidgetTester tester) async {
    print('--- 🧪 START: Test de l\'interface de caisse et multi-devise ---');

    // 1. Charger le widget de vente dans le moteur de rendu virtuel de Flutter
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<SalesBloc>.value(
          value: mockSalesBloc,
          child: const SalesScreen(),
        ),
      ),
    );

    // 2. Vérifier que l'écran affiche les éléments de base du panier
    expect(find.text('🛒 Panier Actuel (XOF)'), findsOneWidget);
    expect(find.text('Sac de Ciment 50kg'), findsOneWidget);
    print('✅ [UI] Panier et devise initiale (XOF) correctement affichés à l\'écran.');

    // 3. Simuler le clic sur le menu déroulant des devises pour choisir "USD"
    final dropdownFinder = find.byType(DropdownButton<String>);
    expect(dropdownFinder, findsOneWidget);
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle(); // Attendre l'animation d'ouverture du menu

    // Sélectionner USD dans la liste
    final usdItemFinder = find.text('USD').last;
    await tester.tap(usdItemFinder);
    await tester.pumpAndSettle(); // Attendre la reconstruction de l'UI

    // 4. Vérifier que l'interface a bien changé de monnaie dynamiquement
    expect(find.text('🛒 Panier Actuel (USD)'), findsOneWidget);
    print('✅ [UI] Sélecteur dynamique validé : Le panier s\'est mis à jour en (USD) !');

    // 5. Simuler le clic sur le gros bouton vert "ENCAISSER & SYNC"
    final buttonFinder = find.byType(ElevatedButton);
    await tester.tap(buttonFinder);
    await tester.pump();

    // 6. Vérifier que l'UI a bien envoyé l'ordre d'enregistrement au SalesBloc
    verify(() => mockSalesBloc.add(any(that: isA<SaveDocumentEvent>()))).called(1);
    print('✅ [UI] Bouton Encaisser validé : L\'événement d\'enregistrement offline a bien été envoyé au BLoC !');
    print('------------------------------------------------------------------\n');
  });
}