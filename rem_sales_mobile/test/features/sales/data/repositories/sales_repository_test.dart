import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:isar/isar.dart';
import 'package:rem_sales_mobile/features/sales/data/models/local_sales_document.dart';
import 'package:rem_sales_mobile/features/sales/data/models/sales_document_model.dart';
import 'package:rem_sales_mobile/features/sales/data/models/product_model.dart'; // 📦 AJOUT : Import du modèle de produit Isar
import 'package:rem_sales_mobile/features/sales/data/datasources/sync_manager.dart';
import 'package:rem_sales_mobile/features/sales/data/repositories/sales_repository.dart';

void main() {
  late Isar isar;
  late Directory tempDir;
  late SyncManager syncManager;
  late SalesRepository repository;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    tempDir = await Directory.systemTemp.createTemp('repo_test_dir');
  });

  setUp(() async {
    // 🛡️ MODIFICATION : Ajout de ProductModelSchema pour qu'Isar puisse gérer les produits dans la transaction
    isar = await Isar.open(
      [LocalSalesDocumentSchema, ProductModelSchema], 
      directory: tempDir.path,
    );
    
    // Faux client HTTP qui simule une réussite d'envoi API
    final mockHttpClient = MockClient((request) async {
      return http.Response('{"status": "success"}', 201);
    });
    
    syncManager = SyncManager(isar: isar, httpClient: mockHttpClient);
    repository = SalesRepository(isar: isar, syncManager: syncManager);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  group('REM-205 & Offline-First: SalesRepository Tests', () {
    
    test('🔴 TDD: Devrait enregistrer localement dans Isar ET lancer la synchronisation', () async {
      final newInvoice = SalesDocument(
        id: 'repo-uuid-111',
        type: 'INVOICE',
        number: 'FACT-REPO-001',
        status: 'DRAFT',
        totalAmount: 4500.0,
        createdAt: DateTime.now(),
      );

      // 🌱 Préparer un produit fictif en base Isar pour que la déduction automatique de stock fonctionne
      final testProduct = ProductModel(
        companyId: 'robust-corp-africa-123',
        name: 'Sac de Ciment 50kg',
        purchasePrice: 3500.0,
        sellingPrice: 4500.0,
        stockQuantity: 100, // Stock de départ
        code: 'CIM-50K',
      );

      await isar.writeTxn(() async {
        await isar.productModels.put(testProduct);
      });

      // 🛒 Simuler un panier contenant cet article
      final mockCart = [
        {
          'name': 'Sac de Ciment 50kg',
          'price': 4500.0,
          'quantity': 10, // Le client achète 10 sacs
        }
      ];

      // Act : On passe désormais le document ET le panier associé
      await repository.saveSalesDocument(newInvoice, mockCart);

      // Assertions locales (Facture)
      final localDoc = await isar.localSalesDocuments.filter().idEqualTo('repo-uuid-111').findFirst();
      expect(localDoc, isNotNull);
      expect(localDoc!.number, 'FACT-REPO-001');
      expect(localDoc.isSynced, isTrue); // Le SyncManager a réussi à l'envoyer

      // Assertions d'Inventaire (Vérifier que le stock a baissé de 10 unités : 100 - 10 = 90)
      final updatedProduct = await isar.productModels.filter().nameEqualTo('Sac de Ciment 50kg').findFirst();
      expect(updatedProduct, isNotNull);
      expect(updatedProduct!.stockQuantity, equals(90));
    });

    test('🔴 TDD: Devrait mettre à jour le statut à PAID en local et sur l\'API (Encaissement)', () async {
      // Pré-remplir la base avec une facture DRAFT
      final localDoc = LocalSalesDocument()
        ..id = 'invoice-uuid-456'
        ..type = 'INVOICE'
        ..number = 'FACT-REPO-002'
        ..status = 'DRAFT'
        ..totalAmount = 120000.0
        ..createdAt = DateTime.now()
        ..isSynced = true;

      await isar.writeTxn(() async => await isar.localSalesDocuments.put(localDoc));

      // Act : On encaisse la facture via le repository
      await repository.updateStatus(documentId: 'invoice-uuid-456', newStatus: 'PAID');

      // Assert : Le statut est bien mis à jour en local
      final updatedDoc = await isar.localSalesDocuments.filter().idEqualTo('invoice-uuid-456').findFirst();
      expect(updatedDoc!.status, 'PAID');
    });

  });
}