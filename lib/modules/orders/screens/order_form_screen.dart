import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../services/order_service.dart';
import '../widgets/order_item_dialog.dart';

/// Screen for creating and editing orders
class OrderFormScreen extends StatefulWidget {
  final int? orderId; // For editing existing order

  const OrderFormScreen({Key? key, this.orderId}) : super(key: key);

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _customerNameController = TextEditingController();
  final _deliveryBatchController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedEventName;
  DateTime? _selectedDeliveryDate;

  bool _isEditMode = false;
  bool _isLoading = false;
  bool _hasTriedSaving = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.orderId != null;
    if (_isEditMode) {
      // Defer data loading until after the build is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadOrderData();
      });
    }
  }

  @override
  void dispose() {
    // Dispose controllers safely after current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _customerNameController.dispose();
      _deliveryBatchController.dispose();
      _locationController.dispose();
      _notesController.dispose();
    });
    super.dispose();
  }

  Future<void> _loadOrderData() async {
    if (widget.orderId == null) return;

    setState(() => _isLoading = true);

    final provider = Provider.of<OrderProvider>(context, listen: false);
    await provider.loadOrderDetails(widget.orderId!);

    final order = provider.currentOrder;
    if (order != null) {
      _customerNameController.text = order.customerName;
      _deliveryBatchController.text = order.deliveryBatch ?? '';
      _locationController.text = order.location ?? '';
      _notesController.text = order.notes ?? '';
      _selectedEventName = order.eventName;

      if (order.deliveryDate != null) {
        try {
          _selectedDeliveryDate = DateTime.parse(order.deliveryDate!);
        } catch (e) {
          print('Error parsing delivery date: $e');
        }
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
        child: Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Order' : 'New Order'),
        actions: [
          if (_isEditMode)
            Consumer<OrderProvider>(
              builder: (context, provider, child) {
                final itemCount = provider.currentOrderItemsCount;
                return Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Center(
                    child: Text(
                      '$itemCount items',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(),
      floatingActionButton: _isEditMode
          ? FloatingActionButton.extended(
              onPressed: _addOrderItem,
              icon: const Icon(Icons.add),
              label: const Text('Add Item'),
              tooltip: 'Add Item',
            )
          : null,
    ));
  }

  Widget _buildForm() {
    return Consumer<OrderProvider>(
      builder: (context, provider, child) {
        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Header section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Details',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      _buildCustomerNameField(),
                      const SizedBox(height: 16),
                      _buildEventNameDropdown(),
                      const SizedBox(height: 16),
                      _buildDeliveryDatePicker(),
                      const SizedBox(height: 16),
                      _buildDeliveryBatchField(),
                      const SizedBox(height: 16),
                      _buildLocationField(),
                      const SizedBox(height: 16),
                      _buildNotesField(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Items section (only show in edit mode)
              if (_isEditMode) ...[
                _buildItemsSection(),
                const SizedBox(height: 80), // Space for FAB
              ],

              // Save button (only show in create mode)
              if (!_isEditMode) ...[
                const SizedBox(height: 24),
                _buildSaveButton(provider),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomerNameField() {
    return TextFormField(
      controller: _customerNameController,
      decoration: const InputDecoration(
        labelText: 'Customer Name *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.person),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Customer name is required';
        }
        return null;
      },
    );
  }

  Widget _buildEventNameDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedEventName,
      decoration: const InputDecoration(
        labelText: 'Event Name',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.event),
      ),
      items: OrderService.eventNames.map((event) {
        return DropdownMenuItem(
          value: event,
          child: Text(event),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedEventName = value;
        });
      },
    );
  }

  Widget _buildDeliveryDatePicker() {
    return InkWell(
      onTap: _selectDeliveryDate,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Delivery Date *',
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.calendar_today),
          errorText: _selectedDeliveryDate == null && _hasTriedSaving
              ? 'Delivery date is required'
              : null,
        ),
        child: Text(
          _selectedDeliveryDate != null
              ? '${_selectedDeliveryDate!.day}/${_selectedDeliveryDate!.month}/${_selectedDeliveryDate!.year}'
              : 'Select delivery date',
          style: TextStyle(
            color: _selectedDeliveryDate != null
                ? Theme.of(context).textTheme.bodyLarge?.color
                : Theme.of(context).hintColor,
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryBatchField() {
    return TextFormField(
      controller: _deliveryBatchController,
      decoration: const InputDecoration(
        labelText: 'Delivery Batch',
        hintText: 'e.g., "Nov 13th delivery", "11/18 week"',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.local_shipping),
        helperText: 'Specify delivery batch or timing',
      ),
    );
  }

  Widget _buildLocationField() {
    return TextFormField(
      controller: _locationController,
      decoration: const InputDecoration(
        labelText: 'Location',
        hintText: 'Delivery location (City, Store, Address)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.location_on),
        helperText: 'Where should the order be delivered?',
      ),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      decoration: const InputDecoration(
        labelText: 'Notes',
        hintText: 'Additional notes or requirements',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.notes),
      ),
      maxLines: 3,
    );
  }

  Widget _buildItemsSection() {
    return Consumer<OrderProvider>(
      builder: (context, provider, child) {
        final items = provider.currentOrderItems;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Order Items',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Row(
                      children: [
                        if (_isEditMode && items.isNotEmpty)
                          IconButton(
                            onPressed: _addOrderItem,
                            icon: const Icon(Icons.add),
                            tooltip: 'Add Item',
                          ),
                        Text(
                          'Total: \$${provider.currentOrderTotal.toStringAsFixed(2)}',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (items.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Theme.of(context).disabledColor,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No items added yet',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context).disabledColor,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        if (_isEditMode)
                          ElevatedButton.icon(
                            onPressed: _addOrderItem,
                            icon: const Icon(Icons.add),
                            label: const Text('Add First Item'),
                          ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildOrderItemTile(item);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderItemTile(dynamic item) {
    return ListTile(
      title: Text(item.displaySummary),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.itemType != null && item.itemType!.isNotEmpty)
            Text('Type: ${item.itemType}'),
          if (item.usageFor != null && item.usageFor!.isNotEmpty)
            Text('For: ${item.usageFor}'),
          if (item.amount != null && item.amount! > 0)
            Text('Amount: \$${item.amount!.toStringAsFixed(2)}'),
        ],
      ),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: Icon(Icons.edit),
              title: Text('Edit'),
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
        onSelected: (value) {
          if (value == 'edit') {
            _editOrderItem(item);
          } else if (value == 'delete') {
            _deleteOrderItem(item);
          }
        },
      ),
    );
  }

  Widget _buildSaveButton(OrderProvider provider) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: provider.isLoading ? null : _saveOrder,
        child: provider.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Create Order'),
      ),
    );
  }

  Future<void> _selectDeliveryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDeliveryDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _selectedDeliveryDate = date;
      });
    }
  }

  Future<void> _saveOrder() async {
    setState(() => _hasTriedSaving = true);

    // Validate form fields and required data
    bool isValid = _formKey.currentState!.validate();

    // Check delivery date requirement
    if (_selectedDeliveryDate == null) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a delivery date'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      isValid = false;
    }

    if (!isValid) {
      return;
    }

    final provider = Provider.of<OrderProvider>(context, listen: false);

    final order = await provider.createOrder(
      customerName: _customerNameController.text.trim(),
      eventName: _selectedEventName,
      deliveryDate: _selectedDeliveryDate?.toIso8601String().split('T')[0],
      deliveryBatch: _deliveryBatchController.text.trim().isNotEmpty
          ? _deliveryBatchController.text.trim()
          : null,
      location: _locationController.text.trim().isNotEmpty
          ? _locationController.text.trim()
          : null,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
    );

    if (order != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderFormScreen(orderId: order.id),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to create order'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _addOrderItem() async {
    if (!_isEditMode || widget.orderId == null) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => OrderItemDialog(orderId: widget.orderId!),
    );

    if (result != null) {
      final provider = Provider.of<OrderProvider>(context, listen: false);
      await provider.addOrderItem(
        orderId: widget.orderId!,
        section: result['section'],
        feetValue: result['feetValue'],
        feetUnit: result['feetUnit'],
        flower1: result['flower1'],
        flower2: result['flower2'],
        flower3: result['flower3'],
        flower4: result['flower4'],
        flower5: result['flower5'],
        qty: result['qty'],
        qtyUnit: result['qtyUnit'],
        itemType: result['itemType'],
        usageFor: result['usageFor'],
        ratePerUnit: result['ratePerUnit'],
        amount: result['amount'],
      );
    }
  }

  Future<void> _editOrderItem(dynamic item) async {
    // TODO: Implement edit item dialog
  }

  Future<void> _deleteOrderItem(dynamic item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && item.id != null) {
      final provider = Provider.of<OrderProvider>(context, listen: false);
      await provider.deleteOrderItem(item.id);
    }
  }
}
