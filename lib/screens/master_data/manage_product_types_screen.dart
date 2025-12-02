import 'package:flutter/material.dart';
import 'package:invoice_generator/services/data_service.dart';
import 'package:invoice_generator/models/master_product_type.dart';

/// Screen for managing master product types data
class ManageProductTypesScreen extends StatefulWidget {
  const ManageProductTypesScreen({Key? key}) : super(key: key);

  @override
  State<ManageProductTypesScreen> createState() =>
      _ManageProductTypesScreenState();
}

class _ManageProductTypesScreenState extends State<ManageProductTypesScreen> {
  final DataService _dataService = DataService();
  final TextEditingController _searchController = TextEditingController();

  List<MasterProductType> _productTypes = [];
  List<MasterProductType> _filteredProductTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProductTypes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProductTypes() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Force fresh data from both local and Firebase
      final productTypesData = await _dataService.getMasterProductTypes();
      final productTypes = productTypesData
          .map((data) => MasterProductType.fromMap(data))
          .toList();

      if (mounted) {
        setState(() {
          _productTypes = productTypes;
          _filteredProductTypes = productTypes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading product types: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'RETRY',
              textColor: Colors.white,
              onPressed: _loadProductTypes,
            ),
          ),
        );
      }
    }
  }

  void _filterProductTypes(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredProductTypes = _productTypes;
      } else {
        _filteredProductTypes = _productTypes
            .where((productType) =>
                productType.name.toLowerCase().contains(query.toLowerCase()) ||
                productType.approxQuantity.toString().contains(query))
            .toList();
      }
    });
  }

  Future<void> _showAddEditDialog({MasterProductType? productType}) async {
    final nameController = TextEditingController(text: productType?.name ?? '');
    final approxQuantityController = TextEditingController(
        text: productType?.approxQuantity.toString() ?? '1');
    final formKey = GlobalKey<FormState>();

    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            productType == null ? 'Add Product Type' : 'Edit Product Type'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Type Name *',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: approxQuantityController,
                  decoration: const InputDecoration(
                    labelText: 'Approximate Quantity *',
                    hintText: 'Enter estimated quantity per shipment',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.trim().isEmpty == true) {
                      return 'Approximate quantity is required';
                    }
                    final quantity = int.tryParse(value!);
                    if (quantity == null || quantity <= 0) {
                      return 'Please enter a valid positive number';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  final productTypeData = {
                    'name': nameController.text.trim(),
                    'approx_quantity':
                        int.tryParse(approxQuantityController.text) ?? 1,
                  };

                  if (productType == null) {
                    await _dataService.saveMasterProductType(productTypeData);
                  } else {
                    await _dataService.updateMasterProductType(
                        productType.id, productTypeData);
                  }

                  // Close dialog first
                  Navigator.pop(context, true);

                  // Force immediate refresh after successful save
                  await Future.delayed(const Duration(milliseconds: 100));
                  await _loadProductTypes();
                } catch (e) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error saving product type: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(productType == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );

    // Controllers will be disposed by the frame callback
    // Refresh is handled inside the dialog save action

    // Dispose controllers after the current frame to avoid using disposed controllers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      approxQuantityController.dispose();
    });
  }

  Future<void> _deleteProductType(MasterProductType productType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product Type'),
        content: Text('Are you sure you want to delete "${productType.name}"?'),
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
        await _dataService.deleteMasterProductType(productType.id);

        // Force immediate refresh
        await _loadProductTypes();

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${productType.name}" deleted successfully'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'REFRESH',
                textColor: Colors.white,
                onPressed: _loadProductTypes,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting product type: $e'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'RETRY',
                textColor: Colors.white,
                onPressed: () => _deleteProductType(productType),
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
        title: const Text('Manage Product Types'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            onPressed: () async {
              // Show loading indicator
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 16),
                      Text('Force syncing from Firebase...'),
                    ],
                  ),
                  backgroundColor: Colors.blue,
                  duration: Duration(seconds: 10),
                ),
              );

              try {
                // Force sync master data from Firebase
                await _dataService.forceSyncMasterDataFromFirebase();

                // Refresh the UI
                await _loadProductTypes();

                // Show success message
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                            'Force sync completed! Data updated from Firebase.'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Force sync failed: $e')),
                      ],
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.cloud_sync),
            tooltip: 'Force Sync from Firebase',
          ),
          IconButton(
            onPressed: () {
              _loadProductTypes();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterProductTypes,
              decoration: InputDecoration(
                labelText: 'Search product types...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),

          // Product Types List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProductTypes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.category_outlined,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'No product types found\nTap + to add your first product type'
                                  : 'No product types match your search',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredProductTypes.length,
                        itemBuilder: (context, index) {
                          final productType = _filteredProductTypes[index];
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
                                  Icons.category,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              title: Text(
                                productType.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Approx. Quantity: ${productType.approxQuantity}',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _showAddEditDialog(
                                        productType: productType);
                                  } else if (value == 'delete') {
                                    _deleteProductType(productType);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 20),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete,
                                            size: 20, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
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
