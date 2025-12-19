import '../../../services/database_service.dart';
import '../../../services/firebase_service.dart';
import '../models/order_header.dart';
import '../models/order_item.dart';

/// Service for managing orders with business logic
class OrderService {
  static final OrderService _instance = OrderService._internal();
  factory OrderService() => _instance;
  OrderService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final FirebaseService _firebaseService = FirebaseService();

  /// Event name options for dropdown
  static const List<String> eventNames = [
    'Ayyappa pooja',
    'Wedding',
    'Store',
    'Saastha pooja',
    'Vinayagar Chaturthi',
    'Navaratri',
    'Diwali',
    'Pongal',
    'Tamil New Year',
    'Engagement',
    'House warming',
    'Birthday',
    'Anniversary',
    'Other',
  ];

  /// Section options for order items
  static const List<String> sections = [
    'Outdoor decor',
    'Entrance decor',
    'Mandap',
    'Garlands',
    'Loose flowers',
    'Leaves & thoranam',
    'Others',
  ];

  /// Flower options master list
  static const List<String> flowers = [
    'Lilly',
    'Nandiyavittai',
    'Rose',
    'Jasmine',
    'Mullai',
    'Arali',
    'Marigold',
    'Mango leaf',
    'Coconut leaf',
    'Paneer rose',
    'Shenbaga',
    'Chrysanthemum',
    'Lotus',
    'Kanakambaram',
    'Crossandra',
    'Ixora',
    'Hibiscus',
    'Tuberose',
    'Valli',
    'Sampangi',
    'Nerium',
  ];

  /// Unit options for feet/quantity
  static const List<String> units = [
    'ft',
    'kg',
    'lb',
    'box',
    'nos',
    'bag',
    'bundle',
  ];

  /// Quantity unit options
  static const List<String> qtyUnits = [
    'string',
    'garland',
    'bag',
    'box',
    'leaf',
    'thoranam',
    'basket',
    'piece',
    'bunch',
  ];

  /// Item type options
  static const List<String> itemTypes = [
    'kunjam',
    'open malai',
    'gaja malai',
    'thoranam',
    'basket',
    'leaf string',
    'loose',
    'wedding garland',
    'backup',
    'decoration piece',
    'vadam',
    'round malai',
    'string',
    'pooja malai',
  ];

  /// Usage options
  static const List<String> usageOptions = [
    'Vinayagar',
    'Amman',
    'Ayyan padam',
    'Vilakku',
    'Door',
    'Ganesha',
    'Store',
    'Backup',
    'Decoration',
    'Puja',
    'Offering',
  ];

  /// Create a new order
  Future<OrderHeader> createOrder({
    required String customerName,
    String? eventName,
    String? deliveryDate,
    String? deliveryBatch,
    String? location,
    String? notes,
  }) async {
    print('🛒 ORDER_SERVICE: Creating order for customer: $customerName');

    final orderCode = _databaseService.generateOrderCode();
    final now = DateTime.now().millisecondsSinceEpoch;

    print('🛒 ORDER_SERVICE: Generated order code: $orderCode');

    final orderData = {
      'order_code': orderCode,
      'customer_name': customerName,
      'event_name': eventName,
      'delivery_date': deliveryDate,
      'delivery_batch': deliveryBatch,
      'location': location,
      'notes': notes,
      'status': 'pending',
      'created_at': now,
    };

    print('🛒 ORDER_SERVICE: Order data prepared: $orderData');
    print(
        '🛒 ORDER_SERVICE: Current user ID: ${_databaseService.getCurrentUserId()}');

    final id = await _databaseService.saveOrderHeader(orderData);

    print('🛒 ORDER_SERVICE: Order saved with ID: $id');

    return OrderHeader(
      id: id,
      userId: _databaseService.getCurrentUserId() ?? '',
      orderCode: orderCode,
      customerName: customerName,
      eventName: eventName,
      deliveryDate: deliveryDate,
      deliveryBatch: deliveryBatch,
      location: location,
      notes: notes,
      status: 'pending',
      createdAt: now,
    );
  }

  /// Get all orders for current user
  Future<List<OrderHeader>> getOrders() async {
    try {
      final orderMaps = await _databaseService.getOrderHeaders();
      return orderMaps.map((map) => OrderHeader.fromSQLite(map)).toList();
    } catch (e) {
      print('Error getting orders: $e');
      return [];
    }
  }

  /// Get order by ID
  Future<OrderHeader?> getOrderById(int id) async {
    try {
      final orderMap = await _databaseService.getOrderHeaderById(id);
      return orderMap != null ? OrderHeader.fromSQLite(orderMap) : null;
    } catch (e) {
      print('Error getting order by ID: $e');
      return null;
    }
  }

  /// Update order
  Future<void> updateOrder(int id, Map<String, dynamic> updates) async {
    await _databaseService.updateOrderHeader(id, updates);
  }

  /// Delete order
  Future<void> deleteOrder(int id) async {
    await _databaseService.deleteOrderHeader(id);
  }

  /// Add item to order
  Future<OrderItem> addOrderItem({
    required int orderId,
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
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final itemData = {
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
      'created_at': now,
    };

    final id = await _databaseService.saveOrderItem(itemData);

    return OrderItem(
      id: id,
      orderId: orderId,
      section: section,
      feetValue: feetValue,
      feetUnit: feetUnit,
      flower1: flower1,
      flower2: flower2,
      flower3: flower3,
      flower4: flower4,
      flower5: flower5,
      qty: qty,
      qtyUnit: qtyUnit,
      itemType: itemType,
      usageFor: usageFor,
      ratePerUnit: ratePerUnit,
      amount: amount,
      createdAt: now,
    );
  }

  /// Get items for an order
  Future<List<OrderItem>> getOrderItems(int orderId) async {
    try {
      final itemMaps = await _databaseService.getOrderItems(orderId);
      return itemMaps.map((map) => OrderItem.fromSQLite(map)).toList();
    } catch (e) {
      print('Error getting order items: $e');
      return [];
    }
  }

  /// Update order item
  Future<void> updateOrderItem(int id, Map<String, dynamic> updates) async {
    await _databaseService.updateOrderItem(id, updates);
  }

  /// Delete order item
  Future<void> deleteOrderItem(int id) async {
    await _databaseService.deleteOrderItem(id);
  }

  /// Calculate total amount for order
  Future<double> calculateOrderTotal(int orderId) async {
    final items = await getOrderItems(orderId);
    double total = 0.0;
    for (final item in items) {
      total += item.amount ?? 0.0;
    }
    return total;
  }

  /// Update order status
  Future<void> updateOrderStatus(int id, String status) async {
    await updateOrder(id, {'status': status});
  }

  /// Sync order to Firebase (for sharing between users)
  Future<bool> syncOrderToFirebase(int orderId) async {
    try {
      final order = await getOrderById(orderId);
      final items = await getOrderItems(orderId);

      if (order == null) return false;

      final orderData = {
        'header': order.toFirebase(),
        'items': items.map((item) => item.toFirebase()).toList(),
        'syncedAt': DateTime.now().toIso8601String(),
      };

      final success = await _firebaseService.saveOrder(
        order.orderCode,
        orderData,
      );

      return success;
    } catch (e) {
      print('Error syncing order to Firebase: $e');
      return false;
    }
  }

  /// Sync all orders to Firebase
  Future<Map<String, int>> syncAllOrdersToFirebase() async {
    int successful = 0;
    int failed = 0;

    try {
      final orders = await getOrders();

      for (final order in orders) {
        final success = await syncOrderToFirebase(order.id!);
        if (success) {
          successful++;
        } else {
          failed++;
        }
      }
    } catch (e) {
      print('Error during bulk sync: $e');
    }

    return {'successful': successful, 'failed': failed};
  }

  /// Load orders from Firebase
  Future<List<Map<String, dynamic>>> loadOrdersFromFirebase() async {
    try {
      return await _firebaseService.getUserOrders();
    } catch (e) {
      print('Error loading orders from Firebase: $e');
      return [];
    }
  }

  /// Get order summary for PDF
  Future<Map<String, dynamic>> getOrderSummary(int orderId) async {
    final order = await getOrderById(orderId);
    final items = await getOrderItems(orderId);

    if (order == null) {
      throw Exception('Order not found');
    }

    return {
      'order': order,
      'items': items,
      'total_items': items.length,
      'total_amount': await calculateOrderTotal(orderId),
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Share order with another user
  Future<bool> shareOrder(int orderId, String targetUserEmail) async {
    try {
      final order = await getOrderById(orderId);
      final items = await getOrderItems(orderId);

      if (order == null) return false;

      final orderData = {
        'header': order.toFirebase(),
        'items': items.map((item) => item.toFirebase()).toList(),
        'sharedAt': DateTime.now().toIso8601String(),
      };

      return await _firebaseService.shareOrder(
        order.orderCode,
        targetUserEmail,
        orderData,
      );
    } catch (e) {
      print('Error sharing order: $e');
      return false;
    }
  }

  /// Get shared orders from Firebase
  Future<List<Map<String, dynamic>>> getSharedOrders() async {
    try {
      return await _firebaseService.getSharedOrders();
    } catch (e) {
      print('Error getting shared orders: $e');
      return [];
    }
  }
}
