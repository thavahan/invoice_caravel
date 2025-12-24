import 'package:flutter/material.dart';
import 'package:invoice_generator/models/box_product.dart';
import 'package:invoice_generator/models/invoice.dart';
import 'package:invoice_generator/models/invoice_item.dart';
import 'package:invoice_generator/models/product.dart';
import 'package:invoice_generator/models/shipment.dart';
import 'package:invoice_generator/services/data_service.dart';
import 'package:invoice_generator/services/pdf_service.dart';
import 'package:logger/logger.dart';

/// Manages the state of the shipment creation process.
///
/// This provider handles the business logic for creating, managing,
/// and saving shipments. It interacts with the [DataService] and
/// [PdfService] to handle data persistence and PDF generation.
class InvoiceProvider with ChangeNotifier {
  late final DataService _dataService;
  final _logger = Logger();
  bool _isDisposed = false;

  /// Creates an instance of [InvoiceProvider].
  ///
  /// An optional [dataService] can be provided for testing purposes.
  InvoiceProvider({DataService? dataService}) {
    _dataService = dataService ?? DataService();
    _initializeDataService();
  }

  /// Initialize the data service
  Future<void> _initializeDataService() async {
    try {
      await _dataService.initialize();

      // Set connectivity change callback to notify listeners
      _dataService.setConnectivityChangeCallback(() {
        notifyListeners();
      });

      _logger.i('Data service initialized');

      // Load initial data WITHOUT auto-sync (sync only happens at login time)
      await loadInitialData(isLoginTime: false);
    } catch (e, s) {
      _logger.e('Failed to initialize data service', e, s);
    }
  }

  List<Item> _items = [];
  List<FlowerType> _flowerTypes = [];
  List<InvoiceItem> _invoiceItems = [];
  List<Shipment> _shipments = [];
  Map<String, dynamic> _masterData = {};
  List<Map<String, dynamic>> _drafts = [];
  String _signUrl = '';
  bool _isLoading = false;
  bool _isSyncing = false;
  String _syncProgress = '';
  String? _error;
  bool _isBusy = false;
  bool _hasPerformedLoginSync = false; // Track if login sync is completed

  /// The list of available items.
  List<Item> get items => _items;

  /// The list of available flower types.
  List<FlowerType> get flowerTypes => _flowerTypes;

  /// The list of shipments.
  List<Shipment> get shipments => _shipments;

  /// The master data.
  Map<String, dynamic> get masterData => _masterData;

  /// The list of drafts.
  List<Map<String, dynamic>> get drafts => _drafts;

  /// For backward compatibility
  List<Item> get products => _items;
  List<FlowerType> get customers => _flowerTypes;

  /// The list of items currently in the invoice.
  List<InvoiceItem> get invoiceItems => _invoiceItems;

  /// The URL for the signature image.
  String get signUrl => _signUrl;

  /// Whether the initial data is being loaded.
  bool get isLoading => _isLoading;

  /// The current error message, if any.
  String? get error => _error;

  /// Whether the provider is busy with a task (e.g., saving an invoice).
  bool get isBusy => _isBusy;

  /// Whether the provider is currently syncing.
  bool get isSyncing => _isSyncing;

  /// Current sync progress message.
  String get syncProgress => _syncProgress;

  /// The currently selected flower type.
  FlowerType? selectedFlowerType;

  /// The currently selected item to be added to the invoice.
  Item? selectedItem;

  /// The current invoice number.
  String invoiceNumber = '';

  /// Clears the current invoice form.
  void clearForm() {
    _invoiceItems.clear();
    invoiceNumber = '';
    notifyListeners();
    _logger.i('Form cleared.');
  }

  /// Create a new shipment using the data service
  Future<void> createShipment(Shipment shipment) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Save shipment to both local database and Firebase
      await _dataService.saveShipment(shipment);
      _shipments.add(shipment);

      // Check save status for user feedback
      final saveStatus = await _dataService.getLastSaveStatus();
      final localSaved = saveStatus['localAvailable'] ?? false;
      final firebaseSaved = saveStatus['firebaseAvailable'] ?? false;

      String statusMessage = 'Shipment created: ${shipment.invoiceNumber}';
      if (localSaved && firebaseSaved) {
        statusMessage += ' (saved to database and cloud)';
      } else if (localSaved) {
        statusMessage += ' (saved to database only - cloud backup unavailable)';
      }

      _logger.i(statusMessage);
    } catch (e, s) {
      _logger.e('Failed to create shipment', e, s);
      _error = 'Failed to create shipment: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create shipment with auto box/product creation
  Future<void> createShipmentWithBoxes(
      Shipment shipment, List<Map<String, dynamic>> boxesData) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Check if shipment already exists (update scenario)
      final existingShipment =
          await _dataService.getShipment(shipment.invoiceNumber);
      final isUpdate = existingShipment != null;

      if (isUpdate) {
        // Delete existing boxes/products before adding new ones
        try {
          await _dataService.deleteAllBoxesForShipment(shipment.invoiceNumber);
        } catch (e) {
          _logger.w('Failed to delete existing boxes during update', e);
          // Don't fail the entire operation, just warn
        }
      } else {}

      // Save shipment first to both local database and Firebase
      await _dataService.saveShipment(shipment);

      // Auto-create boxes and products if provided
      if (boxesData.isNotEmpty) {
        try {
          await _dataService.autoCreateBoxesAndProducts(
            shipment.invoiceNumber,
            boxesData,
          );
          _logger.i(
              'Auto-created ${boxesData.length} boxes for shipment ${shipment.invoiceNumber}');
        } catch (e) {
          _logger.e(
              'Failed to auto-create boxes/products for shipment ${shipment.invoiceNumber}',
              e);
          rethrow;
        }
      }

      // Update or add shipment to the list
      final index = _shipments
          .indexWhere((s) => s.invoiceNumber == shipment.invoiceNumber);
      if (index != -1) {
        _shipments[index] = shipment;
      } else {
        _shipments.add(shipment);
      }

      // Check save status for user feedback
      final saveStatus = await _dataService.getLastSaveStatus();
      final localSaved = saveStatus['localAvailable'] ?? false;
      final firebaseSaved = saveStatus['firebaseAvailable'] ?? false;

      String statusMessage = isUpdate
          ? 'Shipment with boxes updated: ${shipment.invoiceNumber}'
          : 'Shipment with boxes created: ${shipment.invoiceNumber}';
      if (localSaved && firebaseSaved) {
        statusMessage += ' (saved to database and cloud)';
      } else if (localSaved) {
        statusMessage += ' (saved to database only - cloud backup unavailable)';
      }

      _logger.i(statusMessage);
    } catch (e, s) {
      _logger.e('Failed to create shipment with boxes', e, s);
      _error = 'Failed to create shipment: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update an existing shipment using the data service
  Future<void> updateShipment(Shipment shipment) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _dataService.saveShipment(shipment);

      final index = _shipments
          .indexWhere((s) => s.invoiceNumber == shipment.invoiceNumber);
      if (index != -1) {
        _shipments[index] = shipment;
      }

      _logger.i('Shipment updated: ${shipment.invoiceNumber}');
    } catch (e, s) {
      _logger.e('Failed to update shipment', e, s);
      _error = 'Failed to update shipment: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update shipment with boxes/products - SMART DIFF-BASED UPDATE
  Future<void> updateShipmentWithBoxes(
      Shipment shipment, List<Map<String, dynamic>> boxesData) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _logger.i('🔄 Starting update for shipment: ${shipment.invoiceNumber}');
      _logger.i('📦 Form data contains ${boxesData.length} boxes');
      for (var box in boxesData) {
        _logger.i('📦 Box in form: ${box['id']} - ${box['boxNumber']}');
      }

      // Update the shipment record first - FORCE SYNCHRONOUS FIREBASE UPDATE
      await _dataService.forceUpdateShipmentSync(shipment);

      // Get existing boxes for this shipment - FORCE LOCAL ONLY for consistency
      _dataService.forceOfflineMode(true);
      final existingBoxes =
          await _dataService.getBoxesForShipment(shipment.invoiceNumber);
      _dataService.forceOfflineMode(false);

      // Ensure offline mode is fully disabled before proceeding with updates
      await Future.delayed(
          Duration(milliseconds: 100)); // Small delay to ensure state change

      _logger.i(
          '🗄️ Database contains ${existingBoxes.length} boxes for shipment ${shipment.invoiceNumber}');
      for (var box in existingBoxes) {
        _logger.i('🗄️ Box in database: ${box.id} - ${box.boxNumber}');
      }

      // Create maps for efficient lookup
      final existingBoxesMap = {for (var box in existingBoxes) box.id: box};
      final newBoxesMap = {
        for (var box in boxesData) box['id'] as String? ?? '': box
      };

      // Remove empty key if present
      newBoxesMap.remove('');

      _logger.i('🔍 Comparing boxes:');
      _logger.i(
          '🔍 Existing boxes map has ${existingBoxesMap.length} entries: ${existingBoxesMap.keys.toList()}');
      _logger.i(
          '🔍 New boxes map has ${newBoxesMap.length} entries: ${newBoxesMap.keys.toList()}');

      // Categorize boxes: to update, to add, to delete
      final boxesToUpdate = <String>[];
      final boxesToAdd = <Map<String, dynamic>>[];
      final boxesToDelete = <String>[];

      // Check which new boxes exist (update) vs new (add)
      for (var newBox in boxesData) {
        final boxId = newBox['id'] as String?;
        if (boxId != null &&
            boxId.isNotEmpty &&
            existingBoxesMap.containsKey(boxId)) {
          boxesToUpdate.add(boxId);
        } else {
          boxesToAdd.add(newBox);
        }
      }

      // Check which existing boxes should be deleted (not in new data)
      for (var existingBox in existingBoxes) {
        final boxId = existingBox.id;
        if (!newBoxesMap.containsKey(boxId)) {
          _logger.i(
              '📦 Box marked for deletion: $boxId (Box Number: ${existingBox.boxNumber})');
          print(
              '📦 DEBUG: Box $boxId (${existingBox.boxNumber}) will be deleted - not found in new data');
          boxesToDelete.add(boxId);
        }
      }

      // Log the categorization results
      _logger.i(
          'Existing boxes in DB: ${existingBoxes.length}, New boxes from form: ${boxesData.length}');
      _logger.i(
          'Boxes to update: ${boxesToUpdate.length}, to add: ${boxesToAdd.length}, to delete: ${boxesToDelete.length}');

      _logger.i(
          'Starting box operations - to delete: ${boxesToDelete.length}, to add: ${boxesToAdd.length}, to update: ${boxesToUpdate.length}');

      // 1. Update existing boxes
      for (var boxId in boxesToUpdate) {
        final existingBox = existingBoxesMap[boxId]!;
        final newBoxData = newBoxesMap[boxId]!;

        // Update box dimensions if changed
        if (existingBox.length != newBoxData['length'] ||
            existingBox.width != newBoxData['width'] ||
            existingBox.height != newBoxData['height']) {
          await _dataService.updateBox(boxId, {
            'length': newBoxData['length'],
            'width': newBoxData['width'],
            'height': newBoxData['height'],
          });
        }

        // Update products for this box
        await _updateProductsForBox(shipment.invoiceNumber, boxId,
            newBoxData['products'] as List? ?? [], newBoxData);
      }

      // 2. Add new boxes
      for (var newBoxData in boxesToAdd) {
        final boxId =
            await _dataService.saveBox(shipment.invoiceNumber, newBoxData);
        await _dataService.saveProductsForBox(boxId,
            newBoxData['products'] as List? ?? [], shipment.invoiceNumber);
      }

      // 3. Delete removed boxes
      for (var boxId in boxesToDelete) {
        _logger.i('🗑️ Deleting box: $boxId');
        print('🗑️ DEBUG: Deleting box $boxId from database');
        await _dataService.deleteBox(boxId);
        print('🗑️ DEBUG: Box $boxId deleted successfully');
      }

      // Update local shipments list
      final index = _shipments
          .indexWhere((s) => s.invoiceNumber == shipment.invoiceNumber);
      if (index != -1) {
        _shipments[index] = shipment;
      }

      // Reload data to ensure consistency
      await loadInitialData();

      // Check save status for user feedback
      final saveStatus = await _dataService.getLastSaveStatus();
      final localSaved = saveStatus['localAvailable'] ?? false;
      final firebaseSaved = saveStatus['firebaseAvailable'] ?? false;

      // Clean up any orphaned boxes in Firebase
      try {
        print(
            '🧹 PROVIDER: About to call Firebase cleanup for shipment ${shipment.invoiceNumber}');
        await _dataService
            .cleanupOrphanedBoxesInFirebase(shipment.invoiceNumber);
        print(
            '🧹 PROVIDER: Firebase cleanup completed for shipment ${shipment.invoiceNumber}');
      } catch (e) {
        print('❌ PROVIDER: Firebase cleanup failed: $e');
        _logger.w('Failed to cleanup orphaned boxes in Firebase', e);
      }

      String statusMessage = 'Shipment updated: ${shipment.invoiceNumber}';
      if (localSaved && firebaseSaved) {
        statusMessage += ' (saved to database and cloud)';
      } else if (localSaved) {
        statusMessage += ' (saved to database only - cloud backup unavailable)';
      }

      _logger.i(statusMessage);
    } catch (e, s) {
      _logger.e('Failed to update shipment with boxes', e, s);
      _error = 'Failed to update shipment: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update products for a specific box - smart diff-based
  Future<void> _updateProductsForBox(
      String shipmentId, String boxId, List<dynamic> productsData,
      [Map<String, dynamic>? boxData]) async {
    // Ensure the box exists by saving it
    if (boxData != null) {
      await _dataService.saveBox(shipmentId, {
        'id': boxId,
        'box_number': boxData['boxNumber'] ?? boxData['box_number'] ?? 'Box',
        'length': boxData['length'] ?? 0.0,
        'width': boxData['width'] ?? 0.0,
        'height': boxData['height'] ?? 0.0,
      });
    }

    // Get existing products for this box - FORCE LOCAL ONLY for consistency
    _dataService.forceOfflineMode(true);
    final existingProducts =
        await _dataService.getProductsForBox(shipmentId, boxId);
    _dataService.forceOfflineMode(false);
    // Create maps for efficient lookup
    final existingProductsMap = {
      for (var product in existingProducts) product.id: product
    };
    final newProductsMap = {
      for (var product in productsData) product['id'] as String? ?? '': product
    };

    // Remove empty key
    newProductsMap.remove('');

    // Categorize products
    final productsToUpdate = <String>[];
    final productsToAdd = <Map<String, dynamic>>[];
    final productsToDelete = <String>[];

    // Check which new products exist (update) vs new (add)
    for (var newProduct in productsData) {
      final productId = newProduct['id'] as String?;
      if (productId != null &&
          productId.isNotEmpty &&
          existingProductsMap.containsKey(productId)) {
        productsToUpdate.add(productId);
      } else {
        productsToAdd.add(newProduct);
      }
    }

    // Check which existing products should be deleted
    for (var existingProduct in existingProducts) {
      if (!newProductsMap.containsKey(existingProduct.id)) {
        _logger.i(
            '🗑️ Product marked for deletion: ${existingProduct.id} (${existingProduct.description}) from box $boxId');
        print(
            '🗑️ DEBUG: Product ${existingProduct.id} (${existingProduct.description}) will be deleted from box $boxId');
        productsToDelete.add(existingProduct.id);
      }
    }

    _logger.i('Updating products for box $boxId in shipment $shipmentId');
    _logger.i(
        'Existing products in DB: ${existingProducts.length}, New products from form: ${productsData.length}');
    _logger.i(
        'Products to update: ${productsToUpdate.length}, to add: ${productsToAdd.length}, to delete: ${productsToDelete.length}');
    for (var productId in productsToUpdate) {
      final existingProduct = existingProductsMap[productId]!;
      final newProductData = newProductsMap[productId]!;

      // Check if anything changed
      if (existingProduct.type != newProductData['type'] ||
          existingProduct.description != newProductData['description'] ||
          existingProduct.weight != newProductData['weight'] ||
          existingProduct.flowerType != newProductData['flowerType'] ||
          existingProduct.hasStems != newProductData['hasStems'] ||
          existingProduct.approxQuantity != newProductData['approxQuantity']) {
        await _dataService.updateProduct(productId, {
          'type': newProductData['type'],
          'description': newProductData['description'],
          'weight': newProductData['weight'],
          'flower_type': newProductData['flowerType'],
          'has_stems': newProductData['hasStems'],
          'approx_quantity': newProductData['approxQuantity'],
        });
      }
    }

    // Add new products
    for (var newProductData in productsToAdd) {
      final productDataWithShipmentId = {
        ...newProductData,
        'shipmentId': shipmentId,
      };
      await _dataService.saveProduct(boxId, productDataWithShipmentId);
    }

    // Delete removed products
    for (var productId in productsToDelete) {
      _logger.i('🗑️ Deleting product: $productId from box $boxId');
      print('🗑️ DEBUG: Deleting product $productId from box $boxId');
      await _dataService.deleteProduct(productId);
      print('🗑️ DEBUG: Product $productId deleted successfully');
    }
  }

  /// Creates and saves the current invoice to Firestore.
  ///
  /// Returns the created [Invoice] on success, or `null` on failure.
  Future<Invoice?> _createAndSaveInvoice() async {
    if (selectedFlowerType == null ||
        invoiceNumber.isEmpty ||
        _invoiceItems.isEmpty) {
      _error = 'Please fill all fields and add at least one item.';
      notifyListeners();
      return null;
    }

    _isBusy = true;
    _error = null;
    notifyListeners();

    // Create a temporary shipment for the invoice
    final tempShipment = Shipment(
      invoiceNumber: invoiceNumber,
      shipper: 'Default Shipper',
      consignee: selectedFlowerType!.flowerName,
      awb: invoiceNumber,
      flightNo: 'TBD',
      flightDate: DateTime.now(), // Add required flightDate
      dischargeAirport: 'TBD',
      eta: DateTime.now().add(Duration(days: 1)),
      grossWeight: total,
      invoiceTitle: 'Invoice $invoiceNumber',
      boxIds: [],
    );

    final invoice = Invoice(
      invoiceNumber: invoiceNumber,
      shipment: tempShipment,
      date: DateTime.now(),
      items: _invoiceItems.map((ii) => ii.item).toList(),
      signUrl: _signUrl,
    );

    try {
      await _dataService.saveShipment(invoice.shipment);
      _isBusy = false;
      notifyListeners();
      return invoice;
    } catch (e, s) {
      _logger.e('Failed to save invoice', e, s);
      _error = 'Failed to save invoice. Please try again.';
      _isBusy = false;
      notifyListeners();
      return null;
    }
  }

  /// Generates a preview of the current invoice.
  Future<void> previewInvoice() async {
    final invoice = await _createAndSaveInvoice();
    if (invoice != null) {
      try {
        final pdfService = PdfService();
        // Get master product types for Table 3
        final masterProductTypes = await _dataService.getMasterProductTypes();
        await pdfService.generateShipmentPDF(
            invoice.shipment, invoice.items, masterProductTypes);
        _logger.i('Invoice ${invoice.invoiceNumber} previewed successfully.');
      } catch (e, s) {
        _logger.e('Failed to preview invoice', e, s);
        _error = 'Failed to generate PDF. Please try again.';
        notifyListeners();
      }
    }
  }

  /// Generates a preview of the invoice with provided shipment data.
  Future<void> previewInvoiceWithData(Map<String, dynamic> shipmentData) async {
    try {
      // Create shipment from the provided data
      final shipment = Shipment(
        invoiceNumber: shipmentData['invoiceNumber'] ?? '',
        shipper: shipmentData['shipper'] ?? '',
        shipperAddress: shipmentData['shipperAddress'] ?? '',
        consignee: shipmentData['consignee'] ?? '',
        consigneeAddress: shipmentData['consigneeAddress'] ?? '',
        clientRef: shipmentData['clientRef'] ?? '',
        awb: shipmentData['awb'] ?? '',
        masterAwb: shipmentData['masterAwb'] ?? '',
        houseAwb: shipmentData['houseAwb'] ?? '',
        flightNo: shipmentData['flightNo'] ?? '',
        flightDate: shipmentData['flightDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(shipmentData['flightDate'])
            : DateTime.now(),
        dischargeAirport: shipmentData['dischargeAirport'] ?? '',
        origin: shipmentData['origin'] ?? '',
        destination: shipmentData['destination'] ?? '',
        eta: shipmentData['eta'] != null
            ? DateTime.tryParse(shipmentData['eta']) ??
                DateTime.now().add(Duration(days: 1))
            : DateTime.now().add(Duration(days: 1)),
        invoiceDate: shipmentData['invoiceDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(shipmentData['invoiceDate'])
            : null,
        dateOfIssue: shipmentData['dateOfIssue'] != null
            ? DateTime.fromMillisecondsSinceEpoch(shipmentData['dateOfIssue'])
            : null,
        placeOfReceipt: shipmentData['placeOfReceipt'] ?? '',
        sgstNo: shipmentData['sgstNo'] ?? '',
        iecCode: shipmentData['iecCode'] ?? '',
        freightTerms: shipmentData['freightTerms'] ?? '',
        grossWeight: double.tryParse(shipmentData['grossWeight'] ?? '0') ?? 0.0,
        invoiceTitle: shipmentData['invoiceTitle'] ?? '',
        status: shipmentData['status'] ?? 'pending',
        boxIds: [], // Will be populated from boxes
      );

      // Convert boxes data to ShipmentBox objects
      final boxes =
          (shipmentData['boxes'] as List<dynamic>? ?? []).map((boxData) {
        final products =
            (boxData['products'] as List<dynamic>? ?? []).map((productData) {
          return ShipmentProduct(
            id: productData['id'] ?? '',
            boxId: '', // Will be set when box is created
            type: productData['type'] ?? '',
            description: productData['description'] ?? '',
            flowerType: productData['flowerType'] ?? 'LOOSE FLOWERS',
            hasStems: productData['hasStems'] ?? false,
            weight: (productData['weight'] ?? 0.0).toDouble(),
            rate: (productData['rate'] ?? 0.0).toDouble(),
            approxQuantity: productData['approxQuantity'] ?? 0,
          );
        }).toList();

        return ShipmentBox(
          id: boxData['id'] ?? '',
          shipmentId: shipment.invoiceNumber,
          boxNumber: boxData['boxNumber'] ?? '',
          length: (boxData['length'] ?? 0.0).toDouble(),
          width: (boxData['width'] ?? 0.0).toDouble(),
          height: (boxData['height'] ?? 0.0).toDouble(),
          products: products,
        );
      }).toList();

      // Create invoice items from boxes
      final invoiceItems = boxes
          .expand((box) => box.products.map((product) => InvoiceItem(
                item: Item(
                  id: product.id,
                  flowerTypeId: product.flowerType,
                  weightKg: product.weight,
                  form: product.type,
                  quantity: product.approxQuantity,
                  rate: product.rate,
                ),
                quantity: 1,
              )))
          .toList();

      final invoice = Invoice(
        invoiceNumber: shipment.invoiceNumber,
        shipment: shipment,
        date: DateTime.now(),
        items: invoiceItems.map((ii) => ii.item).toList(),
        signUrl: _signUrl,
      );

      final pdfService = PdfService();
      // Get master product types for Table 3
      final masterProductTypes = await _dataService.getMasterProductTypes();
      await pdfService.generateShipmentPDF(
          invoice.shipment, invoice.items, masterProductTypes);
      _logger.i(
          'Invoice ${invoice.invoiceNumber} previewed successfully with ${boxes.length} boxes.');
    } catch (e, s) {
      _logger.e('Failed to preview invoice with data', e, s);
      _error = 'Failed to generate PDF. Please try again.';
      notifyListeners();
    }
  }

  /// Shares the current invoice as a PDF.
  Future<void> shareInvoice() async {
    final invoice = await _createAndSaveInvoice();
    if (invoice != null) {
      try {
        final pdfService = PdfService();
        // Get master product types for Table 3
        final masterProductTypes = await _dataService.getMasterProductTypes();
        await pdfService.generateShipmentPDF(
            invoice.shipment, invoice.items, masterProductTypes);
        _logger.i('Invoice ${invoice.invoiceNumber} shared successfully.');
      } catch (e, s) {
        _logger.e('Failed to share invoice', e, s);
        _error = 'Failed to share PDF. Please try again.';
        notifyListeners();
      }
    }
  }

  /// Manually trigger sync from Firebase to local database
  Future<void> syncFromCloud() async {
    try {
      _isSyncing = true;
      _syncProgress = 'Starting sync...';
      _error = null;
      notifyListeners();

      await _dataService.syncFromFirebaseToLocal(
        onProgress: (progress) {
          _syncProgress = progress;
          notifyListeners();
        },
      );

      // Reload data after sync
      await loadInitialData();

      _syncProgress = 'Sync completed successfully!';
      _logger.i('Manual sync from Firebase completed successfully');

      // Clear progress after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        _syncProgress = '';
        _isSyncing = false;
        notifyListeners();
      });
    } catch (e, s) {
      _logger.e('Failed to sync from Firebase', e, s);
      _error = 'Sync failed: ${e.toString()}';
      _syncProgress = 'Sync failed';
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Load initial data from the data service
  /// Auto-sync only happens at login time, not during normal app usage
  Future<void> loadInitialData({bool isLoginTime = false}) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Initialize user collections only if using Firebase
      try {
        await _dataService.initializeUserCollections();
        _logger.i('User collections checked for initialization');
      } catch (e) {
        _logger.w(
            'Failed to check user collections, continuing with local data', e);
      }

      // DISABLED: Automatic migration during app startup - too risky, use manual migration instead
      // try {
      //   await migrateExistingDataToFirebase();
      // } catch (e) {
      //   _logger.w('Automatic migration failed, will try manual migration later', e);
      //   // Don't fail the entire app startup if migration fails
      // }

      // Auto-sync from Firebase ONLY at login time or if explicitly requested
      if (isLoginTime || !_hasPerformedLoginSync) {
        _logger.i(
            '🔄 LOAD-DATA: Login-time sync condition met (isLoginTime: $isLoginTime, _hasPerformedLoginSync: $_hasPerformedLoginSync)');
        try {
          final localShipments = await _dataService.getShipments();
          _logger.i(
              '📄 LOAD-DATA: Current local database has ${localShipments.length} shipments');

          // Check if Firebase is available and sync from Firebase to local
          final dataSourceInfo = await _dataService.getDataSourceInfo();
          final isOnline = dataSourceInfo['isOnline'] ?? false;
          final currentUserId = dataSourceInfo['currentUserId'];

          _logger.i(
              '🔄 LOAD-DATA: Data source info - isOnline: $isOnline, currentUserId: $currentUserId');

          if (isOnline && currentUserId != null) {
            _logger.i(
                '📥 LOAD-DATA: Login-time auto-sync - syncing latest data from Firebase...');

            try {
              await _dataService.syncFromFirebaseToLocal(
                onProgress: (progress) {
                  _logger.i('📥 LOAD-DATA: Login sync progress: $progress');
                },
              );

              _logger.i(
                  '✅ LOAD-DATA: Login-time sync from Firebase completed successfully');
              _hasPerformedLoginSync = true;

              // Verify sync worked and show updated count
              final updatedShipments = await _dataService.getShipments();
              _logger.i(
                  '📊 LOAD-DATA: After login sync: Found ${updatedShipments.length} shipments in local database');
            } catch (syncError) {
              _logger.e(
                  '❌ LOAD-DATA: Login-time sync from Firebase failed, using existing local data',
                  syncError);
              // Don't block app startup if sync fails, continue with local data
            }
          } else {
            if (currentUserId == null) {
              _logger
                  .i('📶 LOAD-DATA: Not authenticated - using local data only');
            } else {
              _logger.i('📶 LOAD-DATA: Offline - using local data only');
            }
          }
        } catch (e) {
          _logger.e(
              '❌ LOAD-DATA: Failed to perform login-time sync check, continuing with local data',
              e);
        }
      } else {
        _logger.i(
            '🔄 LOAD-DATA: Normal app startup - skipping auto-sync (already performed at login)');
      }

      // Load shipments (after potential sync) - FORCE LOCAL ONLY
      _dataService.forceOfflineMode(true);
      final shipments = await _dataService.getShipments();
      _dataService.forceOfflineMode(false);
      _shipments = shipments;

      // Load master data - FORCE LOCAL ONLY
      _dataService.forceOfflineMode(true);
      final masterShippers = await _dataService.getMasterShippers();
      final masterConsignees = await _dataService.getMasterConsignees();
      final masterProductTypes = await _dataService.getMasterProductTypes();
      final flowerTypes = await _dataService.getFlowerTypes();
      _dataService.forceOfflineMode(false);

      _masterData = {
        'shippers': masterShippers,
        'consignees': masterConsignees,
        'productTypes': masterProductTypes,
        'flowerTypes': flowerTypes,
      };

      // Load drafts - FORCE LOCAL ONLY
      _dataService.forceOfflineMode(true);
      final drafts = await _dataService.getDrafts();
      _dataService.forceOfflineMode(false);
      _drafts = drafts;

      _logger.i(
          'Initial data loaded: ${shipments.length} shipments, ${drafts.length} drafts');
    } catch (e, s) {
      _logger.e('Failed to load initial data', e, s);
      _error = 'Failed to load data: $e';

      // Ensure we have empty but valid data structures even on error
      _shipments = [];
      _masterData = {
        'shippers': [],
        'consignees': [],
        'productTypes': [],
        'flowerTypes': [],
      };
      _drafts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get data service instance
  DataService get dataService => _dataService;

  /// Migrate existing local data to Firebase (public method for manual migration)
  Future<void> migrateExistingDataToFirebase() async {
    _logger.i(
        '🔄 PROVIDER MIGRATION: Starting manual data migration to Firebase...');
    try {
      // Check connectivity first
      final connectivityInfo = await _dataService.getDataSourceInfo();
      final isOffline = !(connectivityInfo['isOnline'] ?? false);
      final forceOffline = connectivityInfo['forceOffline'] ?? false;

      if (isOffline || forceOffline) {
        throw Exception(
            'Cannot migrate data while offline. Please check your internet connection and try again.');
      }

      // Check if user has already been migrated
      _logger.i('🔄 PROVIDER MIGRATION: Checking if already migrated...');
      final hasMigrated =
          await _dataService.getSetting('dataMigrated') == 'true';
      _logger.i('🔄 PROVIDER MIGRATION: Has migrated: $hasMigrated');

      if (hasMigrated) {
        _logger.i('🔄 PROVIDER MIGRATION: Data already migrated to Firebase');
        return;
      }

      // Check if user has existing local data by temporarily forcing offline mode
      _logger.i('🔄 PROVIDER MIGRATION: Checking for local data...');
      _dataService.forceOfflineMode(true);
      final localShipments = await _dataService.getShipments();
      _dataService.forceOfflineMode(false);
      _logger.i(
          '🔄 PROVIDER MIGRATION: Found ${localShipments.length} local shipments');

      final hasLocalData = localShipments.isNotEmpty;

      if (!hasLocalData) {
        _logger.i('🔄 PROVIDER MIGRATION: No local data to migrate');
        await _dataService.setSetting('dataMigrated', 'true');
        return;
      }

      _logger.i(
          '🔄 PROVIDER MIGRATION: Migrating ${localShipments.length} existing shipments to Firebase...');

      // Force online mode temporarily to ensure migration to Firebase
      _logger.i('🔄 PROVIDER MIGRATION: Forcing online mode...');
      _dataService.forceOfflineMode(false);

      // Verify user is authenticated before proceeding
      _logger.i(
          '🔄 PROVIDER MIGRATION: Checking authentication and connectivity...');
      final dataSourceInfo = await _dataService.getDataSourceInfo();
      _logger.i('🔄 PROVIDER MIGRATION: Data source info: $dataSourceInfo');

      if (dataSourceInfo['currentUserId'] == null) {
        throw Exception('User not authenticated. Please log in again.');
      }

      if (!(dataSourceInfo['isOnline'] ?? false)) {
        throw Exception(
            'No internet connection. Please check your connection and try again.');
      }

      _logger.i('🔄 PROVIDER MIGRATION: Starting sync to Firebase...');
      // Use the sync method to migrate data
      await _dataService.syncToFirebase();

      _logger.i('🔄 PROVIDER MIGRATION: Marking migration as complete...');
      // Mark migration as complete
      await _dataService.setSetting('dataMigrated', 'true');
      _logger.i(
          '🔄 PROVIDER MIGRATION: Data migration to Firebase completed successfully');
    } catch (e, s) {
      _logger.e('🔄 PROVIDER MIGRATION: Failed to migrate existing data', e, s);
      // Re-throw the exception with a more user-friendly message
      if (e.toString().contains('permission-denied')) {
        throw Exception(
            'Permission denied. Please check your Firebase security rules.');
      } else if (e.toString().contains('unavailable')) {
        throw Exception(
            'Firebase service is currently unavailable. Please try again later.');
      } else if (e.toString().contains('User not authenticated')) {
        throw Exception(
            'Authentication required. Please log out and log back in.');
      } else {
        throw Exception('Migration failed: ${e.toString()}');
      }
    }
  }

  /// Sets the selected flower type.
  void selectFlowerType(FlowerType? flowerType) {
    selectedFlowerType = flowerType;
    notifyListeners();
  }

  /// Sets the selected item.
  void selectItem(Item? item) {
    selectedItem = item;
    notifyListeners();
  }

  /// For backward compatibility
  void selectCustomer(FlowerType? flowerType) => selectFlowerType(flowerType);
  void selectProduct(Item? item) => selectItem(item);

  /// Sets the invoice number.
  void setInvoiceNumber(String number) {
    invoiceNumber = number;
  }

  /// Adds an item to the current invoice.
  void addItem(int quantity, int bonus) {
    if (selectedItem != null) {
      _invoiceItems.add(InvoiceItem(
        item: selectedItem!,
        quantity: quantity,
        bonus: bonus,
      ));
      notifyListeners();
      _logger.i('Added item: ${selectedItem!.form}');
    }
  }

  /// Removes an item from the current invoice.
  void removeItem(int index) {
    if (index >= 0 && index < _invoiceItems.length) {
      final item = _invoiceItems[index];
      _invoiceItems.removeAt(index);
      notifyListeners();
      _logger.i('Removed item: ${item.product.name}');
    }
  }

  /// The subtotal of the invoice (before tax).
  double get subtotal {
    return _invoiceItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  /// The tax amount of the invoice.
  double get tax => subtotal * 0.15;

  /// Get data source information
  Future<Map<String, dynamic>> getDataSourceInfo() async {
    return await _dataService.getDataSourceInfo();
  }

  /// Sync data to Firebase
  Future<void> syncToFirebase() async {
    final dataSourceInfo = await _dataService.getDataSourceInfo();
    final isOffline = !(dataSourceInfo['isOnline'] ?? false);
    final forceOffline = dataSourceInfo['forceOffline'] ?? false;

    if (isOffline || forceOffline) {
      throw Exception(
          'Cannot sync to Firebase while offline. Please check your internet connection and try again.');
    }

    await _dataService.syncToFirebase();
  }

  /// Sync data from Firebase to local
  Future<void> syncFromFirebase() async {
    final dataSourceInfo = await _dataService.getDataSourceInfo();
    final isOffline = !(dataSourceInfo['isOnline'] ?? false);
    final forceOffline = dataSourceInfo['forceOffline'] ?? false;

    if (isOffline || forceOffline) {
      throw Exception(
          'Cannot sync from Firebase while offline. Please check your internet connection and try again.');
    }

    await _dataService.syncFromFirebase();
  }

  /// Check migration status
  Future<Map<String, dynamic>> getMigrationStatus() async {
    try {
      final hasMigrated =
          await _dataService.getSetting('dataMigrated') == 'true';

      // Check local data count
      _dataService.forceOfflineMode(true);
      final localShipments = await _dataService.getShipments();
      final localShippers = await _dataService.getMasterShippers();
      final localConsignees = await _dataService.getMasterConsignees();
      final localProductTypes = await _dataService.getMasterProductTypes();
      final localFlowerTypes = await _dataService.getFlowerTypes();
      _dataService.forceOfflineMode(false);

      // Check Firebase data count (if online)
      List<Shipment> firebaseShipments = [];
      List<dynamic> firebaseShippers = [];
      List<dynamic> firebaseConsignees = [];
      List<dynamic> firebaseProductTypes = [];
      List<dynamic> firebaseFlowerTypes = [];
      try {
        final dataSourceInfo = await _dataService.getDataSourceInfo();
        if (dataSourceInfo['isOnline'] == true) {
          firebaseShipments = await _dataService.getShipments();
          firebaseShippers = await _dataService.getMasterShippers();
          firebaseConsignees = await _dataService.getMasterConsignees();
          firebaseProductTypes = await _dataService.getMasterProductTypes();
          firebaseFlowerTypes = await _dataService.getFlowerTypes();
        }
      } catch (e) {
        _logger.w('Could not check Firebase data count', e);
      }

      return {
        'hasMigrated': hasMigrated,
        'localShipmentsCount': localShipments.length,
        'firebaseShipmentsCount': firebaseShipments.length,
        'localShippersCount': localShippers.length,
        'firebaseShippersCount': firebaseShippers.length,
        'localConsigneesCount': localConsignees.length,
        'firebaseConsigneesCount': firebaseConsignees.length,
        'localProductTypesCount': localProductTypes.length,
        'firebaseProductTypesCount': firebaseProductTypes.length,
        'localFlowerTypesCount': localFlowerTypes.length,
        'firebaseFlowerTypesCount': firebaseFlowerTypes.length,
        'needsMigration': !hasMigrated && localShipments.isNotEmpty,
      };
    } catch (e) {
      _logger.e('Failed to get migration status', e);
      return {
        'hasMigrated': false,
        'localShipmentsCount': 0,
        'firebaseShipmentsCount': 0,
        'localShippersCount': 0,
        'firebaseShippersCount': 0,
        'localConsigneesCount': 0,
        'firebaseConsigneesCount': 0,
        'localProductTypesCount': 0,
        'firebaseProductTypesCount': 0,
        'localFlowerTypesCount': 0,
        'firebaseFlowerTypesCount': 0,
        'needsMigration': false,
        'error': e.toString(),
      };
    }
  }

  /// Trigger login-time auto-sync
  /// This should be called when user successfully logs in
  Future<void> performLoginTimeSync() async {
    _logger.i('🔐 LOGIN-SYNC: Performing login-time auto-sync...');
    _logger.i(
        '🔐 LOGIN-SYNC: Current _hasPerformedLoginSync flag: $_hasPerformedLoginSync');
    _hasPerformedLoginSync = false; // Reset flag to allow sync
    _logger.i(
        '🔐 LOGIN-SYNC: Reset _hasPerformedLoginSync to false, calling loadInitialData(isLoginTime: true)');
    await loadInitialData(isLoginTime: true);
    _logger.i('🔐 LOGIN-SYNC: loadInitialData completed');
  }

  /// Reset login sync flag
  /// This should be called when user logs out
  void resetLoginSyncFlag() {
    _logger.i('🔓 Resetting login sync flag - will auto-sync on next login');
    _hasPerformedLoginSync = false;
    notifyListeners();
  }

  /// Check if login-time sync has been performed
  bool get hasPerformedLoginSync => _hasPerformedLoginSync;

  /// Force enable auto-sync for next app startup (useful for testing)
  void enableAutoSyncForNextStartup() {
    _logger.i('🔄 Enabling auto-sync for next app startup');
    _hasPerformedLoginSync = false;
    notifyListeners();
  }

  /// The total amount of the invoice (including tax).
  double get total => subtotal + tax;

  /// Override notifyListeners to prevent notifications after disposal
  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  /// Dispose method to mark the provider as disposed
  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
