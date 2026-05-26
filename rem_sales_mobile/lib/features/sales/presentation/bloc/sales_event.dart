import 'package:equatable/equatable.dart';
import 'package:rem_sales_mobile/features/sales/data/models/sales_document_model.dart';

abstract class SalesEvent extends Equatable {
  const SalesEvent();

  @override
  List<Object?> get props => [];
}

class SaveDocumentEvent extends SalesEvent {
  final SalesDocument document;
  final List<Map<String, dynamic>> cartItems;

  const SaveDocumentEvent(this.document, this.cartItems);

  @override
  List<Object?> get props => [document, cartItems];
}

/// 📦 JALON INVENTORY : Événement pour charger le catalogue d'articles Multi-Tenant depuis Isar DB
class LoadProductsEvent extends SalesEvent {
  final String companyId;

  const LoadProductsEvent(this.companyId);

  @override
  List<Object?> get props => [companyId];
}