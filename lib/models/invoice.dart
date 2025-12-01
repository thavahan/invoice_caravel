import 'package:invoice_generator/models/shipment.dart';
import 'package:invoice_generator/models/product.dart';

// Keeping Invoice for backward compatibility but using shipment data
class Invoice {
  final String invoiceNumber;
  final Shipment shipment;
  final DateTime date;
  final List<Item> items;
  final String signUrl;

  Invoice({
    required this.invoiceNumber,
    required this.shipment,
    required this.date,
    required this.items,
    required this.signUrl,
  });

  double get subtotal => shipment.totalAmount;

  double get tax => subtotal * 0.15;

  double get total => subtotal + tax;

  // For compatibility with existing PDF generation
  get customer => _LegacyCustomer(
      name: shipment.consignee, address: shipment.dischargeAirport);
}

// Temporary class for PDF compatibility
class _LegacyCustomer {
  final String name;
  final String address;
  _LegacyCustomer({required this.name, required this.address});
}
