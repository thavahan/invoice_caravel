import 'package:flutter/material.dart';
import 'package:invoice_generator/services/data_service.dart';
import 'package:invoice_generator/models/product.dart';
import 'package:invoice_generator/widgets/branded_loading_indicator.dart';

/// Screen for managing flower types (add/update/delete)
class ManageFlowerTypesScreen extends StatefulWidget {
  const ManageFlowerTypesScreen({Key? key}) : super(key: key);

  @override
  State<ManageFlowerTypesScreen> createState() =>
      _ManageFlowerTypesScreenState();
}

class _ManageFlowerTypesScreenState extends State<ManageFlowerTypesScreen> {
  final DataService _dataService = DataService();

  List<FlowerType> _flowerTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFlowerTypes();
  }

  Future<void> _loadFlowerTypes() async {
    setState(() => _isLoading = true);
    try {
      final data = await _dataService.getFlowerTypes();

      // DataService returns dynamic objects (FlowerType or Map)
      final items = <FlowerType>[];
      for (final item in data) {
        if (item is FlowerType) {
          items.add(item);
        } else if (item is Map<String, dynamic>) {
          items.add(FlowerType(
            id: item['id']?.toString() ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            flowerName: item['flower_name'] ?? item['flowerName'] ?? '',
            description: item['description'] ?? '',
          ));
        }
      }

      if (mounted) {
        setState(() {
          _flowerTypes = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error loading flower types: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showAddEditDialog({FlowerType? flowerType}) async {
    final nameController =
        TextEditingController(text: flowerType?.flowerName ?? '');
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        builder: (context, scrollController) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              controller: scrollController,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Text(
                        flowerType == null
                            ? 'Add Flower Type'
                            : 'Edit Flower Type',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Form Fields
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Flower Type *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_florist),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) => value?.trim().isEmpty == true
                        ? 'Name is required'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  // Buttons
                  Row(
                    children: [
                      if (flowerType != null) ...[
                        // Delete button (only for editing)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Flower Type'),
                                  content: Text(
                                      'Delete "${flowerType.flowerName}"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                try {
                                  await _dataService
                                      .deleteFlowerType(flowerType.id);
                                  Navigator.pop(context); // Close bottom sheet
                                  await _loadFlowerTypes();
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Error deleting flower type: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.delete, color: Colors.white),
                            label: const Text('Delete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      // Add/Update button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              try {
                                final data = {
                                  'flower_name': nameController.text.trim(),
                                  'description': '',
                                };

                                if (flowerType == null) {
                                  await _dataService.saveFlowerType(data);
                                } else {
                                  await _dataService.updateFlowerType(
                                      flowerType.id, data);
                                }

                                Navigator.pop(context);
                                await Future.delayed(
                                    const Duration(milliseconds: 100));
                                await _loadFlowerTypes();
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Error saving flower type: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          icon: Icon(
                            flowerType == null ? Icons.add : Icons.save,
                            color: Colors.white,
                          ),
                          label: Text(flowerType == null ? 'Add' : 'Update'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                flowerType == null ? Colors.blue : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Add extra bottom padding to prevent overflow
                  SizedBox(
                      height: MediaQuery.of(context).viewInsets.bottom > 0
                          ? 8
                          : 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Dispose controller safely after the widget tree updates
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Add extra delay to ensure all widget dependencies are cleared
      await Future.delayed(Duration(milliseconds: 100));

      // Check if the widget is still mounted and context is still valid
      if (!mounted) {
        try {
          // Avoid any context or ancestor lookups during disposal
          // Clear any listeners before disposal
          nameController.clearComposing();

          // Dispose safely without any context access
          nameController.dispose();
        } catch (e) {
          // Ignore any disposal errors completely
          // Do not use context or any ancestor widgets here
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Flower Types'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
              onPressed: _loadFlowerTypes, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
      ),
      body: _isLoading
          ? const Center(child: BrandedLoadingWidget.small())
          : _flowerTypes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_florist_outlined,
                          size: 64,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: 16),
                      Text('No flower types found\nTap + to add one',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  itemCount: _flowerTypes.length,
                  itemBuilder: (context, index) {
                    final f = _flowerTypes[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: Icon(Icons.local_florist,
                                color: Theme.of(context).colorScheme.primary)),
                        title: Text(f.flowerName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: f.description.isNotEmpty
                            ? Text(f.description)
                            : null,
                        onTap: () => _showAddEditDialog(flowerType: f),
                      ),
                    );
                  },
                ),
    );
  }
}
