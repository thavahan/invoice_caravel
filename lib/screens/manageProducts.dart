import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:invoice_generator/models/product.dart';

class ManageProducts extends StatefulWidget {
  const ManageProducts({super.key});

  @override
  State<ManageProducts> createState() => _ManageProductsState();
}

class _ManageProductsState extends State<ManageProducts>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Add new item dialog
  void _addItem() async {
    final formKey = GlobalKey<FormState>();
    final flowerTypeIdController = TextEditingController();
    final weightKgController = TextEditingController();
    final formController = TextEditingController();
    final quantityController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Item'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: flowerTypeIdController,
                  decoration: InputDecoration(labelText: 'Flower Type ID'),
                  validator: (value) =>
                      value?.isEmpty == true ? 'Required' : null,
                ),
                TextFormField(
                  controller: weightKgController,
                  decoration: InputDecoration(labelText: 'Weight (kg)'),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  validator: (value) =>
                      value?.isEmpty == true ? 'Required' : null,
                ),
                TextFormField(
                  controller: formController,
                  decoration: InputDecoration(labelText: 'Form'),
                  validator: (value) =>
                      value?.isEmpty == true ? 'Required' : null,
                ),
                TextFormField(
                  controller: quantityController,
                  decoration: InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value?.isEmpty == true ? 'Required' : null,
                ),
                TextFormField(
                  controller: notesController,
                  decoration: InputDecoration(labelText: 'Notes'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  final item = Item(
                    id: '',
                    flowerTypeId: flowerTypeIdController.text,
                    weightKg: double.parse(weightKgController.text),
                    form: formController.text,
                    quantity: int.parse(quantityController.text),
                    notes: notesController.text,
                  );

                  await _firestore.collection('items').add(item.toMap());
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Item added successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  // Add new flower type dialog
  void _addFlowerType() async {
    final formKey = GlobalKey<FormState>();
    final flowerNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Flower Type'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: flowerNameController,
            decoration: InputDecoration(labelText: 'Flower Name'),
            validator: (value) => value?.isEmpty == true ? 'Required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  final flowerType = FlowerType(
                    id: '',
                    flowerName: flowerNameController.text,
                  );

                  await _firestore
                      .collection('flowerTypes')
                      .add(flowerType.toMap());
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Flower type added successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Logistics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Items'),
            Tab(text: 'Flower Types'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Items Tab
          Column(
            children: [
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Items',
                        style: Theme.of(context).textTheme.headlineSmall),
                    ElevatedButton(
                      onPressed: _addItem,
                      child: Text('Add Item'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('items').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('No items found'));
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final item = Item.fromMap(
                            doc.id, doc.data() as Map<String, dynamic>);

                        return Card(
                          margin:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            title: Text(item.form),
                            subtitle: Text(
                                'Weight: ${item.weightKg} kg, Quantity: ${item.quantity}'),
                            trailing: Text('Type: ${item.flowerTypeId}'),
                            onTap: () {
                              // TODO: Add edit functionality
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          // Flower Types Tab
          Column(
            children: [
              Padding(
                padding: EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Flower Types',
                        style: Theme.of(context).textTheme.headlineSmall),
                    ElevatedButton(
                      onPressed: _addFlowerType,
                      child: Text('Add Flower Type'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('flowerTypes').snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('No flower types found'));
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final flowerType = FlowerType.fromMap(
                            doc.id, doc.data() as Map<String, dynamic>);

                        return Card(
                          margin:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            title: Text(flowerType.flowerName),
                            subtitle: Text('ID: ${flowerType.id}'),
                            onTap: () {
                              // TODO: Add edit functionality
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
