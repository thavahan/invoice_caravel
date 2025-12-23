import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../models/order_header.dart';
import 'order_form_screen.dart';

/// Screen for displaying list of orders
class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({Key? key}) : super(key: key);

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false).loadOrders();
    });
  }

  @override
  void dispose() {
    // Dispose controller safely after current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchController.dispose();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Orders'),
      //   actions: [
      //     IconButton(
      //       icon: const Icon(Icons.refresh),
      //       onPressed: () {
      //         Provider.of<OrderProvider>(context, listen: false)
      //             .refreshOrders();
      //       },
      //     ),
      //   ],
      // ),
      body: _buildOrdersList(),
      // Column(
      //   children: [
      //     _buildSearchAndFilter(),
      //     Expanded(
      //       child: _buildOrdersList(),
      //     ),
      //   ],
      // ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const OrderFormScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'New Order',
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by customer name, order code, or event...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Status: '),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedStatus,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(
                        value: 'confirmed', child: Text('Confirmed')),
                    DropdownMenuItem(
                        value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(
                        value: 'cancelled', child: Text('Cancelled')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value ?? 'all';
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList() {
    return RepaintBoundary(
      child: Consumer<OrderProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${provider.error}',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      provider.clearError();
                      provider.refreshOrders();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final filteredOrders = _getFilteredOrders(provider.orders);

          if (filteredOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 64,
                    color: Theme.of(context).disabledColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty || _selectedStatus != 'all'
                        ? 'No orders match your criteria'
                        : 'No orders yet',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).disabledColor,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _searchQuery.isNotEmpty || _selectedStatus != 'all'
                        ? 'Try adjusting your search or filter'
                        : 'Tap + to create your first order',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).disabledColor,
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: filteredOrders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final order = filteredOrders[index];
              return RepaintBoundary(
                child: _buildOrderCard(order, provider),
              );
            },
            // Performance optimizations
            cacheExtent: 200.0,
            addRepaintBoundaries: true,
            addSemanticIndexes: true,
          );
        },
      ),
    );
  }

  List<OrderHeader> _getFilteredOrders(List<OrderHeader> orders) {
    var filtered = orders;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = orders
          .where((order) =>
              order.customerName.toLowerCase().contains(_searchQuery) ||
              order.orderCode.toLowerCase().contains(_searchQuery) ||
              (order.eventName?.toLowerCase().contains(_searchQuery) ?? false))
          .toList();
    }

    // Filter by status
    if (_selectedStatus != 'all') {
      filtered =
          filtered.where((order) => order.status == _selectedStatus).toList();
    }

    return filtered;
  }

  Widget _buildOrderCard(OrderHeader order, OrderProvider provider) {
    final DateTime createdDate =
        DateTime.fromMillisecondsSinceEpoch(order.createdAt);
    DateTime? deliveryDate;

    if (order.deliveryDate != null && order.deliveryDate!.isNotEmpty) {
      try {
        deliveryDate = DateTime.parse(order.deliveryDate!);
      } catch (e) {
        // Invalid date format
      }
    }

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderFormScreen(orderId: order.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.orderCode,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  _buildStatusChip(order.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.customerName,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
              if (order.eventName != null && order.eventName!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.event,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      order.eventName!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          'Created: ${_formatDate(createdDate)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (deliveryDate != null) ...[
                    Row(
                      children: [
                        Icon(Icons.local_shipping,
                            size: 16,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          'Delivery: ${_formatDate(deliveryDate)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              if (order.location != null && order.location!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      order.location!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tap to view details',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).primaryColor,
                        ),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('Edit'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'share',
                        child: ListTile(
                          leading: Icon(Icons.share),
                          title: Text('Share PDF'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'sync',
                        child: ListTile(
                          leading: Icon(Icons.cloud_upload),
                          title: Text('Sync to Cloud'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete,
                              color: Theme.of(context).colorScheme.error),
                          title: const Text('Delete'),
                        ),
                      ),
                    ],
                    onSelected: (value) =>
                        _handleOrderAction(value, order, provider),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
        color = Theme.of(context).brightness == Brightness.dark
            ? Colors.orange.shade300
            : Colors.orange;
        break;
      case 'confirmed':
        color = Theme.of(context).colorScheme.primary;
        break;
      case 'completed':
        color = Theme.of(context).brightness == Brightness.dark
            ? Colors.green.shade300
            : Colors.green;
        break;
      case 'cancelled':
        color = Theme.of(context).colorScheme.error;
        break;
      default:
        color = Theme.of(context).colorScheme.onSurfaceVariant;
    }

    return Chip(
      label: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _handleOrderAction(
      String action, OrderHeader order, OrderProvider provider) {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderFormScreen(orderId: order.id),
          ),
        );
        break;
      case 'share':
        _shareOrderPDF(order);
        break;
      case 'sync':
        _syncOrderToCloud(order, provider);
        break;
      case 'delete':
        _deleteOrder(order, provider);
        break;
    }
  }

  void _shareOrderPDF(OrderHeader order) {
    // TODO: Implement PDF generation and sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF sharing will be implemented soon'),
      ),
    );
  }

  void _syncOrderToCloud(OrderHeader order, OrderProvider provider) {
    if (order.id == null) return;

    provider.syncOrderToFirebase(order.id!).then((success) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Order synced to cloud successfully'),
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.green.shade600
                : Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sync order: ${provider.error}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    });
  }

  void _deleteOrder(OrderHeader order, OrderProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: Text(
          'Are you sure you want to delete order ${order.orderCode}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (order.id != null) {
                provider.deleteOrder(order.id!).then((success) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Order deleted successfully'),
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors.green.shade600
                                : Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Failed to delete order: ${provider.error}'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                });
              }
            },
            child: Text('Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}
