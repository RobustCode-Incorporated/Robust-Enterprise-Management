import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rem_sales_mobile/features/sales/presentation/bloc/sales_bloc.dart';
import 'package:rem_sales_mobile/features/sales/presentation/bloc/sales_event.dart';
import 'package:rem_sales_mobile/features/sales/presentation/bloc/sales_state.dart';
// 🛡️ CORRECTION FINALE : Import direct et absolu du modèle via le package du projet
import 'package:rem_sales_mobile/features/sales/data/models/sales_document_model.dart'; 

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final List<String> _currencies = ['XOF', 'USD', 'EUR', 'CAD'];
  late String _selectedCurrency;

  final List<Map<String, dynamic>> _mockCartItems = [
    {'name': 'Sac de Ciment 50kg', 'price': 4500, 'quantity': 10},
    {'name': 'Fer à béton de 12', 'price': 5500, 'quantity': 5},
  ];

  @override
  void initState() {
    super.initState();
    _selectedCurrency = _currencies[0];
  }

  double _calculateTotal() {
    return _mockCartItems.fold(0, (sum, item) => sum + (item['price'] * item['quantity']));
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = _calculateTotal();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caisse & Facturation Offline'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: BlocListener<SalesBloc, SalesState>(
        listener: (context, state) {
          if (state is SalesSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🎉 Vente enregistrée avec succès en local (Isar) !'),
                backgroundColor: Colors.green,
              ),
            );
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
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    // 🛡️ CORRECTION : Remplacement de .between par .spaceBetween
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.payments_outlined, color: Colors.indigo),
                          SizedBox(width: 8),
                          Text(
                            'Devise de la transaction :',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
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
            Expanded(
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🛒 Panier Actuel ($_selectedCurrency)',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _mockCartItems.length,
                          itemBuilder: (context, index) {
                            final item = _mockCartItems[index];
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
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          // 🛡️ CORRECTION : Remplacement de .between par .spaceBetween
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('NET À PAYER :', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text(
                              '$totalAmount $_selectedCurrency',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: BlocBuilder<SalesBloc, SalesState>(
                builder: (context, state) {
                  if (state is SalesLoading) {
                    // 🛡️ CORRECTION : Retrait du mot-clé 'const' sur le styleFrom dynamique
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
                    onPressed: () {
                      final uniqueDocNumber = 'FACT-${DateTime.now().millisecondsSinceEpoch}';
                      
                      // 🛡️ CORRECTION : Désormais reconnu grâce au bon import au-dessus
                      final newDocument = SalesDocument(
                        id: 'mob-uuid-${DateTime.now().microsecondsSinceEpoch}',
                        type: 'INVOICE',
                        number: uniqueDocNumber,
                        status: 'DRAFT',
                        totalAmount: totalAmount,
                        createdAt: DateTime.now(),
                      );

                      context.read<SalesBloc>().add(SaveDocumentEvent(newDocument));
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