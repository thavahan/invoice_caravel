class Item {
  final String id;
  final String flowerTypeId;
  final double weightKg;
  final String form;
  final int quantity;
  final String notes;

  Item({
    this.id = '',
    required this.flowerTypeId,
    required this.weightKg,
    required this.form,
    required this.quantity,
    this.notes = '',
  });

  factory Item.fromMap(String id, Map<String, dynamic> map) {
    return Item(
      id: id,
      flowerTypeId: map['flower_type_id'] ?? '',
      weightKg: (map['weight_kg'] ?? 0.0).toDouble(),
      form: map['form'] ?? '',
      quantity: map['quantity'] ?? 0,
      notes: map['notes'] ?? '',
    );
  }

  /// Create Item from Shipment (for backward compatibility)
  factory Item.fromShipment(Map<String, dynamic> shipment) {
    return Item(
      id: shipment['id'] ?? '',
      flowerTypeId: shipment['awb'] ?? '',
      weightKg: (shipment['total_amount'] ?? 0.0).toDouble(),
      form: 'shipment',
      quantity: 1,
      notes: shipment['invoice_title'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'flower_type_id': flowerTypeId,
      'weight_kg': weightKg,
      'form': form,
      'quantity': quantity,
      'notes': notes,
    };
  }
}

/// FlowerType model for different types of flowers
class FlowerType {
  final String id;
  final String flowerName;
  final String description;

  FlowerType({
    required this.id,
    required this.flowerName,
    this.description = '',
  });

  factory FlowerType.fromMap(String id, Map<String, dynamic> map) {
    return FlowerType(
      id: id,
      flowerName: map['flower_name'] ?? '',
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'flower_name': flowerName,
      'description': description,
    };
  }

  @override
  String toString() => flowerName;
}
