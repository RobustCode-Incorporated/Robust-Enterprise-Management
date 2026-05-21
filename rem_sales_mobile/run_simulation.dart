import 'lib/features/sales/presentation/bloc/sales_bloc.dart';
import 'lib/features/sales/presentation/pages/sales_pipeline_page.dart';

void main() async {
  print('==================================================');
  print('🚀 EXÉCUTION DE LA SIMULATION RÉSEAU REM SALES (LIVE)');
  print('==================================================\n');

  final bloc = SalesBloc();
  final ui = SalesPipelinePage(bloc: bloc);

  // Génération de faux UUID valides pour passer la validation stricte de PostgreSQL
  const String mockClientUuid1 = 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d';
  const String mockClientUuid2 = 'f6e5d4c3-b2a1-0f9e-8d7c-6b5a4f3e2d1c';

  // 1. État Initial
  ui.renderUI();

  // 2. Envoi d'un Devis au Backend Node.js avec un UUID Client valide
  print('[Action Mobile] Tentative de création d\'un Devis de 45,000 XOF...');
  await bloc.createDocument(mockClientUuid1, 'QUOTE', 45000.00);
  ui.renderUI();

  // 3. Envoi d\'une Facture au Backend Node.js avec un UUID Client valide
  print('\n[Action Mobile] Tentative de création d\'une Facture de 120,000 XOF...');
  await bloc.createDocument(mockClientUuid2, 'INVOICE', 120000.00);
  ui.renderUI();

  print('==================================================');
  print('✅ FIN DE LA SIMULATION RÉSEAU END-TO-END');
  print('==================================================');
}