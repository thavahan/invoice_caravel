import 'package:invoice_generator/models/product.dart';

class InvoiceItem {
  final Item item;
  final int quantity;
  final int bonus;

  InvoiceItem({
    required this.item,
    required this.quantity,
    this.bonus = 0,
  });

  // For backward compatibility, calculate price from weight and quantity
  double get totalPrice =>
      item.weightKg * quantity * 10.0; // Example price calculation

  // For compatibility with existing code that expects product
  get product => _LegacyProduct(
        name: item.form,
        unitPrice: item.weightKg * 10.0,
      );
}

// Temporary class for backward compatibility
class _LegacyProduct {
  final String name;
  final double unitPrice;
  _LegacyProduct({required this.name, required this.unitPrice});
}
