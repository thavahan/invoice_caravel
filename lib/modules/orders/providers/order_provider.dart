import 'package:flutter/material.dart';
import 'dart:async';
import '../models/order_header.dart';
import '../models/order_item.dart';
import '../services/order_service.dart';

/// Provider for managing order state and operations
class OrderProvider with ChangeNotifier {
  final OrderService _orderService = OrderService();

  // State variables
  List<OrderHeader> _orders = [];
  List<OrderItem> _currentOrderItems = [];
  OrderHeader? _currentOrder;
  bool _isLoading = false;
  String? _error;

  // Performance optimization
  Timer? _debounceTimer;
  bool _isDisposed = false;

  // Getters
  List<OrderHeader> get orders => _orders;
  List<OrderItem> get currentOrderItems => _currentOrderItems;
  OrderHeader? get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load all orders for current user
  Future<void> loadOrders() async {
    _setLoading(true);
    _setError(null);

    try {
      _orders = await _orderService.getOrders();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load orders: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Create a new order
  Future<OrderHeader?> createOrder({
    required String customerName,
    String? eventName,
    String? deliveryDate,
    String? deliveryBatch,
    String? location,
    String? notes,
  }) async {
    print('🛒 ORDER_PROVIDER: Creating order for customer: $customerName');
    _setLoading(true);
    _setError(null);

    try {
      print('🛒 ORDER_PROVIDER: Calling OrderService.createOrder...');
      final order = await _orderService.createOrder(
        customerName: customerName,
        eventName: eventName,
        deliveryDate: deliveryDate,
        deliveryBatch: deliveryBatch,
        location: location,
        notes: notes,
      );

      print('🛒 ORDER_PROVIDER: Order created successfully: ${order.id}');
      _orders.insert(0, order);
      _currentOrder = order;
      _currentOrderItems = [];
      notifyListeners();
      return order;
    } catch (e) {
      print('🛒 ORDER_PROVIDER: Failed to create order: $e');
      _setError('Failed to create order: $e');
      return null;
    } finally {
      _setLoading(false);
      print('🛒 ORDER_PROVIDER: createOrder operation completed');
    }
  }

  /// Load order details by ID
  Future<void> loadOrderDetails(int orderId) async {
    _setLoading(true);
    _setError(null);

    try {
      final order = await _orderService.getOrderById(orderId);
      final items = await _orderService.getOrderItems(orderId);

      _currentOrder = order;
      _currentOrderItems = items;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load order details: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Update order
  Future<bool> updateOrder(int id, Map<String, dynamic> updates) async {
    _setLoading(true);
    _setError(null);

    try {
      await _orderService.updateOrder(id, updates);

      // Update local state
      final index = _orders.indexWhere((order) => order.id == id);
      if (index != -1) {
        final updatedOrder = _orders[index].copyWith(
          customerName: updates['customer_name'] ?? _orders[index].customerName,
          eventName: updates['event_name'] ?? _orders[index].eventName,
          deliveryDate: updates['delivery_date'] ?? _orders[index].deliveryDate,
          deliveryBatch:
              updates['delivery_batch'] ?? _orders[index].deliveryBatch,
          location: updates['location'] ?? _orders[index].location,
          notes: updates['notes'] ?? _orders[index].notes,
          status: updates['status'] ?? _orders[index].status,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        _orders[index] = updatedOrder;

        if (_currentOrder?.id == id) {
          _currentOrder = updatedOrder;
        }
      }

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update order: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete order
  Future<bool> deleteOrder(int id) async {
    _setLoading(true);
    _setError(null);

    try {
      await _orderService.deleteOrder(id);

      _orders.removeWhere((order) => order.id == id);
      if (_currentOrder?.id == id) {
        _currentOrder = null;
        _currentOrderItems = [];
      }

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete order: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Add item to current order
  Future<bool> addOrderItem({
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
    _setLoading(true);
    _setError(null);

    try {
      final item = await _orderService.addOrderItem(
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
      );

      _currentOrderItems.add(item);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to add order item: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Update order item
  Future<bool> updateOrderItem(int id, Map<String, dynamic> updates) async {
    _setLoading(true);
    _setError(null);

    try {
      await _orderService.updateOrderItem(id, updates);

      // Update local state
      final index = _currentOrderItems.indexWhere((item) => item.id == id);
      if (index != -1) {
        _currentOrderItems[index] = _currentOrderItems[index].copyWith(
          section: updates['section'],
          feetValue: updates['feet_value']?.toDouble(),
          feetUnit: updates['feet_unit'],
          flower1: updates['flower_1'],
          flower2: updates['flower_2'],
          flower3: updates['flower_3'],
          flower4: updates['flower_4'],
          flower5: updates['flower_5'],
          qty: updates['qty']?.toDouble(),
          qtyUnit: updates['qty_unit'],
          itemType: updates['item_type'],
          usageFor: updates['usage_for'],
          ratePerUnit: updates['rate_per_unit']?.toDouble(),
          amount: updates['amount']?.toDouble(),
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to update order item: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete order item
  Future<bool> deleteOrderItem(int id) async {
    _setLoading(true);
    _setError(null);

    try {
      await _orderService.deleteOrderItem(id);
      _currentOrderItems.removeWhere((item) => item.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete order item: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Calculate total for current order
  double get currentOrderTotal {
    return _currentOrderItems.fold(
        0.0, (total, item) => total + (item.amount ?? 0.0));
  }

  /// Get current order items count
  int get currentOrderItemsCount => _currentOrderItems.length;

  /// Update order status
  Future<bool> updateOrderStatus(int id, String status) async {
    return await updateOrder(id, {'status': status});
  }

  /// Sync order to Firebase
  Future<bool> syncOrderToFirebase(int orderId) async {
    _setLoading(true);
    _setError(null);

    try {
      final success = await _orderService.syncOrderToFirebase(orderId);
      if (!success) {
        _setError('Failed to sync order to cloud');
      }
      return success;
    } catch (e) {
      _setError('Failed to sync order: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Clear current order
  void clearCurrentOrder() {
    _currentOrder = null;
    _currentOrderItems = [];
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Helper methods
  void _setLoading(bool loading) {
    if (_isDisposed) return;
    _isLoading = loading;
    _debouncedNotify();
  }

  void _setError(String? error) {
    if (_isDisposed) return;
    _error = error;
    notifyListeners(); // Error messages should be immediate
  }

  void _debouncedNotify() {
    if (_isDisposed) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      if (!_isDisposed) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  /// Refresh orders
  Future<void> refreshOrders() async {
    await loadOrders();
  }

  /// Get order by ID from loaded orders
  OrderHeader? getOrderById(int id) {
    try {
      return _orders.firstWhere((order) => order.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Filter orders by status
  List<OrderHeader> getOrdersByStatus(String status) {
    return _orders.where((order) => order.status == status).toList();
  }

  /// Search orders by customer name or order code
  List<OrderHeader> searchOrders(String query) {
    final lowerQuery = query.toLowerCase();
    return _orders
        .where((order) =>
            order.customerName.toLowerCase().contains(lowerQuery) ||
            order.orderCode.toLowerCase().contains(lowerQuery) ||
            (order.eventName?.toLowerCase().contains(lowerQuery) ?? false))
        .toList();
  }

  // ========================================
  // FIREBASE SYNC AND SHARING METHODS
  // ========================================

  /// Sync a specific order to Firebase
  Future<bool> syncSingleOrderToFirebase(int orderId) async {
    _setLoading(true);
    try {
      final success = await _orderService.syncOrderToFirebase(orderId);
      if (success) {
        // Refresh orders to get updated sync status
        await refreshOrders();
      }
      return success;
    } catch (e) {
      _setError('Failed to sync order: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sync all orders to Firebase
  Future<Map<String, int>> syncAllOrdersToFirebase() async {
    _setLoading(true);
    try {
      final result = await _orderService.syncAllOrdersToFirebase();
      if ((result['successful'] ?? 0) > 0) {
        // Refresh orders to get updated sync status
        await refreshOrders();
      }
      return result;
    } catch (e) {
      _setError('Failed to sync orders: $e');
      return {'successful': 0, 'failed': 0};
    } finally {
      _setLoading(false);
    }
  }

  /// Load orders from Firebase
  Future<List<Map<String, dynamic>>> loadOrdersFromFirebase() async {
    _setLoading(true);
    try {
      return await _orderService.loadOrdersFromFirebase();
    } catch (e) {
      _setError('Failed to load orders from Firebase: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// Share order with another user
  Future<bool> shareOrder(int orderId, String targetUserEmail) async {
    _setLoading(true);
    try {
      return await _orderService.shareOrder(orderId, targetUserEmail);
    } catch (e) {
      _setError('Failed to share order: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get shared orders from Firebase
  Future<List<Map<String, dynamic>>> getSharedOrders() async {
    _setLoading(true);
    try {
      return await _orderService.getSharedOrders();
    } catch (e) {
      _setError('Failed to get shared orders: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }
}
