import 'package:isar/isar.dart';
import 'package:rem_sales_mobile/features/sales/data/models/local_sales_document.dart';
import 'package:rem_sales_mobile/features/sales/data/models/sales_document_model.dart';
import 'package:rem_sales_mobile/features/sales/data/models/product_model.dart'; 
import 'package:rem_sales_mobile/features/sales/data/datasources/sync_manager.dart';

class SalesRepository {
  final Isar isar;
  final SyncManager syncManager;

  SalesRepository({
    required this.isar,
    required this.syncManager,
  });

  /// 📦 Sauvegarde le document localement, déduit les stocks de manière ATOMIQUE
  /// et déclenche la synchronisation asynchrone.
  Future<void> saveSalesDocument(
    SalesDocument document, 
    List<Map<String, dynamic>> cartItems,
  ) async {
    // 1. Conversion du modèle de l'application vers le modèle Isar
    final localDoc = LocalSalesDocument.fromSalesDocument(document, synced: false);

    // 2. Écriture atomique dans le stockage local (Transaction unique "Tout ou Rien")
    await isar.writeTxn(() async {
      
      // 🔄 BOUCLE DE VÉRIFICATION ET DÉDUCTION DES STOCKS
      for (final item in cartItems) {
        final String productName = item['name'];
        final int quantityToDeduct = item['quantity'];

        // Recherche du produit correspondant dans Isar
        final product = await isar.productModels
            .filter()
            .nameEqualTo(productName)
            .findFirst();

        if (product == null) {
          throw Exception('Le produit "$productName" n\'existe plus dans le catalogue local.');
        }

        // 🛡️ CONTROLE DE RUPTURE : Sécurité d'inventaire
        if (product.stockQuantity < quantityToDeduct) {
          throw Exception(
            'Rupture de stock pour $productName. '
            'Disponible: ${product.stockQuantity}, Demandé: $quantityToDeduct'
          );
        }

        // Déduction de la quantité et mise à jour du produit dans la transaction
        product.stockQuantity -= quantityToDeduct;
        await isar.productModels.put(product);
      }

      // 📝 Sauvegarde finale de la facture uniquement si toutes les déductions ont réussi
      await isar.localSalesDocuments.put(localDoc);
    });

    // 3. Tentative de synchronisation en tâche de fond avec le backend
    await syncManager.synchronizeDocument(document.id);
  }

  /// 💳 JALON REM-205 : Met à jour le statut du document (ex: Passage à PAID lors d'un encaissement)
  Future<void> updateStatus({required String documentId, required String newStatus}) async {
    final localDoc = await isar.localSalesDocuments
        .filter()
        .idEqualTo(documentId)
        .findFirst();

    if (localDoc == null) {
      throw Exception('Document introuvable en local : $documentId');
    }

    await isar.writeTxn(() async {
      localDoc.status = newStatus;
      localDoc.isSynced = false; 
      await isar.localSalesDocuments.put(localDoc);
    });

    await syncManager.synchronizeDocument(documentId);
  }

  /// 📦 JALON INVENTORY : Récupérer les produits du catalogue pour une entreprise spécifique (Multi-Tenant)
  Future<List<ProductModel>> getProductsByCompany(String companyId) async {
    return await isar.productModels
        .filter()
        .companyIdEqualTo(companyId)
        .findAll();
  }

  /// 🌱 JALON INVENTORY : Seed Data : Injecter des produits de test si le catalogue local est complètement vide
  Future<void> seedProductsIfEmpty(String companyId) async {
    final count = await isar.productModels.count();
    if (count == 0) {
      final dummyProducts = [
        ProductModel(
          companyId: companyId,
          name: 'Sac de Ciment 50kg', // Ajusté pour correspondre exactement au libellé attendu par le UI test
          purchasePrice: 3500.0,
          sellingPrice: 4500.0,
          stockQuantity: 150,
          code: 'CIM-50K',
        ),
        ProductModel(
          companyId: companyId,
          name: 'Fer à béton ø12 (Barre de 12m)',
          purchasePrice: 4200.0,
          sellingPrice: 5200.0,
          stockQuantity: 80,
          code: 'FER-12MM',
        ),
        ProductModel(
          companyId: companyId,
          name: 'Pointe de charpente 100mm (Kg)',
          purchasePrice: 800.0,
          sellingPrice: 1200.0,
          stockQuantity: 25,
          minStockAlert: 5,
          code: 'PT-100',
        ),
      ];

      await isar.writeTxn(() async {
        await isar.productModels.putAll(dummyProducts);
      });
    }
  }
}