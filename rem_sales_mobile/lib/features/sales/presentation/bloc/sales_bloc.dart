import 'dart:developer' as developer;
import '../../data/models/sales_document_model.dart';
import '../../data/repositories/sales_repository.dart'; // Import du dépôt réseau

abstract class SalesState {}
class SalesInitial extends SalesState {}
class SalesLoading extends SalesState {}
class SalesSuccess extends SalesState {
  final List<SalesDocument> documents;
  SalesSuccess(this.documents);
}
class SalesError extends SalesState {
  final String message;
  SalesError(this.message);
}

class SalesBloc {
  final SalesRepository repository = SalesRepository(); // Injection du gestionnaire réseau
  SalesState _state = SalesInitial();
  SalesState get state => _state;
  final List<SalesDocument> _realPipeline = [];

  Future<void> createDocument(String clientId, String type, double amount) async {
    _state = SalesLoading();
    developer.log('[BLOC NETWORK] Envoi de la demande au serveur...', name: 'REM.Sales');

    try {
      // On effectue le vrai appel HTTP asynchrone
      final newDoc = await repository.sendDocumentToBackend(
        clientId: clientId,
        type: type,
        amount: amount,
      );

      _realPipeline.add(newDoc);
      _state = SalesSuccess(List.from(_realPipeline));
      developer.log('[BLOC SUCCESS] Réponse reçue de l\'API. Numéro généré: ${newDoc.number}', name: 'REM.Sales');
    } catch (e) {
      _state = SalesError(e.toString());
      developer.log('[BLOC ERROR] La requête réseau a échoué: $e', name: 'REM.Sales');
    }
  }
}