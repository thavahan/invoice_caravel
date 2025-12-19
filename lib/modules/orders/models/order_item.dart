class OrderItem {
  final int? id;
  final int orderId;
  final String? section;
  final double? feetValue;
  final String? feetUnit;
  final String? flower1;
  final String? flower2;
  final String? flower3;
  final String? flower4;
  final String? flower5;
  final double? qty;
  final String? qtyUnit;
  final String? itemType;
  final String? usageFor;
  final double? ratePerUnit;
  final double? amount;
  final int createdAt;
  final int? updatedAt;

  OrderItem({
    this.id,
    required this.orderId,
    this.section,
    this.feetValue,
    this.feetUnit,
    this.flower1,
    this.flower2,
    this.flower3,
    this.flower4,
    this.flower5,
    this.qty,
    this.qtyUnit,
    this.itemType,
    this.usageFor,
    this.ratePerUnit,
    this.amount,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create OrderItem from SQLite database row
  factory OrderItem.fromSQLite(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'],
      orderId: map['order_id'] ?? 0,
      section: map['section'],
      feetValue: map['feet_value']?.toDouble(),
      feetUnit: map['feet_unit'],
      flower1: map['flower_1'],
      flower2: map['flower_2'],
      flower3: map['flower_3'],
      flower4: map['flower_4'],
      flower5: map['flower_5'],
      qty: map['qty']?.toDouble(),
      qtyUnit: map['qty_unit'],
      itemType: map['item_type'],
      usageFor: map['usage_for'],
      ratePerUnit: map['rate_per_unit']?.toDouble(),
      amount: map['amount']?.toDouble(),
      createdAt: map['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: map['updated_at'],
    );
  }

  /// Create OrderItem from Firebase data
  factory OrderItem.fromFirebase(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'],
      orderId: map['orderId'] ?? map['order_id'] ?? 0,
      section: map['section'],
      feetValue: (map['feetValue'] ?? map['feet_value'])?.toDouble(),
      feetUnit: map['feetUnit'] ?? map['feet_unit'],
      flower1: map['flower1'] ?? map['flower_1'],
      flower2: map['flower2'] ?? map['flower_2'],
      flower3: map['flower3'] ?? map['flower_3'],
      flower4: map['flower4'] ?? map['flower_4'],
      flower5: map['flower5'] ?? map['flower_5'],
      qty: map['qty']?.toDouble(),
      qtyUnit: map['qtyUnit'] ?? map['qty_unit'],
      itemType: map['itemType'] ?? map['item_type'],
      usageFor: map['usageFor'] ?? map['usage_for'],
      ratePerUnit: (map['ratePerUnit'] ?? map['rate_per_unit'])?.toDouble(),
      amount: map['amount']?.toDouble(),
      createdAt: map['createdAt'] ??
          map['created_at'] ??
          DateTime.now().millisecondsSinceEpoch,
      updatedAt: map['updatedAt'] ?? map['updated_at'],
    );
  }

  /// Convert to SQLite-compatible map
  Map<String, dynamic> toSQLite() {
    final map = <String, dynamic>{
      'order_id': orderId,
      'section': section,
      'feet_value': feetValue,
      'feet_unit': feetUnit,
      'flower_1': flower1,
      'flower_2': flower2,
      'flower_3': flower3,
      'flower_4': flower4,
      'flower_5': flower5,
      'qty': qty,
      'qty_unit': qtyUnit,
      'item_type': itemType,
      'usage_for': usageFor,
      'rate_per_unit': ratePerUnit,
      'amount': amount,
      'created_at': createdAt,
      'updated_at': updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    };

    if (id != null) {
      map['id'] = id;
    }

    return map;
  }

  /// Convert to Firebase format
  Map<String, dynamic> toFirebase() {
    return {
      'id': id,
      'orderId': orderId,
      'section': section,
      'feetValue': feetValue,
      'feetUnit': feetUnit,
      'flower1': flower1,
      'flower2': flower2,
      'flower3': flower3,
      'flower4': flower4,
      'flower5': flower5,
      'qty': qty,
      'qtyUnit': qtyUnit,
      'itemType': itemType,
      'usageFor': usageFor,
      'ratePerUnit': ratePerUnit,
      'amount': amount,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Get a compact display summary for the item
  String get displaySummary {
    final parts = <String>[];

    // Add section if available
    if (section != null && section!.isNotEmpty) {
      parts.add(section!);
    }

    // Add feet/size if available
    if (feetValue != null && feetValue! > 0) {
      final unit = feetUnit ?? 'ft';
      parts.add(
          '${feetValue!.toStringAsFixed(feetValue! % 1 == 0 ? 0 : 1)} $unit');
    }

    // Add flowers with + separator
    final flowers = [flower1, flower2, flower3, flower4, flower5];
    final flowerNames =
        flowers.where((f) => f != null && f.isNotEmpty).toList();
    if (flowerNames.isNotEmpty) {
      parts.add(flowerNames.join(' + '));
    }

    // Add quantity at the end
    if (qty != null && qty! > 0) {
      final unit = qtyUnit ?? '';
      final qtyStr = qty!.toStringAsFixed(qty! % 1 == 0 ? 0 : 1);
      parts.add('Qty $qtyStr${unit.isNotEmpty ? ' $unit' : ''}');
    }

    return parts.isEmpty ? 'Order item' : parts.join(' – ');
  }

  /// Get total flowers count (non-empty flower fields)
  int get flowersCount {
    final flowers = [flower1, flower2, flower3, flower4, flower5];
    return flowers.where((f) => f != null && f.isNotEmpty).length;
  }

  /// Create a copy with updated fields
  OrderItem copyWith({
    int? id,
    int? orderId,
    String? section,
    double? feetValue,
    String? feetUnit,
    String? flower1,
    String? flower2,
    String? flower3,
    String? flower4,
    String? flower5,
    double? qty,
    String? qtyUnit,
    String? itemType,
    String? usageFor,
    double? ratePerUnit,
    double? amount,
    int? createdAt,
    int? updatedAt,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      section: section ?? this.section,
      feetValue: feetValue ?? this.feetValue,
      feetUnit: feetUnit ?? this.feetUnit,
      flower1: flower1 ?? this.flower1,
      flower2: flower2 ?? this.flower2,
      flower3: flower3 ?? this.flower3,
      flower4: flower4 ?? this.flower4,
      flower5: flower5 ?? this.flower5,
      qty: qty ?? this.qty,
      qtyUnit: qtyUnit ?? this.qtyUnit,
      itemType: itemType ?? this.itemType,
      usageFor: usageFor ?? this.usageFor,
      ratePerUnit: ratePerUnit ?? this.ratePerUnit,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  String toString() {
    return 'OrderItem{id: $id, orderId: $orderId, section: $section, flowers: [$flower1, $flower2, $flower3], qty: $qty}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrderItem && other.id == id && other.orderId == orderId;
  }

  @override
  int get hashCode => id.hashCode ^ orderId.hashCode;
}
