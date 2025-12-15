import 'package:cloud_firestore/cloud_firestore.dart';

/// Box model for SQLite database

/// Box model for SQLite database
class ShipmentBox {
  final String id;
  final String shipmentId;
  final String boxNumber;
  final double length;
  final double width;
  final double height;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<ShipmentProduct> products;

  ShipmentBox({
    required this.id,
    required this.shipmentId,
    required this.boxNumber,
    this.length = 0.0,
    this.width = 0.0,
    this.height = 0.0,
    DateTime? createdAt,
    this.updatedAt,
    List<ShipmentProduct>? products,
  })  : createdAt = createdAt ?? DateTime.now(),
        products = products ?? [];

  /// Create Box from SQLite database row
  factory ShipmentBox.fromSQLite(Map<String, dynamic> map) {
    return ShipmentBox(
      id: map['id'] ?? '',
      shipmentId: map['shipment_invoice_number'] ?? '',
      boxNumber: map['box_number'] ?? '',
      length: (map['length'] ?? 0.0).toDouble(),
      width: (map['width'] ?? 0.0).toDouble(),
      height: (map['height'] ?? 0.0).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'])
          : null,
    );
  }

  /// Create Box from Firebase map
  factory ShipmentBox.fromMap(String id, Map<String, dynamic> map) {
    return ShipmentBox(
      id: id,
      shipmentId: map['shipmentId'] ?? '',
      boxNumber: map['boxNumber'] ?? map['box_number'] ?? '',
      length: (map['length'] ?? 0.0).toDouble(),
      width: (map['width'] ?? 0.0).toDouble(),
      height: (map['height'] ?? 0.0).toDouble(),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert to SQLite-compatible map
  Map<String, dynamic> toSQLite() {
    return {
      'id': id,
      'shipment_invoice_number': shipmentId,
      'box_number': boxNumber,
      'length': length,
      'width': width,
      'height': height,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
    };
  }

  /// Legacy method for UI compatibility
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'boxNumber': boxNumber,
      'length': length,
      'width': width,
      'height': height,
      'products': products.map((product) => product.toMap()).toList(),
    };
  }

  // Calculated properties
  double get totalWeight =>
      products.fold(0.0, (sum, product) => sum + product.totalWeight);
  double get totalValue =>
      products.fold(0.0, (sum, product) => sum + product.totalValue);
  double get volume => length * width * height;
  int get productCount => products.length;

  /// Create a copy with updated fields
  ShipmentBox copyWith({
    String? id,
    String? shipmentId,
    String? boxNumber,
    double? length,
    double? width,
    double? height,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ShipmentProduct>? products,
  }) {
    return ShipmentBox(
      id: id ?? this.id,
      shipmentId: shipmentId ?? this.shipmentId,
      boxNumber: boxNumber ?? this.boxNumber,
      length: length ?? this.length,
      width: width ?? this.width,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      products: products ?? this.products,
    );
  }

  @override
  String toString() => '$boxNumber (${products.length} products)';
}

/// Product model for SQLite database
class ShipmentProduct {
  final String id;
  final String boxId;
  final String type;
  final String description;
  final double weight;
  final double rate;
  final String
      flowerType; // TIED GARLANS, LOOSE FLOWERS, TIED GARLANS AND LOOSE FLOWERS
  final bool hasStems; // true for Yes, false for No
  final int
      approxQuantity; // auto calculated: weight * approxQuantity from product type
  final DateTime createdAt;
  final DateTime? updatedAt;

  ShipmentProduct({
    required this.id,
    required this.boxId,
    required this.type,
    required this.description,
    required this.weight,
    this.rate = 0.0, // Made optional with default value
    this.flowerType = 'LOOSE FLOWERS', // default value
    this.hasStems = false, // default to No
    this.approxQuantity = 0,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create Product from SQLite database row
  factory ShipmentProduct.fromSQLite(Map<String, dynamic> map) {
    return ShipmentProduct(
      id: map['id'] ?? '',
      boxId: map['box_id'] ?? '',
      type: map['type'] ?? '',
      description: map['description'] ?? '',
      weight: (map['weight'] ?? 0.0).toDouble(),
      rate: (map['rate'] ?? 0.0).toDouble(),
      flowerType: map['flower_type'] ?? 'LOOSE FLOWERS',
      hasStems: (map['has_stems'] ?? 0) == 1,
      approxQuantity: (map['approx_quantity'] ?? 0).toInt(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'])
          : null,
    );
  }

  /// Create Product from Firebase map
  factory ShipmentProduct.fromMap(String id, Map<String, dynamic> map) {
    return ShipmentProduct(
      id: id,
      boxId: map['boxId'] ?? '',
      type: map['type'] ?? '',
      description: map['description'] ?? '',
      weight: (map['weight'] ?? 0.0).toDouble(),
      rate: (map['rate'] ?? 0.0).toDouble(),
      flowerType: map['flowerType'] ?? 'LOOSE FLOWERS',
      hasStems: map['hasStems'] ?? false,
      approxQuantity: (map['approxQuantity'] ?? 0).toInt(),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert to SQLite-compatible map
  Map<String, dynamic> toSQLite() {
    return {
      'id': id,
      'box_id': boxId,
      'type': type,
      'description': description,
      'weight': weight,
      'rate': rate,
      'flower_type': flowerType,
      'has_stems': hasStems ? 1 : 0,
      'approx_quantity': approxQuantity,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
    };
  }

  /// Convert to Firebase-compatible map
  Map<String, dynamic> toFirebase() {
    return {
      'id': id,
      'boxId': boxId,
      'type': type,
      'description': description,
      'weight': weight,
      'rate': rate,
      'flowerType': flowerType,
      'hasStems': hasStems,
      'approxQuantity': approxQuantity,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Legacy method for UI compatibility
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'description': description,
      'weight': weight,
      'rate': rate,
      'flowerType': flowerType,
      'hasStems': hasStems,
      'approxQuantity': approxQuantity,
    };
  }

  // Calculated properties
  double get totalWeight => weight;
  double get totalValue => rate;

  /// Create a copy with updated fields
  ShipmentProduct copyWith({
    String? id,
    String? boxId,
    String? type,
    String? description,
    double? weight,
    double? rate,
    String? flowerType,
    bool? hasStems,
    int? approxQuantity,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShipmentProduct(
      id: id ?? this.id,
      boxId: boxId ?? this.boxId,
      type: type ?? this.type,
      description: description ?? this.description,
      weight: weight ?? this.weight,
      rate: rate ?? this.rate,
      flowerType: flowerType ?? this.flowerType,
      hasStems: hasStems ?? this.hasStems,
      approxQuantity: approxQuantity ?? this.approxQuantity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      '$type - ${weight}kg ($flowerType${hasStems ? ', WITH STEMS' : ', NO STEMS'}, APPROX $approxQuantity NOS)';
}
