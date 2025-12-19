class OrderHeader {
  final int? id;
  final String userId;
  final String orderCode;
  final String customerName;
  final String? eventName;
  final String? deliveryDate;
  final String? deliveryBatch;
  final String? location;
  final String? notes;
  final String status;
  final int createdAt;
  final int? updatedAt;

  OrderHeader({
    this.id,
    required this.userId,
    required this.orderCode,
    required this.customerName,
    this.eventName,
    this.deliveryDate,
    this.deliveryBatch,
    this.location,
    this.notes,
    this.status = 'pending',
    required this.createdAt,
    this.updatedAt,
  });

  /// Create OrderHeader from SQLite database row
  factory OrderHeader.fromSQLite(Map<String, dynamic> map) {
    return OrderHeader(
      id: map['id'],
      userId: map['user_id'] ?? '',
      orderCode: map['order_code'] ?? '',
      customerName: map['customer_name'] ?? '',
      eventName: map['event_name'],
      deliveryDate: map['delivery_date'],
      deliveryBatch: map['delivery_batch'],
      location: map['location'],
      notes: map['notes'],
      status: map['status'] ?? 'pending',
      createdAt: map['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
      updatedAt: map['updated_at'],
    );
  }

  /// Create OrderHeader from Firebase data
  factory OrderHeader.fromFirebase(Map<String, dynamic> map) {
    return OrderHeader(
      id: map['id'],
      userId: map['userId'] ?? map['user_id'] ?? '',
      orderCode: map['orderCode'] ?? map['order_code'] ?? '',
      customerName: map['customerName'] ?? map['customer_name'] ?? '',
      eventName: map['eventName'] ?? map['event_name'],
      deliveryDate: map['deliveryDate'] ?? map['delivery_date'],
      deliveryBatch: map['deliveryBatch'] ?? map['delivery_batch'],
      location: map['location'],
      notes: map['notes'],
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] ??
          map['created_at'] ??
          DateTime.now().millisecondsSinceEpoch,
      updatedAt: map['updatedAt'] ?? map['updated_at'],
    );
  }

  /// Convert to SQLite-compatible map
  Map<String, dynamic> toSQLite() {
    final map = <String, dynamic>{
      'user_id': userId,
      'order_code': orderCode,
      'customer_name': customerName,
      'event_name': eventName,
      'delivery_date': deliveryDate,
      'delivery_batch': deliveryBatch,
      'location': location,
      'notes': notes,
      'status': status,
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
      'userId': userId,
      'orderCode': orderCode,
      'customerName': customerName,
      'eventName': eventName,
      'deliveryDate': deliveryDate,
      'deliveryBatch': deliveryBatch,
      'location': location,
      'notes': notes,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Create a copy with updated fields
  OrderHeader copyWith({
    int? id,
    String? userId,
    String? orderCode,
    String? customerName,
    String? eventName,
    String? deliveryDate,
    String? deliveryBatch,
    String? location,
    String? notes,
    String? status,
    int? createdAt,
    int? updatedAt,
  }) {
    return OrderHeader(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      orderCode: orderCode ?? this.orderCode,
      customerName: customerName ?? this.customerName,
      eventName: eventName ?? this.eventName,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      deliveryBatch: deliveryBatch ?? this.deliveryBatch,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  @override
  String toString() {
    return 'OrderHeader{id: $id, orderCode: $orderCode, customerName: $customerName, eventName: $eventName, deliveryDate: $deliveryDate, status: $status}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrderHeader &&
        other.id == id &&
        other.orderCode == orderCode;
  }

  @override
  int get hashCode => id.hashCode ^ orderCode.hashCode;
}
