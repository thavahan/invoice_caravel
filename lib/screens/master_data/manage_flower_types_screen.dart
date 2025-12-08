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

    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(flowerType == null ? 'Add Flower Type' : 'Edit Flower Type'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Flower Type *',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) =>
                value?.trim().isEmpty == true ? 'Name is required' : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
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
                    await _dataService.updateFlowerType(flowerType.id, data);
                  }

                  Navigator.pop(context, true);
                  await Future.delayed(const Duration(milliseconds: 100));
                  await _loadFlowerTypes();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error saving flower type: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(flowerType == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
    });
  }

  Future<void> _deleteFlowerType(FlowerType flowerType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Flower Type'),
        content: Text('Delete "${flowerType.flowerName}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _dataService.deleteFlowerType(flowerType.id);
        await _loadFlowerTypes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('"${flowerType.flowerName}" deleted'),
                backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error deleting: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
                            child: Icon(Icons.local_florist,
                                color: Theme.of(context).colorScheme.primary)),
                        title: Text(f.flowerName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: f.description.isNotEmpty
                            ? Text(f.description)
                            : null,
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showAddEditDialog(flowerType: f);
                            } else if (value == 'delete') {
                              _deleteFlowerType(f);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [
                                  Icon(Icons.edit, size: 20),
                                  SizedBox(width: 8),
                                  Text('Edit')
                                ])),
                            const PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  Icon(Icons.delete,
                                      size: 20, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete',
                                      style: TextStyle(color: Colors.red))
                                ])),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
