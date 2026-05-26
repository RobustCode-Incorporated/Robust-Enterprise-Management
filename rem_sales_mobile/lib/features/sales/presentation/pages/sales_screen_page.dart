import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rem_sales_mobile/features/sales/presentation/bloc/sales_bloc.dart';
import 'package:rem_sales_mobile/features/sales/presentation/bloc/sales_event.dart';
import 'package:rem_sales_mobile/features/sales/presentation/bloc/sales_state.dart';
import 'package:rem_sales_mobile/features/sales/data/models/sales_document_model.dart'; 
import 'package:rem_sales_mobile/features/sales/data/models/product_model.dart'; 
import 'package:rem_sales_mobile/features/sales/domain/services/receipt_service.dart'; // 📦 AJOUT : Import du service d'impression

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final List<String> _currencies = ['XOF', 'USD', 'EUR', 'CAD'];
  late String _selectedCurrency;

  // 🚀 INSTANCE : Initialisation de notre ReceiptService
  final ReceiptService _receiptService = ReceiptService();

  // 🛒 PANIER DYNAMIQUE : Contient les articles sélectionnés
  final List<Map<String, dynamic>> _dynamicCartItems = [];

  // 🛡️ MULTI-TENANT LOCAL : Pour simuler l'entreprise du commercial connecté (ex: Robust Capital Africa)
  final String _currentCompanyId = 'robust-corp-africa-123';

  @override
  void initState() {
    super.initState();
    _selectedCurrency = _currencies[0];

    // 🚀 BOOT : On demande au BLoC de charger immédiatement le catalogue d'articles Isar de cette entreprise
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SalesBloc>().add(LoadProductsEvent(_currentCompanyId));
    });
  }

  double _calculateTotal() {
    return _dynamicCartItems.fold(0, (sum, item) => sum + (item['price'] * item['quantity']));
  }

  // 📥 Logique métier d'ajout au panier avec garde-fou d'inventaire "Fail-Fast"
  void _addProductToCart(ProductModel product) {
    final existingIndex = _dynamicCartItems.indexWhere((item) => item['serverId'] == product.serverId || item['name'] == product.name);
    final currentQuantityInCart = existingIndex >= 0 ? _dynamicCartItems[existingIndex]['quantity'] : 0;

    // 🛡️ Blocage préventif si la demande excède le stock physique disponible
    if (currentQuantityInCart >= product.stockQuantity) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🛑 Impossible d\'ajouter plus de "${product.name}". Stock maximal atteint !'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      if (existingIndex >= 0) {
        _dynamicCartItems[existingIndex]['quantity'] += 1;
      } else {
        _dynamicCartItems.add({
          'serverId': product.serverId,
          'name': product.name,
          'price': product.sellingPrice,
          'quantity': 1,
        });
      }
    });
  }

  /// 📱 DIALOGUE DE GESTION DES REÇUS : Offre l'impression Bluetooth et le partage WhatsApp
  void _showReceiptDialog(SalesDocument document, List<Map<String, dynamic>> finalCartItems) {
    showDialog(
      context: context,
      barrierDismissible: false, // Force une action explicite pour fermer la modale
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Vente Enregistrée !',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Facture : ${document.number}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Montant total : ${_calculateTotal().toInt()} $_selectedCurrency', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                'Souhaitez-vous remettre un reçu au client ? Vous pouvez l\'imprimer en direct ou le partager sous format PDF.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fermer', style: TextStyle(color: Colors.grey)),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.indigo),
                  tooltip: 'Partager le PDF (WhatsApp...)',
                  onPressed: () async {
                    await _receiptService.shareReceipt(
                      document: document,
                      cartItems: finalCartItems,
                      currency: _selectedCurrency,
                    );
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('Imprimer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () async {
                    await _receiptService.printReceipt(
                      document: document,
                      cartItems: finalCartItems,
                      currency: _selectedCurrency,
                    );
                  },
                ),
              ],
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = _calculateTotal();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caisse & Catalogue REM'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: BlocListener<SalesBloc, SalesState>(
        listener: (context, state) {
          if (state is SalesSuccess) {
            // 🛡️ SÉCURITÉ DATA : On fait une copie profonde à la volée du panier avant de le resetter
            final List<Map<String, dynamic>> archivedCartItems = List.from(_dynamicCartItems);

            // Création d'un objet document factice temporaire mais aligné pour nourrir le générateur
            // S'il n'est pas fourni par l'état, on reconstruit ses informations clés.
            final completedDoc = SalesDocument(
              id: 'mob-uuid-${DateTime.now().microsecondsSinceEpoch}',
              type: 'INVOICE',
              number: 'FACT-${DateTime.now().millisecondsSinceEpoch}',
              status: 'PAID',
              totalAmount: totalAmount,
              createdAt: DateTime.now(),
            );

            // On vide le panier après encaissement réussi pour libérer l'UI
            setState(() {
              _dynamicCartItems.clear();
            });

            // 🚀 DÉCLENCHEMENT : Ouverture instantanée de la boîte de gestion du reçu
            _showReceiptDialog(completedDoc, archivedCartItems);
          } else if (state is SalesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('⚠️ Notification : ${state.message}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        },
        child: Column(
          children: [
            // 🌐 SECTION 1 : Sélecteur de Devise
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.payments_outlined, color: Colors.indigo),
                          SizedBox(width: 8),
                          Text('Devise :', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      DropdownButton<String>(
                        value: _selectedCurrency,
                        items: _currencies.map((String currency) {
                          return DropdownMenuItem<String>(
                            value: currency,
                            child: Text(currency, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedCurrency = newValue;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 📦 SECTION 2 : Le Catalogue Dynamique avec Alertes de Stock Visuelles
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.storefront, color: Colors.orange, size: 20),
                  SizedBox(width: 6),
                  Text('Catalogue d\'Articles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            
            SizedBox(
              height: 125,
              child: BlocBuilder<SalesBloc, SalesState>(
                buildWhen: (previous, current) => current is ProductsLoading || current is ProductsLoadSuccess,
                builder: (context, state) {
                  if (state is ProductsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (state is ProductsLoadSuccess) {
                    final products = state.products;
                    if (products.isEmpty) {
                      return const Center(child: Text('Aucun article dans le catalogue local.'));
                    }

                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        
                        final bool isOutOfStock = product.stockQuantity <= 0;
                        final bool isLowStock = !isOutOfStock && product.stockQuantity <= (product.minStockAlert ?? 5);

                        Color badgeColor = Colors.orange;
                        String badgeText = 'Stock: ${product.stockQuantity}';
                        if (isOutOfStock) {
                          badgeColor = Colors.red;
                          badgeText = 'Rupture';
                        } else if (isLowStock) {
                          badgeColor = Colors.redAccent;
                          badgeText = 'Alerte: ${product.stockQuantity}';
                        }

                        return GestureDetector(
                          onTap: () => _addProductToCart(product),
                          child: Opacity(
                            opacity: isOutOfStock ? 0.55 : 1.0,
                            child: Container(
                              width: 155,
                              margin: const EdgeInsets.only(right: 10, bottom: 8, top: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, spreadRadius: 1)],
                                border: Border.all(
                                  color: isOutOfStock 
                                      ? Colors.red.withOpacity(0.3) 
                                      : isLowStock 
                                          ? Colors.redAccent.withOpacity(0.3) 
                                          : Colors.indigo.withOpacity(0.1),
                                  width: (isOutOfStock || isLowStock) ? 1.5 : 1.0,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      product.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${product.sellingPrice.toInt()} $_selectedCurrency', 
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)
                                        ),
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withOpacity(0.12), 
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            badgeText, 
                                            style: TextStyle(fontSize: 9, color: badgeColor, fontWeight: FontWeight.bold)
                                          ),
                                        )
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }
                  return const Center(child: Text('Prêt à charger le catalogue...'));
                },
              ),
            ),

            // 🛒 SECTION 3 : Le Panier Courant
            Expanded(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🛒 Panier Actuel ($_selectedCurrency)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
                      ),
                      const Divider(),
                      Expanded(
                        child: _dynamicCartItems.isEmpty
                            ? const Center(child: Text('Le panier est vide. Tapez sur un article du catalogue !', style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                itemCount: _dynamicCartItems.length,
                                itemBuilder: (context, index) {
                                  final item = _dynamicCartItems[index];
                                  return ListTile(
                                    leading: const Icon(Icons.shopping_bag_outlined, color: Colors.indigo),
                                    title: Text(item['name']),
                                    subtitle: Text('${item['quantity']} x ${item['price']} $_selectedCurrency'),
                                    trailing: Text(
                                      '${item['quantity'] * item['price']} $_selectedCurrency',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('NET À PAYER :', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            Text(
                              '$totalAmount $_selectedCurrency',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 💳 SECTION 4 : Bouton de Validation / Encaissement
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: BlocBuilder<SalesBloc, SalesState>(
                buildWhen: (previous, current) => current is SalesLoading || current is SalesSuccess || current is SalesError,
                builder: (context, state) {
                  if (state is SalesLoading) {
                    return ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      child: const CircularProgressIndicator(),
                    );
                  }

                  return ElevatedButton.icon(
                    icon: const Icon(Icons.monetization_on),
                    label: const Text('ENCAISSER & SYNC (OFFLINE-FIRST)', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _dynamicCartItems.isEmpty ? null : () {
                      final uniqueDocNumber = 'FACT-${DateTime.now().millisecondsSinceEpoch}';
                      
                      final newDocument = SalesDocument(
                        id: 'mob-uuid-${DateTime.now().microsecondsSinceEpoch}',
                        type: 'INVOICE',
                        number: uniqueDocNumber,
                        status: 'DRAFT',
                        totalAmount: totalAmount,
                        createdAt: DateTime.now(),
                      );

                      context.read<SalesBloc>().add(SaveDocumentEvent(newDocument, _dynamicCartItems));
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}