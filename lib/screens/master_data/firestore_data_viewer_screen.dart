import 'package:flutter/material.dart';
import 'package:invoice_generator/models/shipment.dart';
import 'package:invoice_generator/models/box_product.dart';
import 'package:invoice_generator/models/master_shipper.dart';
import 'package:invoice_generator/models/master_consignee.dart';
import 'package:invoice_generator/models/master_product_type.dart';
import 'package:invoice_generator/models/product.dart';
import 'package:invoice_generator/services/firebase_service.dart';

/// Screen to view all data stored in Firestore
class FirestoreDataViewerScreen extends StatefulWidget {
  const FirestoreDataViewerScreen({Key? key}) : super(key: key);

  @override
  State<FirestoreDataViewerScreen> createState() =>
      _FirestoreDataViewerScreenState();
}

class _FirestoreDataViewerScreenState extends State<FirestoreDataViewerScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  late TabController _tabController;

  List<Shipment> _shipments = [];
  List<MasterShipper> _shippers = [];
  List<MasterConsignee> _consignees = [];
  List<MasterProductType> _productTypes = [];
  List<FlowerType> _flowerTypes = [];
  Map<String, List<ShipmentBox>> _shipmentBoxes = {};
  Map<String, List<ShipmentProduct>> _boxProducts = {};

  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Load all data in parallel
      final results = await Future.wait([
        _firebaseService.getShipments(limit: 1000), // Get all shipments
        _firebaseService.getMasterShippers(),
        _firebaseService.getMasterConsignees(),
        _firebaseService.getMasterProductTypes(),
        _firebaseService.getFlowerTypes(),
      ]);

      _shipments = results[0] as List<Shipment>;
      _shippers = results[1] as List<MasterShipper>;
      _consignees = results[2] as List<MasterConsignee>;
      _productTypes = results[3] as List<MasterProductType>;
      _flowerTypes = results[4] as List<FlowerType>;

      // Load boxes and products for each shipment
      for (final shipment in _shipments) {
        try {
          final boxes = await _firebaseService
              .getBoxesForShipment(shipment.invoiceNumber);
          _shipmentBoxes[shipment.invoiceNumber] = boxes;

          for (final box in boxes) {
            try {
              final products = await _firebaseService.getProductsForBox(
                  shipment.invoiceNumber, box.id);
              _boxProducts[box.id] = products;
            } catch (e) {
              _boxProducts[box.id] = [];
            }
          }
        } catch (e) {
          _shipmentBoxes[shipment.invoiceNumber] = [];
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading data: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore Data Viewer'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(
              icon: const Icon(Icons.inventory),
              text: 'Shipments (${_shipments.length})',
            ),
            Tab(
              icon: const Icon(Icons.business),
              text: 'Shippers (${_shippers.length})',
            ),
            Tab(
              icon: const Icon(Icons.person_outline),
              text: 'Consignees (${_consignees.length})',
            ),
            Tab(
              icon: const Icon(Icons.category),
              text: 'Product Types (${_productTypes.length})',
            ),
            Tab(
              icon: const Icon(Icons.local_florist),
              text: 'Flower Types (${_flowerTypes.length})',
            ),
            Tab(
              icon: const Icon(Icons.inventory_2),
              text: 'Boxes & Products',
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surfaceContainerHighest,
              Theme.of(context).colorScheme.surface
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 64,
                            color: Theme.of(context).colorScheme.error),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadAllData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildShipmentsTab(),
                      _buildShippersTab(),
                      _buildConsigneesTab(),
                      _buildProductTypesTab(),
                      _buildFlowerTypesTab(),
                      _buildBoxesProductsTab(),
                    ],
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadAllData,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child:
            Icon(Icons.refresh, color: Theme.of(context).colorScheme.onPrimary),
        tooltip: 'Refresh Data',
      ),
    );
  }

  Widget _buildShipmentsTab() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _shipments.length,
        itemBuilder: (context, index) {
          final shipment = _shipments[index];
          final boxes = _shipmentBoxes[shipment.invoiceNumber] ?? [];
          final totalProducts = boxes.fold<int>(
            0,
            (sum, box) => sum + (_boxProducts[box.id]?.length ?? 0),
          );

          return Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              title: Text(
                'Invoice #${shipment.invoiceNumber}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date: ${shipment.eta.toString().split(' ')[0]}'),
                  Text('Status: ${shipment.status}'),
                  Text('Boxes: ${boxes.length}, Products: $totalProducts'),
                ],
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Invoice Number', shipment.invoiceNumber),
                      _buildDetailRow('Invoice Title', shipment.invoiceTitle),
                      _buildDetailRow('Shipper', shipment.shipper),
                      _buildDetailRow(
                          'Shipper Address', shipment.shipperAddress),
                      _buildDetailRow('Consignee', shipment.consignee),
                      _buildDetailRow(
                          'Consignee Address', shipment.consigneeAddress),
                      _buildDetailRow('Client Reference', shipment.clientRef),
                      _buildDetailRow('AWB', shipment.awb),
                      _buildDetailRow('Master AWB', shipment.masterAwb),
                      _buildDetailRow('House AWB', shipment.houseAwb),
                      _buildDetailRow('Flight Number', shipment.flightNo),
                      _buildDetailRow('Flight Date',
                          shipment.flightDate?.toString() ?? 'Not set'),
                      _buildDetailRow(
                          'Discharge Airport', shipment.dischargeAirport),
                      _buildDetailRow('Origin', shipment.origin),
                      _buildDetailRow('Destination', shipment.destination),
                      _buildDetailRow('ETA', shipment.eta.toString()),
                      _buildDetailRow('Invoice Date',
                          shipment.invoiceDate?.toString() ?? 'Not set'),
                      _buildDetailRow('Date of Issue',
                          shipment.dateOfIssue?.toString() ?? 'Not set'),
                      _buildDetailRow(
                          'Place of Receipt', shipment.placeOfReceipt),
                      _buildDetailRow('SGST Number', shipment.sgstNo),
                      _buildDetailRow('IEC Code', shipment.iecCode),
                      _buildDetailRow('Freight Terms', shipment.freightTerms),
                      _buildDetailRow(
                          'Gross Weight', shipment.grossWeight.toString()),
                      _buildDetailRow('Status', shipment.status),
                      const SizedBox(height: 12),
                      const Text(
                        'Boxes:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...boxes.map((box) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Box ${box.boxNumber}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                    'Dimensions: ${box.length}x${box.width}x${box.height}'),
                                Text(
                                    'Products: ${_boxProducts[box.id]?.length ?? 0}'),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShippersTab() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _shippers.length,
        itemBuilder: (context, index) {
          final shipper = _shippers[index];
          return Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(Icons.business,
                    color: Theme.of(context).colorScheme.primary),
              ),
              title: Text(
                shipper.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shipper.address),
                  Text(
                      'Created: ${shipper.createdAt.toString().split(' ')[0]}'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConsigneesTab() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _consignees.length,
        itemBuilder: (context, index) {
          final consignee = _consignees[index];
          return Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(Icons.person_outline,
                    color: Theme.of(context).colorScheme.primary),
              ),
              title: Text(
                consignee.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(consignee.address),
                  Text(
                      'Created: ${consignee.createdAt.toString().split(' ')[0]}'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductTypesTab() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _productTypes.length,
        itemBuilder: (context, index) {
          final productType = _productTypes[index];
          return Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(Icons.category,
                    color: Theme.of(context).colorScheme.primary),
              ),
              title: Text(
                productType.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Approx Quantity: ${productType.approxQuantity}'),
                  Text('Rate: \$${productType.rate.toStringAsFixed(2)}/kg'),
                  Text('Category: ${productType.category}'),
                  Text('Genus/Species: ${productType.genusSpeciesName}'),
                  Text('Plant/Family: ${productType.plantFamilyName}'),
                  if (productType.specials != null &&
                      productType.specials!.isNotEmpty)
                    Text('Specials: ${productType.specials}'),
                  Text('Country of Origin: ${productType.countryOfOrigin}'),
                  Text('Has Stems: ${productType.hasStems ? 'Yes' : 'No'}'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlowerTypesTab() {
    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _flowerTypes.length,
        itemBuilder: (context, index) {
          final flowerType = _flowerTypes[index];
          return Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(Icons.local_florist,
                    color: Theme.of(context).colorScheme.primary),
              ),
              title: Text(
                flowerType.flowerName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (flowerType.description.isNotEmpty)
                    Text(flowerType.description),
                  Text('ID: ${flowerType.id}'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBoxesProductsTab() {
    final allBoxes = _shipmentBoxes.values.expand((boxes) => boxes).toList();
    final allProducts =
        _boxProducts.values.expand((products) => products).toList();

    return RefreshIndicator(
      onRefresh: _loadAllData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.inventory_2,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Total Boxes: ${allBoxes.length}'),
                    Text('Total Products: ${allProducts.length}'),
                    Text('Shipments: ${_shipments.length}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'All Boxes:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...allBoxes.map((box) => Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    title: Text('Box ${box.boxNumber}'),
                    subtitle: Text(
                        'Dimensions: ${box.length}x${box.width}x${box.height}'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow('ID', box.id),
                            _buildDetailRow('Shipment ID', box.shipmentId),
                            _buildDetailRow('Length', '${box.length}'),
                            _buildDetailRow('Width', '${box.width}'),
                            _buildDetailRow('Height', '${box.height}'),
                            const SizedBox(height: 12),
                            const Text(
                              'Products:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ...(_boxProducts[box.id] ?? [])
                                .map((product) => Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.description,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          Text('Weight: ${product.weight} kg'),
                                          Text('Type: ${product.type}'),
                                          if (product.flowerType.isNotEmpty)
                                            Text(
                                                'Flower Type: ${product.flowerType}'),
                                        ],
                                      ),
                                    )),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}
