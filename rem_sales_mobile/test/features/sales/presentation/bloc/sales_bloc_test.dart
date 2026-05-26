import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart'; 
import 'package:rem_sales_mobile/features/sales/data/models/sales_document_model.dart';
import 'package:rem_sales_mobile/features/sales/data/repositories/sales_repository.dart';
import 'package:rem_sales_mobile/features/sales/presentation/bloc/sales_bloc.dart';
import 'package:rem_sales_mobile/features/sales/presentation/bloc/sales_event.dart';
import 'package:rem_sales_mobile/features/sales/presentation/bloc/sales_state.dart';

// 1. On crée un conteneur Fake pour que Mocktail comprenne le type SalesDocument
class FakeSalesDocument extends Fake implements SalesDocument {}

class MockSalesRepository extends Mock implements SalesRepository {}

void main() {
  late MockSalesRepository mockSalesRepository;
  late SalesBloc salesBloc;

  // 2. On enregistre le fallback au tout début, AVANT que les tests ne s'exécutent
  setUpAll(() {
    registerFallbackValue(FakeSalesDocument());
  });

  setUp(() {
    mockSalesRepository = MockSalesRepository();
    salesBloc = SalesBloc(salesRepository: mockSalesRepository);
  });

  tearDown(() {
    salesBloc.close();
  });

  group('REM-205 / UI State: SalesBloc Tests', () {
    final testDocument = SalesDocument(
      id: 'bloc-uuid-000',
      type: 'INVOICE',
      number: 'FACT-BLOC-001',
      status: 'DRAFT',
      totalAmount: 50000.0,
      createdAt: DateTime.now(),
    );

    blocTest<SalesBloc, SalesState>(
      'Devrait émettre [SalesLoading, SalesSuccess] quand la sauvegarde réussit',
      build: () {
        when(() => mockSalesRepository.saveSalesDocument(any(), any()))
            .thenAnswer((_) async => {});
        return salesBloc;
      },
      act: (bloc) => bloc.add(SaveDocumentEvent(testDocument, const [])),
      expect: () => [
        isA<SalesLoading>(),
        isA<SalesSuccess>(),
      ],
      verify: (_) {
        verify(() => mockSalesRepository.saveSalesDocument(any(), any())).called(1);
      },
    );
  });
}