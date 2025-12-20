import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:invoice_generator/services/data_service.dart';
import 'package:invoice_generator/models/master_product_type.dart';
import 'package:invoice_generator/screens/invoice_form/invoice_form.dart';

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
    final rateController =
        TextEditingController(text: productType?.rate.toString() ?? '0.0');
    final categoryController =
        TextEditingController(text: productType?.category ?? '');
    final genusSpeciesNameController =
        TextEditingController(text: productType?.genusSpeciesName ?? '');
    final plantFamilyNameController =
        TextEditingController(text: productType?.plantFamilyName ?? '');
    final countryOfOriginController =
        TextEditingController(text: productType?.countryOfOrigin ?? '');
    final specialsController =
        TextEditingController(text: productType?.specials ?? '');
    final formKey = GlobalKey<FormState>();
    bool hasStems = productType?.hasStems ?? false; // Default to No stems

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        builder: (context, scrollController) => Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      productType == null
                          ? 'Add Product Type'
                          : 'Edit Product Type',
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
                          labelText: 'Product Type Name *',
                          prefixIcon: const Icon(Icons.category),
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
                        controller: approxQuantityController,
                        decoration: InputDecoration(
                          labelText: 'Approximate Quantity *',
                          hintText: 'Enter estimated quantity per shipment',
                          prefixIcon: const Icon(Icons.numbers),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                      const SizedBox(height: 16),
                      StatefulBuilder(
                        builder: (context, setState) => SwitchListTile(
                          title: const Text('Has Stems'),
                          subtitle:
                              const Text('Whether this product type has stems'),
                          value: hasStems,
                          onChanged: (value) {
                            setState(() {
                              hasStems = value ?? false;
                            });
                          },
                          secondary: const Icon(Icons.grass),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: rateController,
                        decoration: InputDecoration(
                          labelText: 'Rate (per kg) *',
                          hintText: 'Enter rate per kilogram',
                          prefixIcon: const Icon(Icons.attach_money),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value?.trim().isEmpty == true) {
                            return 'Rate is required';
                          }
                          final rate = double.tryParse(value!);
                          if (rate == null || rate < 0) {
                            return 'Please enter a valid non-negative number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: categoryController,
                        decoration: InputDecoration(
                          labelText: 'Category *',
                          hintText: 'Enter product category',
                          prefixIcon: const Icon(Icons.category),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) => value?.trim().isEmpty == true
                            ? 'Category is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: genusSpeciesNameController,
                        decoration: InputDecoration(
                          labelText: 'Genus/Species Name *',
                          hintText: 'Enter genus or species name',
                          prefixIcon: const Icon(Icons.science),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) => value?.trim().isEmpty == true
                            ? 'Genus/Species Name is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: plantFamilyNameController,
                        decoration: InputDecoration(
                          labelText: 'Plant/Family Name *',
                          hintText: 'Enter plant or family name',
                          prefixIcon: const Icon(Icons.nature),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) => value?.trim().isEmpty == true
                            ? 'Plant/Family Name is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: countryOfOriginController,
                        decoration: InputDecoration(
                          labelText: 'Country of Origin *',
                          hintText: 'Enter country of origin',
                          prefixIcon: const Icon(Icons.flag),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) => value?.trim().isEmpty == true
                            ? 'Country of Origin is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: specialsController,
                        decoration: InputDecoration(
                          labelText: 'Specials',
                          hintText:
                              'Enter any special notes, requirements, or additional information (optional)',
                          prefixIcon: const Icon(Icons.star_border),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withOpacity(0.1),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(24),
              child: productType == null
                  ? SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            try {
                              // Dismiss keyboard before saving
                              FocusScope.of(context).unfocus();

                              final productTypeData = {
                                'name': nameController.text.trim(),
                                'approx_quantity': int.tryParse(
                                        approxQuantityController.text) ??
                                    1,
                                'has_stems': hasStems ? 1 : 0,
                                'rate':
                                    double.tryParse(rateController.text) ?? 0.0,
                                'category': categoryController.text.trim(),
                                'genus_species_name':
                                    genusSpeciesNameController.text.trim(),
                                'plant_family_name':
                                    plantFamilyNameController.text.trim(),
                                'country_of_origin':
                                    countryOfOriginController.text.trim(),
                                'specials':
                                    specialsController.text.trim().isEmpty
                                        ? null
                                        : specialsController.text.trim(),
                              };

                              await _dataService
                                  .saveMasterProductType(productTypeData);

                              // Close dialog first
                              Navigator.pop(context, true);

                              // Force immediate refresh after successful save
                              await Future.delayed(
                                  const Duration(milliseconds: 100));
                              await _loadProductTypes();
                            } catch (e) {
                              ScaffoldMessenger.of(context)
                                  .hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Error saving product type: $e'),
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
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Product Type'),
                                  content: Text(
                                      'Are you sure you want to delete "${productType.name}"? This action cannot be undone.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
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
                                  await _dataService
                                      .deleteMasterProductType(productType.id);
                                  print(
                                      '✅ Product type deleted: ${productType.name}');

                                  // Close dialog first
                                  Navigator.pop(context, true);

                                  // Force immediate refresh after successful delete
                                  await Future.delayed(
                                      const Duration(milliseconds: 100));
                                  await _loadProductTypes();

                                  print(
                                      '🔄 Product types refreshed after delete');
                                } catch (e) {
                                  ScaffoldMessenger.of(context)
                                      .hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Error deleting product type: $e'),
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                try {
                                  // Dismiss keyboard before saving
                                  FocusScope.of(context).unfocus();

                                  final productTypeData = {
                                    'name': nameController.text.trim(),
                                    'approx_quantity': int.tryParse(
                                            approxQuantityController.text) ??
                                        1,
                                    'has_stems': hasStems ? 1 : 0,
                                    'rate':
                                        double.tryParse(rateController.text) ??
                                            0.0,
                                    'category': categoryController.text.trim(),
                                    'genus_species_name':
                                        genusSpeciesNameController.text.trim(),
                                    'plant_family_name':
                                        plantFamilyNameController.text.trim(),
                                    'country_of_origin':
                                        countryOfOriginController.text.trim(),
                                    'specials':
                                        specialsController.text.trim().isEmpty
                                            ? null
                                            : specialsController.text.trim(),
                                  };

                                  await _dataService.updateMasterProductType(
                                      productType.id, productTypeData);

                                  // Close dialog first
                                  Navigator.pop(context, true);

                                  // Force immediate refresh after successful save
                                  await Future.delayed(
                                      const Duration(milliseconds: 100));
                                  await _loadProductTypes();

                                  print(
                                      '🔄 Product types refreshed after save');
                                } catch (e) {
                                  ScaffoldMessenger.of(context)
                                      .hideCurrentSnackBar();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Error saving product type: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
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

    // Dispose controllers after the modal animation completes
    SchedulerBinding.instance.addPostFrameCallback((_) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          nameController.dispose();
          approxQuantityController.dispose();
          rateController.dispose();
          categoryController.dispose();
          genusSpeciesNameController.dispose();
          plantFamilyNameController.dispose();
          countryOfOriginController.dispose();
          specialsController.dispose();
        });
      });
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Approx. Quantity: ${productType.approxQuantity}',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Rate: \$${productType.rate.toStringAsFixed(2)}/kg',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Category: ${productType.category}',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          productType.hasStems
                                              ? Icons.grass
                                              : Icons.grass_outlined,
                                          size: 16,
                                          color: productType.hasStems
                                              ? Colors.green
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          productType.hasStems
                                              ? 'Has Stems'
                                              : 'No Stems',
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              onTap: () =>
                                  _showAddEditDialog(productType: productType),
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
