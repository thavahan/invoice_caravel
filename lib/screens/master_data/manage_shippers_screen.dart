import 'package:flutter/material.dart';
import 'package:invoice_generator/services/data_service.dart';
import 'package:invoice_generator/models/master_shipper.dart';

/// Screen for managing master shippers data
class ManageShippersScreen extends StatefulWidget {
  const ManageShippersScreen({Key? key}) : super(key: key);

  @override
  State<ManageShippersScreen> createState() => _ManageShippersScreenState();
}

class _ManageShippersScreenState extends State<ManageShippersScreen> {
  final DataService _dataService = DataService();
  final TextEditingController _searchController = TextEditingController();

  List<MasterShipper> _shippers = [];
  List<MasterShipper> _filteredShippers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShippers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadShippers() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    print('🔄 MASTER_DATA_UI: Loading shippers...');

    try {
      final shippersData = await _dataService.getMasterShippers();
      final shippers =
          shippersData.map((data) => MasterShipper.fromMap(data)).toList();

      print('📊 MASTER_DATA_UI: Loaded ${shippers.length} shippers');

      if (mounted) {
        setState(() {
          _shippers = shippers;
          _filteredShippers = shippers;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ MASTER_DATA_UI: Error loading shippers: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading shippers: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: _loadShippers,
            ),
          ),
        );
      }
    }
  }

  void _filterShippers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredShippers = _shippers;
      } else {
        _filteredShippers = _shippers
            .where((shipper) =>
                shipper.name.toLowerCase().contains(query.toLowerCase()) ||
                shipper.address.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  /// Parse stored address string into individual components
  Map<String, String> _parseAddress(String addressStr) {
    final components = {
      'phone': '',
      'addressLine1': '',
      'addressLine2': '',
      'city': '',
      'state': '',
      'pincode': '',
      'landmark': '',
    };

    if (addressStr.isEmpty) return components;

    final parts = addressStr.split(',').map((s) => s.trim()).toList();

    for (final part in parts) {
      if (part.startsWith('Ph:')) {
        components['phone'] = part.replaceFirst('Ph:', '').trim();
      } else if (part.startsWith('(') && part.endsWith(')')) {
        components['landmark'] = part.substring(1, part.length - 1);
      } else if (components['addressLine1']!.isEmpty) {
        components['addressLine1'] = part;
      } else if (components['addressLine2']!.isEmpty) {
        components['addressLine2'] = part;
      } else if (components['city']!.isEmpty) {
        components['city'] = part;
      } else if (components['state']!.isEmpty) {
        components['state'] = part;
      } else if (components['pincode']!.isEmpty) {
        components['pincode'] = part;
      }
    }

    return components;
  }

  Future<void> _showAddEditDialog({MasterShipper? shipper}) async {
    final nameController = TextEditingController(text: shipper?.name ?? '');
    final phoneController = TextEditingController(text: shipper?.phone ?? '');
    final addr1Controller =
        TextEditingController(text: shipper?.addressLine1 ?? '');
    final addr2Controller =
        TextEditingController(text: shipper?.addressLine2 ?? '');
    final cityController = TextEditingController(text: shipper?.city ?? '');
    final stateController = TextEditingController(text: shipper?.state ?? '');
    final pincodeController =
        TextEditingController(text: shipper?.pincode ?? '');
    final landmarkController =
        TextEditingController(text: shipper?.landmark ?? '');

    // If editing and fields are empty, try to parse from stored address
    if (shipper != null &&
        phoneController.text.isEmpty &&
        addr1Controller.text.isEmpty) {
      final parsed = _parseAddress(shipper.address);
      phoneController.text = parsed['phone']!;
      addr1Controller.text = parsed['addressLine1']!;
      addr2Controller.text = parsed['addressLine2']!;
      cityController.text = parsed['city']!;
      stateController.text = parsed['state']!;
      pincodeController.text = parsed['pincode']!;
      landmarkController.text = parsed['landmark']!;
    }

    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      shipper == null ? 'Add Shipper' : 'Edit Shipper',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Form Content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Shipper Name *',
                          prefixIcon: const Icon(Icons.business),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) => value?.trim().isEmpty == true
                            ? 'Name is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: addr1Controller,
                        decoration: InputDecoration(
                          labelText: 'Address Line 1 *',
                          hintText: 'Street address',
                          prefixIcon: const Icon(Icons.location_on),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) => value?.trim().isEmpty == true
                            ? 'Address Line 1 is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: addr2Controller,
                        decoration: InputDecoration(
                          labelText: 'Address Line 2',
                          hintText: 'Apartment, suite, etc.',
                          prefixIcon: const Icon(Icons.apartment),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: cityController,
                              decoration: InputDecoration(
                                labelText: 'City *',
                                prefixIcon: const Icon(Icons.location_city),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              textCapitalization: TextCapitalization.words,
                              validator: (value) =>
                                  value?.trim().isEmpty == true
                                      ? 'Required'
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: stateController,
                              decoration: InputDecoration(
                                labelText: 'State *',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              textCapitalization: TextCapitalization.words,
                              validator: (value) =>
                                  value?.trim().isEmpty == true
                                      ? 'Required'
                                      : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: pincodeController,
                        decoration: InputDecoration(
                          labelText: 'Postal Code *',
                          hintText: '110001',
                          prefixIcon: const Icon(Icons.pin),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) => value?.trim().isEmpty == true
                            ? 'Postal Code is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: landmarkController,
                        decoration: InputDecoration(
                          labelText: 'Landmark/Notes',
                          hintText: 'e.g., Near the main gate',
                          prefixIcon: const Icon(Icons.note),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: phoneController,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          hintText: '9876543210',
                          prefixIcon: const Icon(Icons.phone),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: shipper == null
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              Navigator.pop(context, false);
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                try {
                                  // Dismiss keyboard before saving
                                  FocusScope.of(context).unfocus();

                                  // Format address as single string
                                  final formattedAddress =
                                      MasterShipper.formatAddress(
                                    phone: phoneController.text.trim(),
                                    addressLine1: addr1Controller.text.trim(),
                                    addressLine2: addr2Controller.text.trim(),
                                    city: cityController.text.trim(),
                                    state: stateController.text.trim(),
                                    pincode: pincodeController.text.trim(),
                                    landmark: landmarkController.text.trim(),
                                  );

                                  final shipperData = {
                                    'name': nameController.text.trim(),
                                    'address': formattedAddress,
                                    'phone': phoneController.text.trim(),
                                    'address_line1': addr1Controller.text.trim(),
                                    'address_line2': addr2Controller.text.trim(),
                                    'city': cityController.text.trim(),
                                    'state': stateController.text.trim(),
                                    'pincode': pincodeController.text.trim(),
                                    'landmark': landmarkController.text.trim(),
                                  };

                                  await _dataService.saveMasterShipper(shipperData);
                                  print(
                                      '✅ MASTER_DATA_UI: New shipper saved: ${shipperData['name']}');

                                  // Close dialog first
                                  Navigator.pop(context, true);

                                  // Force immediate refresh after successful save
                                  await Future.delayed(
                                      const Duration(milliseconds: 100));
                                  await _loadShippers();

                                  print(
                                      '🔄 MASTER_DATA_UI: Shippers refreshed after save');
                                } catch (e) {
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error saving shipper: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Add'),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  FocusScope.of(context).unfocus();
                                  Navigator.pop(context, false);
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Shipper'),
                                      content: Text(
                                          'Are you sure you want to delete "${shipper.name}"? This action cannot be undone.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true) {
                                    try {
                                      await _dataService.deleteMasterShipper(shipper.id);
                                      print('✅ MASTER_DATA_UI: Shipper deleted: ${shipper.name}');

                                      // Close dialog first
                                      Navigator.pop(context, true);

                                      // Force immediate refresh after successful delete
                                      await Future.delayed(
                                          const Duration(milliseconds: 100));
                                      await _loadShippers();

                                      print('🔄 MASTER_DATA_UI: Shippers refreshed after delete');
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error deleting shipper: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Delete'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                try {
                                  // Dismiss keyboard before saving
                                  FocusScope.of(context).unfocus();

                                  // Format address as single string
                                  final formattedAddress =
                                      MasterShipper.formatAddress(
                                    phone: phoneController.text.trim(),
                                    addressLine1: addr1Controller.text.trim(),
                                    addressLine2: addr2Controller.text.trim(),
                                    city: cityController.text.trim(),
                                    state: stateController.text.trim(),
                                    pincode: pincodeController.text.trim(),
                                    landmark: landmarkController.text.trim(),
                                  );

                                  final shipperData = {
                                    'name': nameController.text.trim(),
                                    'address': formattedAddress,
                                    'phone': phoneController.text.trim(),
                                    'address_line1': addr1Controller.text.trim(),
                                    'address_line2': addr2Controller.text.trim(),
                                    'city': cityController.text.trim(),
                                    'state': stateController.text.trim(),
                                    'pincode': pincodeController.text.trim(),
                                    'landmark': landmarkController.text.trim(),
                                  };

                                  await _dataService.updateMasterShipper(
                                      shipper.id, shipperData);
                                  print(
                                      '✅ MASTER_DATA_UI: Shipper updated: ${shipperData['name']}');

                                  // Close dialog first
                                  Navigator.pop(context, true);

                                  // Force immediate refresh after successful save
                                  await Future.delayed(
                                      const Duration(milliseconds: 100));
                                  await _loadShippers();

                                  print(
                                      '🔄 MASTER_DATA_UI: Shippers refreshed after save');
                                } catch (e) {
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error saving shipper: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Update'),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );

    // Dispose controllers after the current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      phoneController.dispose();
      addr1Controller.dispose();
      addr2Controller.dispose();
      cityController.dispose();
      stateController.dispose();
      pincodeController.dispose();
      landmarkController.dispose();
    });
  }

  Future<void> _deleteShipper(MasterShipper shipper) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shipper'),
        content: Text('Are you sure you want to delete "${shipper.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dataService.deleteMasterShipper(shipper.id);
        print('🗑️ MASTER_DATA_UI: Shipper deleted: ${shipper.name}');

        // Force immediate refresh
        await _loadShippers();

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${shipper.name}" deleted successfully'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'REFRESH',
                textColor: Colors.white,
                onPressed: _loadShippers,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting shipper: $e'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'RETRY',
                textColor: Colors.white,
                onPressed: () => _deleteShipper(shipper),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Shippers'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            onPressed: _loadShippers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterShippers,
              decoration: InputDecoration(
                labelText: 'Search shippers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).inputDecorationTheme.fillColor,
              ),
            ),
          ),

          // Shippers List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredShippers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.business_outlined,
                              size: 64,
                              color: Theme.of(context)
                                  .iconTheme
                                  .color
                                  ?.withOpacity(0.6),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No shippers found\nTap + to add your first shipper'
                                  : 'No shippers match your search',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredShippers.length,
                        itemBuilder: (context, index) {
                          final shipper = _filteredShippers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                child: Icon(
                                  Icons.business,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              title: Text(
                                shipper.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  shipper.address,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              onTap: () => _showAddEditDialog(shipper: shipper),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
