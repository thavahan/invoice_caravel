import 'package:flutter/material.dart';
import '../services/order_service.dart';

/// Dialog for adding/editing order items
class OrderItemDialog extends StatefulWidget {
  final int orderId;
  final Map<String, dynamic>? initialData; // For editing existing items

  const OrderItemDialog({
    Key? key,
    required this.orderId,
    this.initialData,
  }) : super(key: key);

  @override
  State<OrderItemDialog> createState() => _OrderItemDialogState();
}

class _OrderItemDialogState extends State<OrderItemDialog> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _feetValueController = TextEditingController();
  final _qtyController = TextEditingController();
  final _rateController = TextEditingController();
  final _amountController = TextEditingController();

  // Dropdown values
  String? _selectedSection;
  String? _selectedFeetUnit;
  String? _selectedFlower1;
  String? _selectedFlower2;
  String? _selectedFlower3;
  String? _selectedFlower4;
  String? _selectedFlower5;
  String? _selectedQtyUnit;
  String? _selectedItemType;
  String? _selectedUsageFor;

  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.initialData != null;
    _loadInitialData();
    _setupCalculation();
  }

  @override
  void dispose() {
    _feetValueController.dispose();
    _qtyController.dispose();
    _rateController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    if (widget.initialData == null) return;

    final data = widget.initialData!;
    _selectedSection = data['section'];
    _feetValueController.text = data['feetValue']?.toString() ?? '';
    _selectedFeetUnit = data['feetUnit'];
    _selectedFlower1 = data['flower1'];
    _selectedFlower2 = data['flower2'];
    _selectedFlower3 = data['flower3'];
    _selectedFlower4 = data['flower4'];
    _selectedFlower5 = data['flower5'];
    _qtyController.text = data['qty']?.toString() ?? '';
    _selectedQtyUnit = data['qtyUnit'];
    _selectedItemType = data['itemType'];
    _selectedUsageFor = data['usageFor'];
    _rateController.text = data['ratePerUnit']?.toString() ?? '';
    _amountController.text = data['amount']?.toString() ?? '';
  }

  void _setupCalculation() {
    _qtyController.addListener(_calculateAmount);
    _rateController.addListener(_calculateAmount);
  }

  void _calculateAmount() {
    final qty = double.tryParse(_qtyController.text) ?? 0.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;
    final amount = qty * rate;
    _amountController.text = amount > 0 ? amount.toStringAsFixed(2) : '';
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: _buildForm(),
                ),
              ),
              _buildButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _isEditMode ? 'Edit Item' : 'Add Item',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return ListView(
      children: [
        // Section
        _buildSectionDropdown(),
        const SizedBox(height: 16),

        // Feet row
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildFeetValueField(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildFeetUnitDropdown(),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Flowers section
        Text(
          'Flowers',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        _buildFlowerDropdown(
            'Flower 1', _selectedFlower1, (value) => _selectedFlower1 = value),
        const SizedBox(height: 8),
        _buildFlowerDropdown(
            'Flower 2', _selectedFlower2, (value) => _selectedFlower2 = value),
        const SizedBox(height: 8),
        _buildFlowerDropdown(
            'Flower 3', _selectedFlower3, (value) => _selectedFlower3 = value),
        const SizedBox(height: 8),
        _buildFlowerDropdown(
            'Flower 4', _selectedFlower4, (value) => _selectedFlower4 = value),
        const SizedBox(height: 8),
        _buildFlowerDropdown(
            'Flower 5', _selectedFlower5, (value) => _selectedFlower5 = value),
        const SizedBox(height: 16),

        // Quantity row
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildQtyField(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQtyUnitDropdown(),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Item type
        _buildItemTypeDropdown(),
        const SizedBox(height: 16),

        // Usage for
        _buildUsageForDropdown(),
        const SizedBox(height: 16),

        // Pricing section
        Text(
          'Pricing (Optional)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildRateField(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildAmountField(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedSection,
      decoration: const InputDecoration(
        labelText: 'Section',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.category),
      ),
      items: OrderService.sections.map((section) {
        return DropdownMenuItem(
          value: section,
          child: Text(section),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedSection = value;
        });
      },
    );
  }

  Widget _buildFeetValueField() {
    return TextFormField(
      controller: _feetValueController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Feet/Size Value',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.straighten),
      ),
    );
  }

  Widget _buildFeetUnitDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedFeetUnit,
      decoration: const InputDecoration(
        labelText: 'Unit',
        border: OutlineInputBorder(),
      ),
      items: OrderService.units.map((unit) {
        return DropdownMenuItem(
          value: unit,
          child: Text(unit),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedFeetUnit = value;
        });
      },
    );
  }

  Widget _buildFlowerDropdown(
      String label, String? value, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.local_florist),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('-- Select Flower --'),
        ),
        ...OrderService.flowers.map((flower) {
          return DropdownMenuItem(
            value: flower,
            child: Text(flower),
          );
        }).toList(),
      ],
      onChanged: (newValue) {
        setState(() {
          onChanged(newValue);
        });
      },
    );
  }

  Widget _buildQtyField() {
    return TextFormField(
      controller: _qtyController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Quantity',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.numbers),
      ),
    );
  }

  Widget _buildQtyUnitDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedQtyUnit,
      decoration: const InputDecoration(
        labelText: 'Qty Unit',
        border: OutlineInputBorder(),
      ),
      items: OrderService.qtyUnits.map((unit) {
        return DropdownMenuItem(
          value: unit,
          child: Text(unit),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedQtyUnit = value;
        });
      },
    );
  }

  Widget _buildItemTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedItemType,
      decoration: const InputDecoration(
        labelText: 'Item Type',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.type_specimen),
      ),
      items: OrderService.itemTypes.map((type) {
        return DropdownMenuItem(
          value: type,
          child: Text(type),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedItemType = value;
        });
      },
    );
  }

  Widget _buildUsageForDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedUsageFor,
      decoration: const InputDecoration(
        labelText: 'Usage For',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.place),
      ),
      items: OrderService.usageOptions.map((usage) {
        return DropdownMenuItem(
          value: usage,
          child: Text(usage),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedUsageFor = value;
        });
      },
    );
  }

  Widget _buildRateField() {
    return TextFormField(
      controller: _rateController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Rate per Unit',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.attach_money),
      ),
    );
  }

  Widget _buildAmountField() {
    return TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Amount',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.calculate),
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _saveItem,
          child: Text(_isEditMode ? 'Update' : 'Add Item'),
        ),
      ],
    );
  }

  void _saveItem() {
    final result = {
      'section': _selectedSection,
      'feetValue': double.tryParse(_feetValueController.text),
      'feetUnit': _selectedFeetUnit,
      'flower1': _selectedFlower1,
      'flower2': _selectedFlower2,
      'flower3': _selectedFlower3,
      'flower4': _selectedFlower4,
      'flower5': _selectedFlower5,
      'qty': double.tryParse(_qtyController.text),
      'qtyUnit': _selectedQtyUnit,
      'itemType': _selectedItemType,
      'usageFor': _selectedUsageFor,
      'ratePerUnit': double.tryParse(_rateController.text),
      'amount': double.tryParse(_amountController.text),
    };

    Navigator.of(context).pop(result);
  }
}
