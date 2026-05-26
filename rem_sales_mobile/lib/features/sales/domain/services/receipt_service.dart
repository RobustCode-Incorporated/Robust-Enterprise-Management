import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:rem_sales_mobile/features/sales/data/models/sales_document_model.dart';

class ReceiptService {
  /// 📄 Génère le document PDF au format ticket de caisse vertical
  Future<pw.Document> generateReceiptPdf({
    required SalesDocument document,
    required List<Map<String, dynamic>> cartItems,
    required String currency,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    // Calcul du sous-total et de la quantité totale d'articles
    final int totalItemsCount = cartItems.fold(0, (sum, item) => sum + (item['quantity'] as int));

    pdf.addPage(
      pw.Page(
        // 📏 Configuration optimale pour ticket de caisse (format rouleau continu)
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start, // 💡 CORRIGÉ : 'crossAxisAlignment' au lieu de 'cross'
            children: [
              // 🏦 ENTÊTE DE L'ENTREPRISE
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'ROBUST ENTERPRISE',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text('Management System', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Kinshasa - Bruxelles', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    pw.SizedBox(height: 6),
                    pw.Text('------------------------------------------', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),

              // 📝 INFOS DU TICKET
              pw.Text('Doc: ${document.number}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.Text('Date: ${dateFormat.format(document.createdAt)}', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Statut: ${document.status} (OFFLINE-CONFIRMED)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.green700)),
              pw.SizedBox(height: 4),
              pw.Text('------------------------------------------', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 4),

              // 🛒 LISTE DES ARTICLES
              pw.Text('ARTICLES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
              pw.SizedBox(height: 4),
              pw.ListView.builder(
                itemCount: cartItems.length,
                itemBuilder: (pw.Context context, int index) {
                  final item = cartItems[index];
                  final double price = (item['price'] as num).toDouble();
                  final int qty = item['quantity'] as int;
                  final double lineTotal = price * qty;

                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start, // 💡 CORRIGÉ : 'crossAxisAlignment' au lieu de 'cross'
                      children: [
                        pw.Text(item['name'] ?? 'Article inconnu', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('$qty x ${price.toInt()} $currency', style: const pw.TextStyle(fontSize: 8)),
                            pw.Text('${lineTotal.toInt()} $currency', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              pw.SizedBox(height: 4),
              pw.Text('------------------------------------------', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 4),

              // 💰 RECAPITULATIF FINANCIER
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Nombre d\'articles :', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text('$totalItemsCount', style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('NET À PAYER :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text(
                    '${document.totalAmount.toInt()} $currency',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.green800),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),

              // 🤝 PIED DE PAGE & SÉCURITÉ
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('------------------------------------------', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 4),
                    pw.Text('Merci pour votre confiance !', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 9)),
                    pw.SizedBox(height: 2),
                    pw.Text('Document certifié conforme par REM Mobile Core', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  /// 📤 ACTION 1 : Lance le partage natif (WhatsApp, Telegram, etc.) sous forme de fichier PDF
  Future<void> shareReceipt({
    required SalesDocument document,
    required List<Map<String, dynamic>> cartItems,
    required String currency,
  }) async {
    final pdfDoc = await generateReceiptPdf(document: document, cartItems: cartItems, currency: currency);
    final bytes = await pdfDoc.save();

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${document.number}.pdf');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: '🧾 Reçu de votre commande ${document.number} via REM Mobile.',
    );
  }

  /// 🖨️ ACTION 2 : Ouvre l'aperçu avant impression système ou envoie direct à l'imprimante
  Future<void> printReceipt({
    required SalesDocument document,
    required List<Map<String, dynamic>> cartItems,
    required String currency,
  }) async {
    final pdfDoc = await generateReceiptPdf(document: document, cartItems: cartItems, currency: currency);
    
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfDoc.save(),
      name: 'Ticket-${document.number}',
    );
  }
}