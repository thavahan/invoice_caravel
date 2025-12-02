import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:invoice_generator/services/firebase_service.dart';
import 'package:invoice_generator/services/local_database_service.dart';
import 'package:invoice_generator/models/shipment.dart';
import 'package:invoice_generator/models/box_product.dart';
import 'package:invoice_generator/models/master_shipper.dart';
import 'package:invoice_generator/models/master_consignee.dart';
import 'package:invoice_generator/models/master_product_type.dart';
import 'package:invoice_generator/models/product.dart';
import 'package:logger/logger.dart';

/// Hybrid data service that can use both Firebase and SQLite
/// Automatically switches based on connectivity and user preferences
class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final LocalDatabaseService _localService = LocalDatabaseService();
  final Connectivity _connectivity = Connectivity();
  final _logger = Logger();

  // Configuration
  bool _preferFirebase = true; // Default to Firebase when online
  bool _forceOffline = false; // Force offline mode

  // Connectivity change callback
  Function()? _onConnectivityChangedCallback;

  /// Initialize both services with better error handling
  Future<void> initialize() async {
    try {
      _logger.i('Initializing data services...');

      // Always initialize local service first (it's reliable)
      await _localService.initialize();
      _logger.i('Local database service initialized successfully');

      // Try to initialize Firebase service with timeout and error handling
      try {
        await _firebaseService.initialize().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            _logger.w(
                'Firebase initialization timed out, continuing with local only');
            _forceOffline = true;
          },
        );
        _logger.i('Firebase service initialized successfully');
      } catch (e) {
        _logger
            .w('Firebase initialization failed, using local database only: $e');
        _forceOffline = true;
        // Don't rethrow - continue with local database
      }

      // Listen to connectivity changes
      _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

      _logger.i('DataService initialized successfully');
    } catch (e, s) {
      _logger.e('Failed to initialize DataService', e, s);
      // Always ensure local service is available
      try {
        await _localService.initialize();
        _forceOffline = true;
        _logger.i('Fallback to local database only');
      } catch (localError) {
        _logger.e(
            'Critical: Failed to initialize even local database', localError);
        rethrow;
      }
    }
  }

  /// Initialize user collections in Firebase (creates them if they don't exist)
  Future<void> initializeUserCollections() async {
    try {
      // Check if we should even attempt Firebase operations
      if (!await _shouldUseFirebase()) {
        _logger.i('Skipping user collections initialization - offline mode');
        return;
      }

      await _firebaseService.initializeUserCollections();
      _logger.i('User collections initialized in Firebase');
    } catch (e) {
      _logger.w('Failed to initialize user collections in Firebase: $e');

      // If it's a connectivity issue, force offline mode
      if (e.toString().contains('network') ||
          e.toString().contains('connectivity') ||
          e.toString().contains('timeout') ||
          e.toString().contains('Unable to resolve host')) {
        _logger.i('Network issue detected, switching to offline mode');
        _forceOffline = true;
      }

      // Don't rethrow - allow app to continue with local database
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isOnline = results.isNotEmpty &&
        results.any((result) => result != ConnectivityResult.none);
    _logger.i('Connectivity changed: ${isOnline ? 'online' : 'offline'}');

    // Notify listeners about connectivity change
    _onConnectivityChangedCallback?.call();

    // Could trigger sync operations here if needed
  }

  /// Set connectivity change callback
  void setConnectivityChangeCallback(Function() callback) {
    _onConnectivityChangedCallback = callback;
  }

  /// Check if we should use Firebase
  Future<bool> _shouldUseFirebase() async {
    if (_forceOffline) return false;

    try {
      // First check if Firebase is initialized (without circular dependency)
      if (!_firebaseService.isInitialized) {
        return false;
      }

      final results = await _connectivity.checkConnectivity();
      final isOnline = results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none);
      return isOnline && _preferFirebase;
    } catch (e) {
      _logger.w('Failed to check connectivity, defaulting to offline', e);
      return false;
    }
  }

  /// Check if Firebase is available for operations
  Future<bool> _isFirebaseAvailable() async {
    try {
      // Simple Firebase availability check without circular dependency
      return !_forceOffline && _firebaseService.isInitialized;
    } catch (e) {
      _logger.w('Firebase availability check failed: $e');
      return false;
    }
  }

  /// Check if local database is empty (new device scenario)
  Future<bool> _isLocalDatabaseEmpty() async {
    try {
      final shipments = await _localService.getShipments(limit: 1);
      final masterShippers = await _localService.getMasterShippers();

      // Consider database empty if no shipments and no master data
      return shipments.isEmpty && masterShippers.isEmpty;
    } catch (e) {
      _logger.w('Failed to check if local database is empty: $e');
      return true; // Assume empty if we can't check
    }
  }

  /// Force sync master data from Firebase to local (updates existing records)
  Future<void> forceSyncMasterDataFromFirebase() async {
    try {
      // Force sync product types from Firebase to local
      final firebaseProductTypes =
          await _firebaseService.getMasterProductTypes();
      final localProductTypes = await _localService.getMasterProductTypes();

      // Create map for efficient lookup
      final localProductTypesMap =
          Map.fromEntries(localProductTypes.map((p) => MapEntry(p.id, p)));

      int updated = 0;
      int added = 0;

      for (final firebaseProductType in firebaseProductTypes) {
        final existingLocal = localProductTypesMap[firebaseProductType.id];

        if (existingLocal == null) {
          // Add new product type
          await _localService.saveMasterProductType(firebaseProductType);
          added++;
        } else {
          // Force update existing product type with Firebase data
          final updateData = {
            'name': firebaseProductType.name,
            'approx_quantity':
                firebaseProductType.approxQuantity, // Use correct field name
          };
          await _localService.updateMasterProductType(
              firebaseProductType.id, updateData);
          updated++;
        }
      }

      _logger.i('Force sync completed: $added added, $updated updated');
    } catch (e, s) {
      _logger.e('Force sync master data failed', e, s);
      throw Exception('Failed to force sync master data: $e');
    }
  }

  /// Perform initial sync from Firebase to local database (new device scenario)
  Future<void> syncFromFirebaseToLocal({Function(String)? onProgress}) async {
    try {
      if (!(await _isFirebaseAvailable())) {
        _logger.w('Firebase not available for sync');
        return;
      }

      _logger.i('Starting initial sync from Firebase to local database...');
      onProgress?.call('Syncing master data...');

      // Sync master data first
      await _syncMasterDataFromFirebase(onProgress);

      onProgress?.call('Syncing shipments...');

      // Sync shipments
      await _syncShipmentsFromFirebase(onProgress);

      onProgress?.call('Syncing boxes and products...');

      // Sync boxes and products for all shipments using the dedicated method
      // This ensures we iterate over local shipments and import boxes/products
      // instead of referencing transient variables (boxesData / _dataService)
      await _syncBoxesAndProductsFromFirebase(onProgress);

      onProgress?.call('Syncing drafts...');

      // Sync drafts
      await _syncDraftsFromFirebase(onProgress);

      onProgress?.call('Sync completed!');
      _logger.i(
          'Initial sync from Firebase to local database completed successfully');
    } catch (e, s) {
      _logger.e('Failed to sync from Firebase to local database', e, s);
      onProgress?.call('Sync failed: ${e.toString()}');
      throw Exception('Failed to sync data from cloud: ${e.toString()}');
    }
  }

  /// Sync master data from Firebase to local with UPDATE support for existing records
  Future<void> _syncMasterDataFromFirebase(Function(String)? onProgress) async {
    try {
      // Sync shippers
      onProgress?.call('Syncing shippers...');
      final firebaseShippers = await _firebaseService.getMasterShippers();
      final localShippers = await _localService.getMasterShippers();
      final existingShipperIds = localShippers.map((s) => s.id).toSet();

      int shippersSynced = 0;
      for (final shipper in firebaseShippers) {
        try {
          if (!existingShipperIds.contains(shipper.id)) {
            await _localService.saveMasterShipper(shipper);
            shippersSynced++;
          }
        } catch (e) {
          _logger.w('Failed to sync shipper ${shipper.id}: $e');
        }
      }
      _logger.i('Synced $shippersSynced new shippers');

      // Sync consignees
      onProgress?.call('Syncing consignees...');
      final firebaseConsignees = await _firebaseService.getMasterConsignees();
      final localConsignees = await _localService.getMasterConsignees();
      final existingConsigneeIds = localConsignees.map((c) => c.id).toSet();

      int consigneesSynced = 0;
      for (final consignee in firebaseConsignees) {
        try {
          if (!existingConsigneeIds.contains(consignee.id)) {
            await _localService.saveMasterConsignee(consignee);
            consigneesSynced++;
          }
        } catch (e) {
          _logger.w('Failed to sync consignee ${consignee.id}: $e');
        }
      }
      _logger.i('Synced $consigneesSynced new consignees');

      // Sync product types - WITH UPDATE SUPPORT for existing records
      onProgress?.call('Syncing product types...');
      final firebaseProductTypes =
          await _firebaseService.getMasterProductTypes();
      final localProductTypes = await _localService.getMasterProductTypes();

      // Create maps for efficient lookup
      final existingProductTypes =
          Map.fromEntries(localProductTypes.map((p) => MapEntry(p.id, p)));

      int productTypesAdded = 0;
      int productTypesUpdated = 0;

      for (final firebaseProductType in firebaseProductTypes) {
        try {
          final existingLocal = existingProductTypes[firebaseProductType.id];

          if (existingLocal == null) {
            // New product type - add it
            await _localService.saveMasterProductType(firebaseProductType);
            productTypesAdded++;
          } else {
            // Existing product type - check if update needed
            if (existingLocal.name != firebaseProductType.name ||
                existingLocal.approxQuantity !=
                    firebaseProductType.approxQuantity) {
              final updateData = {
                'name': firebaseProductType.name,
                'approx_quantity': firebaseProductType
                    .approxQuantity, // Use correct field name
              };
              await _localService.updateMasterProductType(
                  firebaseProductType.id, updateData);
              productTypesUpdated++;
              print(
                  '🔄 SYNC: Updated product type: ${firebaseProductType.name} (qty: ${existingLocal.approxQuantity} → ${firebaseProductType.approxQuantity})');
            }
          }
        } catch (e) {
          _logger
              .w('Failed to sync product type ${firebaseProductType.id}: $e');
        }
      }

      _logger.i(
          'Product types sync: $productTypesAdded added, $productTypesUpdated updated');
      print(
          '✅ SYNC: Product types sync completed: $productTypesAdded added, $productTypesUpdated updated');

      // Sync flower types as part of master data
      onProgress?.call('Syncing flower types...');
      final firebaseFlowerTypes = await _firebaseService.getFlowerTypes();
      final localFlowerTypes = await _localService.getFlowerTypes();
      final existingFlowerTypes =
          Map.fromEntries(localFlowerTypes.map((f) => MapEntry(f.id, f)));

      int flowerTypesAdded = 0;
      int flowerTypesUpdated = 0;

      for (final firebaseFlowerType in firebaseFlowerTypes) {
        try {
          final existingLocal = existingFlowerTypes[firebaseFlowerType.id];

          if (existingLocal == null) {
            await _localService.saveFlowerType(firebaseFlowerType);
            flowerTypesAdded++;
          } else {
            if (existingLocal.flowerName != firebaseFlowerType.flowerName ||
                existingLocal.description != firebaseFlowerType.description) {
              final updateData = {
                'flower_name': firebaseFlowerType.flowerName,
                'description': firebaseFlowerType.description,
              };
              await _localService.updateFlowerType(
                  firebaseFlowerType.id, updateData);
              flowerTypesUpdated++;
            }
          }
        } catch (e) {
          _logger.w('Failed to sync flower type ${firebaseFlowerType.id}: $e');
        }
      }

      _logger.i(
          'Flower types sync: $flowerTypesAdded added, $flowerTypesUpdated updated');

      _logger.i('Master data synced successfully');
    } catch (e) {
      _logger.e('Failed to sync master data from Firebase: $e');
      throw e;
    }
  }

  /// Sync shipments from Firebase to local with duplicate prevention
  Future<void> _syncShipmentsFromFirebase(Function(String)? onProgress) async {
    try {
      final firebaseShipments = await _firebaseService.getShipments(limit: 100);

      // Get existing local shipments to prevent duplicates
      final localShipments = await _localService.getShipments();
      final existingInvoiceNumbers =
          localShipments.map((s) => s.invoiceNumber).toSet();

      int synced = 0;
      int skipped = 0;

      for (final shipment in firebaseShipments) {
        try {
          // Check for duplicate before saving
          if (existingInvoiceNumbers.contains(shipment.invoiceNumber)) {
            skipped++;
            _logger.d('Skipping duplicate shipment: ${shipment.invoiceNumber}');
            continue;
          }

          // Skip invalid shipments (e.g., placeholders with empty required fields)
          if (shipment.invoiceNumber.startsWith('_placeholder') ||
              shipment.awb.isEmpty ||
              shipment.invoiceNumber.isEmpty) {
            skipped++;
            _logger.d(
                'Skipping invalid/placeholder shipment: ${shipment.invoiceNumber}');
            continue;
          }

          await _localService.saveShipment(shipment);
          synced++;
          if (synced % 10 == 0) {
            onProgress?.call(
                'Synced $synced/${firebaseShipments.length} shipments (${skipped} duplicates skipped)...');
          }
        } catch (e) {
          _logger.w('Failed to sync shipment ${shipment.invoiceNumber}: $e');
          skipped++;
        }
      }

      _logger.i(
          'Shipments sync completed: $synced new, $skipped duplicates skipped');

      _logger.i('Synced $synced shipments from Firebase');
    } catch (e) {
      _logger.e('Failed to sync shipments from Firebase: $e');
      throw e;
    }
  }

  /// Sync boxes and products from Firebase to local database
  Future<void> _syncBoxesAndProductsFromFirebase(
      Function(String)? onProgress) async {
    try {
      _logger.i('Starting sync of boxes and products from Firebase...');

      // Get all local shipments to sync their boxes and products
      final localShipments = await _localService.getShipments();

      int totalBoxesSynced = 0;
      int totalProductsSynced = 0;
      int processedShipments = 0;

      for (final shipment in localShipments) {
        try {
          processedShipments++;
          onProgress?.call(
              'Syncing boxes and products for shipment ${processedShipments}/${localShipments.length}...');

          print('📋 SYNC DEBUG: Processing shipment:');
          print('   - Invoice Number: ${shipment.invoiceNumber}');
          print('   - AWB: ${shipment.awb}');
          print('   - Invoice Title: ${shipment.invoiceTitle}');

          // Get boxes for this shipment from Firebase using multiple ID attempts
          List<ShipmentBox> firebaseBoxes = [];

          // Try with invoice number first
          firebaseBoxes = await _firebaseService
              .getBoxesForShipment(shipment.invoiceNumber);
          print(
              '📦 Boxes found with invoiceNumber (${shipment.invoiceNumber}): ${firebaseBoxes.length}');

          // If no boxes found, try with AWB
          if (firebaseBoxes.isEmpty && shipment.awb != shipment.invoiceNumber) {
            firebaseBoxes =
                await _firebaseService.getBoxesForShipment(shipment.awb);
            print(
                '📦 Boxes found with AWB (${shipment.awb}): ${firebaseBoxes.length}');
          }

          // Get existing local boxes to prevent duplicates (check both IDs)
          var localBoxes =
              await _localService.getBoxesForShipment(shipment.invoiceNumber);
          if (localBoxes.isEmpty && shipment.awb != shipment.invoiceNumber) {
            localBoxes = await _localService.getBoxesForShipment(shipment.awb);
          }
          final existingBoxIds = localBoxes.map((b) => b.id).toSet();
          print('📦 Existing local boxes: ${existingBoxIds.length}');

          int shipmentBoxesSynced = 0;
          int shipmentProductsSynced = 0;

          for (final box in firebaseBoxes) {
            try {
              // Skip if box already exists locally
              if (existingBoxIds.contains(box.id)) {
                _logger.d('Skipping duplicate box: ${box.id}');
                continue;
              }

              // Determine which shipment ID to use for storage
              // Use AWB if boxes were found with AWB, otherwise use invoiceNumber
              String storageShipmentId = shipment.invoiceNumber;
              if (firebaseBoxes.isNotEmpty) {
                // If we found boxes with invoiceNumber, use invoiceNumber
                var testBoxes = await _firebaseService
                    .getBoxesForShipment(shipment.invoiceNumber);
                if (testBoxes.isEmpty &&
                    shipment.awb != shipment.invoiceNumber) {
                  // Boxes were found with AWB instead
                  storageShipmentId = shipment.awb;
                  print('📦 Using AWB for storage: $storageShipmentId');
                } else {
                  print(
                      '📦 Using invoiceNumber for storage: $storageShipmentId');
                }
              }

              // Save the box to local database with the correct shipment ID
              final savedBoxId =
                  await _localService.saveBox(storageShipmentId, {
                'id': box.id, // Use original Firebase box ID
                'boxNumber': box.boxNumber,
                'length': box.length,
                'width': box.width,
                'height': box.height,
              });
              shipmentBoxesSynced++;
              totalBoxesSynced++;
              print(
                  '📦 Box saved: ${box.id} (${box.boxNumber}) to shipment: $storageShipmentId');

              // Get products for this box from Firebase using the same shipment ID that worked for boxes
              var firebaseProducts = await _firebaseService.getProductsForBox(
                  storageShipmentId, box.id);
              print(
                  '📦 Found ${firebaseProducts.length} products for box ${box.id}');

              // If no products found with the storage shipment ID, try with the original shipment ID as fallback
              if (firebaseProducts.isEmpty &&
                  storageShipmentId != shipment.invoiceNumber) {
                print(
                    '📦 Trying fallback shipment ID for products: ${shipment.invoiceNumber}');
                firebaseProducts = await _firebaseService.getProductsForBox(
                    shipment.invoiceNumber, box.id);
                print(
                    '📦 Found ${firebaseProducts.length} products with fallback ID');
              }

              // Get existing local products to prevent duplicates
              final localProducts =
                  await _localService.getProductsForBox(savedBoxId);
              final existingProductIds = localProducts.map((p) => p.id).toSet();

              for (final product in firebaseProducts) {
                try {
                  // Skip if product already exists locally
                  if (existingProductIds.contains(product.id)) {
                    _logger.d('Skipping duplicate product: ${product.id}');
                    continue;
                  }

                  // Save the product to local database
                  await _localService.saveProduct(savedBoxId, {
                    'id': product.id, // Use original Firebase product ID
                    'description': product.description,
                    'weight': product.weight,
                    'rate': product.rate,
                    'type': product.type,
                    'flowerType': product.flowerType,
                    'hasStems': product.hasStems,
                    'approxQuantity': product.approxQuantity,
                  });
                  shipmentProductsSynced++;
                  totalProductsSynced++;
                  print(
                      '📦 Product saved: ${product.id} (${product.description}) to box: $savedBoxId');
                  totalProductsSynced++;
                } catch (e) {
                  _logger.w('Failed to sync product ${product.id}: $e');
                }
              }
            } catch (e) {
              _logger.w('Failed to sync box ${box.id}: $e');
            }
          }

          _logger.d(
              'Synced ${shipmentBoxesSynced} boxes and ${shipmentProductsSynced} products for shipment ${shipment.invoiceNumber}');
        } catch (e) {
          _logger.w(
              'Failed to sync boxes/products for shipment ${shipment.invoiceNumber}: $e');
        }
      }

      _logger.i(
          'Boxes and products sync completed: ${totalBoxesSynced} boxes, ${totalProductsSynced} products synced across ${processedShipments} shipments');
    } catch (e) {
      _logger.e('Failed to sync boxes and products from Firebase: $e');
      // Don't throw - continue with other sync operations
    }
  }

  /// Sync drafts from Firebase to local
  Future<void> _syncDraftsFromFirebase(Function(String)? onProgress) async {
    try {
      final firebaseDrafts = await _firebaseService.getDrafts();

      int synced = 0;
      for (final draft in firebaseDrafts) {
        try {
          await _localService
              .saveDraft(draft['draftData'] as Map<String, dynamic>);
          synced++;
        } catch (e) {
          _logger.w('Failed to sync draft ${draft['id']}: $e');
        }
      }

      _logger.i('Synced $synced drafts from Firebase');
    } catch (e) {
      _logger.e('Failed to sync drafts from Firebase: $e');
      // Don't throw - drafts sync is not critical
    }
  }

  /// Get the active service
  Future<dynamic> _getActiveService() async {
    return await _shouldUseFirebase() ? _firebaseService : _localService;
  }

  // ========== DATA LOADING ==========

  /// Load all necessary data for the app - LOCAL FIRST: Always from local database for instant response
  Future<Map<String, dynamic>> loadData() async {
    try {
      print('📊 LOCAL_FIRST: Loading all app data from local database...');
      final result = await _localService.loadData();
      print(
          '✅ LOCAL_FIRST: Loaded all app data from local database successfully');
      return result;
    } catch (e, s) {
      print('❌ LOCAL_FIRST: Error loading app data from local database: $e');
      _logger.e('Failed to load data from local database', e, s);
      throw Exception('Failed to load app data: $e');
    }
  }

  // ========== SHIPMENT OPERATIONS ==========

  /// Save a shipment - Local database AND Firebase (both required)
  Future<void> saveShipment(Shipment shipment) async {
    bool localSaved = false;
    bool firebaseSaved = false;
    String? localError;
    String? firebaseError;

    // Always save to local database first (primary storage)
    try {
      await _localService.saveShipment(shipment);
      localSaved = true;
      _logger.i(
          'Shipment ${shipment.invoiceNumber} saved to local database successfully');
    } catch (e) {
      localError = e.toString();
      _logger.e('Failed to save shipment to local database', e);
    }

    // Always attempt to save to Firebase (cloud backup)
    try {
      if (await _isFirebaseAvailable()) {
        await _firebaseService.saveShipment(shipment);
        firebaseSaved = true;
        _logger.i(
            'Shipment ${shipment.invoiceNumber} saved to Firebase successfully');
      } else {
        firebaseError = 'Firebase not available';
        _logger.w('Firebase not available for shipment save');
      }
    } catch (e) {
      firebaseError = e.toString();
      _logger.w('Failed to save shipment to Firebase', e);
    }

    // Report results
    if (localSaved && firebaseSaved) {
      _logger.i(
          'Shipment ${shipment.invoiceNumber} saved successfully to both local database and Firebase');
    } else if (localSaved && !firebaseSaved) {
      _logger.w(
          'Shipment ${shipment.invoiceNumber} saved to local database only. Firebase error: $firebaseError');
      // Don't throw error - local save succeeded, Firebase is backup
    } else if (!localSaved && firebaseSaved) {
      _logger.e(
          'Critical: Shipment saved to Firebase but failed locally: $localError');
      throw Exception(
          'Failed to save shipment to local database (critical): $localError');
    } else {
      _logger.e(
          'Critical: Failed to save shipment to both local database and Firebase');
      throw Exception(
          'Failed to save shipment to local database: $localError. Firebase error: $firebaseError');
    }
  }

  /// Get save status information for UI feedback
  Future<Map<String, bool>> getLastSaveStatus() async {
    // This could be enhanced to track actual save status
    // For now, return current availability status
    return {
      'localAvailable': true, // Local database should always be available
      'firebaseAvailable': await _isFirebaseAvailable(),
    };
  }

  /// Get all shipments - Always from local database for UI operations (fast loading)
  Future<List<Shipment>> getShipments({String? status, int limit = 50}) async {
    // Always use local database for UI operations as per requirements
    // This ensures fast loading within fractions of seconds
    try {
      final shipments =
          await _localService.getShipments(status: status, limit: limit);
      _logger.d('Retrieved ${shipments.length} shipments from local database');
      return shipments;
    } catch (e) {
      _logger.e('Failed to get shipments from local database', e);
      // Return empty list instead of trying Firebase to maintain speed
      return [];
    }
  }

  /// Get shipment by ID - Local database first, then Firebase fallback
  Future<Shipment?> getShipment(String invoiceNumber) async {
    // First, try to get from local database
    try {
      final localShipment = await _localService.getShipment(invoiceNumber);
      if (localShipment != null) {
        _logger.i('Shipment $invoiceNumber found in local database');
        return localShipment;
      }
    } catch (e) {
      _logger.w('Failed to get shipment from local database', e);
    }

    // If not found locally, try Firebase
    try {
      if (await _isFirebaseAvailable()) {
        final firebaseShipment =
            await _firebaseService.getShipment(invoiceNumber);
        if (firebaseShipment != null) {
          _logger.i(
              'Shipment $invoiceNumber retrieved from Firebase and will be cached locally');

          // Cache in local database for future access
          try {
            await _localService.saveShipment(firebaseShipment);
          } catch (e) {
            _logger.w('Failed to cache shipment locally', e);
          }

          return firebaseShipment;
        }
      }
    } catch (e) {
      _logger.w('Failed to get shipment from Firebase', e);
    }

    _logger
        .w('Shipment $invoiceNumber not found in local database or Firebase');
    return null;
  }

  /// Update shipment - Local database first, then Firebase
  Future<void> updateShipment(
      String invoiceNumber, Map<String, dynamic> updates) async {
    // Always update local database first
    try {
      await _localService.updateShipment(invoiceNumber, updates);
      _logger.i('Shipment updated in local database successfully');
    } catch (e) {
      _logger.e('Failed to update shipment in local database', e);
      throw Exception('Failed to update shipment in local database: $e');
    }

    // Then update Firebase if available
    try {
      if (await _isFirebaseAvailable()) {
        await _firebaseService.updateShipment(invoiceNumber, updates);
        _logger.i('Shipment also updated in Firebase');
      }
    } catch (e) {
      _logger.w(
          'Failed to update shipment in Firebase (continuing with local)', e);
      // Don't throw error - local update succeeded
    }
  }

  /// Delete shipment - Local database first, then Firebase
  Future<void> deleteShipment(String invoiceNumber) async {
    // Always delete from local database first (primary storage)
    try {
      await _localService.deleteShipment(invoiceNumber);
      _logger.i('Shipment deleted from local database successfully');
    } catch (e) {
      _logger.e('Failed to delete shipment from local database', e);
      throw Exception('Failed to delete shipment from local database: $e');
    }

    // Then delete from Firebase (secondary/cloud backup) if available
    try {
      if (await _isFirebaseAvailable()) {
        await _firebaseService.deleteShipment(invoiceNumber);
        _logger.i('Shipment also deleted from Firebase');
      }
    } catch (e) {
      _logger.w(
          'Failed to delete shipment from Firebase (continuing with local)', e);
      // Don't throw error - local delete succeeded
    }
  }

  /// Delete all boxes and products for a shipment (used during updates)
  Future<void> deleteAllBoxesForShipment(String shipmentId) async {
    _logger.i('Deleting all boxes for shipment: $shipmentId');
    print(
        '🗑️ DEBUG: DataService.deleteAllBoxesForShipment - shipmentId: $shipmentId');

    try {
      // Delete from Firebase if available
      if (await _isFirebaseAvailable()) {
        print(
            '🗑️ DEBUG: Deleting boxes from Firebase for shipment: $shipmentId');
        await _firebaseService.deleteAllBoxesForShipment(shipmentId);
        _logger.i('Deleted boxes from Firebase for shipment: $shipmentId');
        print('✅ DEBUG: Deleted boxes from Firebase successfully');
      }
    } catch (e) {
      _logger.w(
          'Failed to delete boxes from Firebase for shipment $shipmentId', e);
      print('⚠️ DEBUG: Failed to delete boxes from Firebase: $e');
    }

    try {
      // Always delete from local database
      print(
          '🗑️ DEBUG: Deleting boxes from local DB for shipment: $shipmentId');
      await _localService.deleteAllBoxesForShipment(shipmentId);
      _logger.i('Deleted boxes from local database for shipment: $shipmentId');
      print('✅ DEBUG: Deleted boxes from local DB successfully');
    } catch (e) {
      _logger.e(
          'Failed to delete boxes from local database for shipment $shipmentId',
          e);
      print('❌ DEBUG: Failed to delete boxes from local DB: $e');
      throw Exception('Failed to delete boxes from local database: $e');
    }
  }

  /// Update shipment status - Local database first, then Firebase
  Future<void> updateShipmentStatus(String shipmentId, String status) async {
    // Always update local database first (primary storage)
    try {
      await _localService.updateShipmentStatus(shipmentId, status);
      _logger.i('Shipment status updated in local database successfully');
    } catch (e) {
      _logger.e('Failed to update shipment status in local database', e);
      throw Exception('Failed to update shipment status in local database: $e');
    }

    // Then update Firebase if available (secondary/cloud backup)
    try {
      if (await _isFirebaseAvailable()) {
        await _firebaseService.updateShipmentStatus(shipmentId, status);
        _logger.i('Shipment status also updated in Firebase');
      }
    } catch (e) {
      _logger.w(
          'Failed to update shipment status in Firebase (continuing with local)',
          e);
      // Don't throw error - local update succeeded
    }
  }

  // ========== BOX OPERATIONS ==========

  /// Save a box to a shipment
  Future<String> saveBox(
      String shipmentId, Map<String, dynamic> boxData) async {
    final service = await _getActiveService();
    final result = await service.saveBox(shipmentId, boxData);

    // If using Firebase, also save locally
    if (service == _firebaseService) {
      try {
        await _localService.saveBox(shipmentId, boxData);
      } catch (e) {
        _logger.w('Failed to save box locally', e);
      }
    }

    return result;
  }

  /// Get boxes for a shipment
  Future<List<ShipmentBox>> getBoxesForShipment(String shipmentId) async {
    final service = await _getActiveService();
    return await service.getBoxesForShipment(shipmentId);
  }

  /// Auto-create boxes and products for a shipment (Firebase only)
  Future<void> autoCreateBoxesAndProducts(
    String shipmentId,
    List<Map<String, dynamic>> boxesData,
  ) async {
    final service = await _getActiveService();

    print(
        '📦 DEBUG: DataService.autoCreateBoxesAndProducts - shipmentId: $shipmentId, boxCount: ${boxesData.length}');

    // Always save to local database first (primary storage)
    print('💾 DEBUG: Saving ${boxesData.length} boxes to LOCAL DB...');
    for (final boxData in boxesData) {
      final boxId = await _localService.saveBox(shipmentId, boxData);
      print('✅ DEBUG: Saved box $boxId to local DB');

      if (boxData['products'] != null && boxData['products'] is List) {
        final products = boxData['products'] as List<dynamic>;
        print(
            '💾 DEBUG: Saving ${products.length} products for box $boxId to local DB');
        for (final productData in products) {
          if (productData is Map<String, dynamic>) {
            // Add box_id to productData for proper linking
            final enhancedProductData = {
              ...productData,
              'box_id': boxId,
            };
            await _localService.saveProduct(boxId, enhancedProductData);
          }
        }
        print('✅ DEBUG: Saved all products for box $boxId to local DB');
      }
    }

    // Then save to Firebase (secondary/cloud backup) if available
    if (service == _firebaseService) {
      try {
        print('🔥 DEBUG: Saving ${boxesData.length} boxes to FIREBASE...');
        await _firebaseService.autoCreateBoxesAndProducts(
            shipmentId, boxesData);
        print('✅ DEBUG: Saved all boxes to Firebase successfully');
      } catch (e) {
        _logger.w(
            'Failed to save boxes/products to Firebase (continuing with local)',
            e);
        print('⚠️ DEBUG: Failed to save to Firebase: $e');
        // Don't throw error - local save succeeded, Firebase is just backup
      }
    }
  }

  // ========== PRODUCT OPERATIONS ==========

  /// Save a product to a box
  Future<String> saveProduct(
      String boxId, Map<String, dynamic> productData) async {
    final service = await _getActiveService();

    // We need shipmentId for Firebase, but not for local
    // For now, we'll get it from the productData if available, or handle differently
    String result;
    if (service == _firebaseService) {
      // Firebase needs shipmentId - try to get it from productData or find another way
      final shipmentId = productData['shipmentId'] ?? '';
      if (shipmentId.isEmpty) {
        throw Exception('shipmentId is required for Firebase product save');
      }
      result = await service.saveProduct(shipmentId, boxId, productData);
    } else {
      // Local service
      result = await service.saveProduct(boxId, productData);
    }

    // If using Firebase, also save locally
    if (service == _firebaseService) {
      try {
        final enhancedProductData = {
          ...productData,
          'box_id': boxId,
        };
        await _localService.saveProduct(boxId, enhancedProductData);
      } catch (e) {
        _logger.w('Failed to save product locally', e);
      }
    }

    return result;
  }

  /// Get products for a box
  Future<List<ShipmentProduct>> getProductsForBox(
      String shipmentId, String boxId) async {
    final service = await _getActiveService();
    return await service.getProductsForBox(shipmentId, boxId);
  }

  // ========== DRAFT OPERATIONS ==========

  /// Save draft - Local database first, then Firebase
  Future<String> saveDraft(Map<String, dynamic> draftData) async {
    String? result;

    // Always save to local database first (primary storage)
    try {
      result = await _localService.saveDraft(draftData);
      _logger.i('Draft saved to local database successfully');
    } catch (e) {
      _logger.e('Failed to save draft to local database', e);
      throw Exception('Failed to save draft to local database: $e');
    }

    // Then save to Firebase (secondary/cloud backup)
    try {
      if (await _isFirebaseAvailable()) {
        await _firebaseService.saveDraft(draftData);
        _logger.i('Draft also saved to Firebase for cloud backup');
      }
    } catch (e) {
      _logger.w('Failed to save draft to Firebase (continuing with local)', e);
      // Don't throw error - local save succeeded, Firebase is just backup
    }

    return result ?? DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Get all drafts - Local database first, then Firebase fallback
  Future<List<Map<String, dynamic>>> getDrafts() async {
    // First, try to get from local database
    try {
      final localDrafts = await _localService.getDrafts();
      if (localDrafts.isNotEmpty) {
        _logger.i(
            'Drafts loaded from local database (${localDrafts.length} found)');
        return localDrafts;
      }
    } catch (e) {
      _logger.w('Failed to get drafts from local database: $e');
    }

    // If local is empty or failed, try Firebase
    try {
      if (await _isFirebaseAvailable()) {
        final firebaseDrafts = await _firebaseService.getDrafts();
        _logger.i(
            'Drafts loaded from Firebase as fallback (${firebaseDrafts.length} found)');

        // Cache in local database for future access
        for (final draft in firebaseDrafts) {
          try {
            await _localService
                .saveDraft(draft['draftData'] as Map<String, dynamic>);
          } catch (e) {
            _logger.w('Failed to cache draft locally: $e');
          }
        }

        return firebaseDrafts;
      }
    } catch (e) {
      _logger.w('Failed to get drafts from Firebase: $e');
    }

    _logger.i('No drafts found in local database or Firebase');
    return [];
  }

  /// Delete draft
  Future<void> deleteDraft(String draftId) async {
    final service = await _getActiveService();
    await service.deleteDraft(draftId);

    // If using Firebase, also delete locally
    if (service == _firebaseService) {
      try {
        await _localService.deleteDraft(draftId);
      } catch (e) {
        _logger.w('Failed to delete draft locally', e);
      }
    }
  }

  /// Convert draft to shipment
  Future<String> publishDraft(String draftId) async {
    final service = await _getActiveService();
    final result = await service.publishDraft(draftId);

    // If using Firebase, also publish locally
    if (service == _firebaseService) {
      try {
        await _localService.publishDraft(draftId);
      } catch (e) {
        _logger.w('Failed to publish draft locally', e);
      }
    }

    return result;
  }

  // ========== MASTER DATA OPERATIONS ==========

  /// Get all master shippers - Always from local database for UI operations (fast loading)
  Future<List<dynamic>> getMasterShippers() async {
    // Always use local database for UI operations as per requirements
    try {
      final localResult = await _localService.getMasterShippers();
      _logger.d('Retrieved ${localResult.length} shippers from local database');
      return localResult.map((item) {
        if (item is Map<String, dynamic>) {
          return item;
        } else {
          return {
            'id': item.id,
            'name': item.name,
            'address': item.address,
            'created_at': item.createdAt.millisecondsSinceEpoch,
            'updated_at': item.updatedAt?.millisecondsSinceEpoch,
          };
        }
      }).toList();
    } catch (e) {
      _logger.e('Failed to get master shippers from local database: $e');
      return [];
    }
  }

  /// Save a master shipper - Local database first, then Firebase
  Future<String> saveMasterShipper(Map<String, dynamic> shipperData) async {
    String? result;

    // Always save to local database first (primary storage)
    try {
      // For local service, create MasterShipper object if needed
      final shipper = MasterShipper(
        id: shipperData['id'] ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: shipperData['name'] ?? '',
        address: shipperData['address'] ?? '',
        phone: shipperData['phone'],
        addressLine1: shipperData['addressLine1'],
        addressLine2: shipperData['addressLine2'],
        city: shipperData['city'],
        state: shipperData['state'],
        pincode: shipperData['pincode'],
        landmark: shipperData['landmark'],
        createdAt: shipperData['createdAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                shipperData['createdAt'] as int)
            : DateTime.now(),
      );
      result = await _localService.saveMasterShipper(shipper);
      _logger.i('Master shipper saved to local database successfully');
    } catch (e) {
      _logger.e('Failed to save master shipper to local database', e);
      throw Exception('Failed to save master shipper to local database: $e');
    }

    // Then save to Firebase (secondary/cloud backup)
    try {
      if (await _isFirebaseAvailable()) {
        final shipper = MasterShipper(
          id: shipperData['id'] ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          name: shipperData['name'] ?? '',
          address: shipperData['address'] ?? '',
          phone: shipperData['phone'],
          addressLine1: shipperData['addressLine1'],
          addressLine2: shipperData['addressLine2'],
          city: shipperData['city'],
          state: shipperData['state'],
          pincode: shipperData['pincode'],
          landmark: shipperData['landmark'],
          createdAt: shipperData['createdAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  shipperData['createdAt'] as int)
              : DateTime.now(),
        );
        await _firebaseService.saveMasterShipper(shipper);
        _logger.i('Master shipper also saved to Firebase for cloud backup');
      }
    } catch (e) {
      _logger.w(
          'Failed to save master shipper to Firebase (continuing with local)',
          e);
      // Don't throw error - local save succeeded, Firebase is just backup
    }

    return result ?? DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Update a master shipper - Local database first, then Firebase
  Future<void> updateMasterShipper(
      String id, Map<String, dynamic> updates) async {
    // Always update local database first (primary storage)
    try {
      if ((_localService as dynamic).updateMasterShipper != null) {
        await (_localService as dynamic).updateMasterShipper(id, updates);
        _logger.i('Master shipper updated in local database successfully');
      } else {
        throw Exception(
            'Local service does not support master shipper updates');
      }
    } catch (e) {
      _logger.e('Failed to update master shipper in local database', e);
      throw Exception('Failed to update master shipper in local database: $e');
    }

    // Then update Firebase if available (secondary/cloud backup)
    try {
      if (await _isFirebaseAvailable()) {
        await _firebaseService.updateMasterShipper(id, updates);
        _logger.i('Master shipper also updated in Firebase');
      }
    } catch (e) {
      _logger.w(
          'Failed to update master shipper in Firebase (continuing with local)',
          e);
      // Don't throw error - local update succeeded
    }
  }

  /// Delete a master shipper
  Future<void> deleteMasterShipper(String id) async {
    final service = await _getActiveService();
    await service.deleteMasterShipper(id);

    // If using Firebase, also delete locally (if method exists)
    if (service == _firebaseService) {
      try {
        if ((_localService as dynamic).deleteMasterShipper != null) {
          await (_localService as dynamic).deleteMasterShipper(id);
        }
      } catch (e) {
        _logger.w('Failed to delete master shipper locally', e);
      }
    }
  }

  /// Get all master consignees - LOCAL FIRST: Always from local database for instant response
  Future<List<dynamic>> getMasterConsignees() async {
    try {
      print('📊 LOCAL_FIRST: Loading master consignees from local database...');
      final result = await _localService.getMasterConsignees();
      print(
          '✅ LOCAL_FIRST: Loaded ${result.length} consignees from local database');

      // Convert to consistent Map format for dropdowns
      return result.map((item) {
        if (item is Map<String, dynamic>) {
          return item;
        } else {
          // Handle MasterConsignee objects from Firebase
          return {
            'id': item.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
            'name': item.name ?? '',
            'address': item.address ?? '',
            'created_at': item.createdAt.millisecondsSinceEpoch,
            'updated_at': item.updatedAt?.millisecondsSinceEpoch,
          };
        }
      }).toList();
    } catch (e) {
      _logger.w(
          'Master consignees not available in service, returning empty list: $e');
      return [];
    }
  }

  /// Save a master consignee - Local database first, then Firebase
  Future<String> saveMasterConsignee(Map<String, dynamic> consigneeData) async {
    String? result;

    // Always save to local database first (primary storage)
    try {
      final consignee = MasterConsignee(
        id: consigneeData['id'] ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: consigneeData['name'] ?? '',
        address: consigneeData['address'] ?? '',
        phone: consigneeData['phone'],
        addressLine1: consigneeData['addressLine1'],
        addressLine2: consigneeData['addressLine2'],
        city: consigneeData['city'],
        state: consigneeData['state'],
        pincode: consigneeData['pincode'],
        landmark: consigneeData['landmark'],
        createdAt: consigneeData['createdAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                consigneeData['createdAt'] as int)
            : DateTime.now(),
      );
      result = await _localService.saveMasterConsignee(consignee);
      _logger.i('Master consignee saved to local database successfully');
    } catch (e) {
      _logger.e('Failed to save master consignee to local database', e);
      throw Exception('Failed to save master consignee to local database: $e');
    }

    // Then save to Firebase (secondary/cloud backup)
    try {
      if (await _isFirebaseAvailable()) {
        final consignee = MasterConsignee(
          id: consigneeData['id'] ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          name: consigneeData['name'] ?? '',
          address: consigneeData['address'] ?? '',
          phone: consigneeData['phone'],
          addressLine1: consigneeData['addressLine1'],
          addressLine2: consigneeData['addressLine2'],
          city: consigneeData['city'],
          state: consigneeData['state'],
          pincode: consigneeData['pincode'],
          landmark: consigneeData['landmark'],
          createdAt: consigneeData['createdAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  consigneeData['createdAt'] as int)
              : DateTime.now(),
        );
        await _firebaseService.saveMasterConsignee(consignee);
        _logger.i('Master consignee also saved to Firebase for cloud backup');
      }
    } catch (e) {
      _logger.w(
          'Failed to save master consignee to Firebase (continuing with local)',
          e);
      // Don't throw error - local save succeeded, Firebase is just backup
    }

    return result ?? DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Update a master consignee - Local database first, then Firebase
  Future<void> updateMasterConsignee(
      String id, Map<String, dynamic> updates) async {
    // Always update local database first (primary storage)
    try {
      if ((_localService as dynamic).updateMasterConsignee != null) {
        await (_localService as dynamic).updateMasterConsignee(id, updates);
        _logger.i('Master consignee updated in local database successfully');
      } else {
        throw Exception(
            'Local service does not support master consignee updates');
      }
    } catch (e) {
      _logger.e('Failed to update master consignee in local database', e);
      throw Exception(
          'Failed to update master consignee in local database: $e');
    }

    // Then update Firebase if available (secondary/cloud backup)
    try {
      if (await _isFirebaseAvailable()) {
        await _firebaseService.updateMasterConsignee(id, updates);
        _logger.i('Master consignee also updated in Firebase');
      }
    } catch (e) {
      _logger.w(
          'Failed to update master consignee in Firebase (continuing with local)',
          e);
      // Don't throw error - local update succeeded
    }
  }

  /// Delete a master consignee
  Future<void> deleteMasterConsignee(String id) async {
    final service = await _getActiveService();
    await service.deleteMasterConsignee(id);

    // If using Firebase, also delete locally (if method exists)
    if (service == _firebaseService) {
      try {
        if ((_localService as dynamic).deleteMasterConsignee != null) {
          await (_localService as dynamic).deleteMasterConsignee(id);
        }
      } catch (e) {
        _logger.w('Failed to delete master consignee locally', e);
      }
    }
  }

  /// Get all master product types - LOCAL FIRST: Always from local database for instant response
  Future<List<dynamic>> getMasterProductTypes() async {
    try {
      print(
          '📊 LOCAL_FIRST: Loading master product types from local database...');
      final result = await _localService.getMasterProductTypes();
      print(
          '✅ LOCAL_FIRST: Loaded ${result.length} product types from local database');

      // Convert to consistent Map format for dropdowns
      return result.map((item) {
        if (item is Map<String, dynamic>) {
          return item;
        } else {
          // Handle MasterProductType objects from Firebase
          return {
            'id': item.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
            'name': item.name ?? '',
            'approx_quantity': item.approxQuantity ?? 1,
            'created_at': item.createdAt.millisecondsSinceEpoch,
            'updated_at': item.updatedAt?.millisecondsSinceEpoch,
          };
        }
      }).toList();
    } catch (e) {
      _logger.w(
          'Master product types not available in service, returning empty list: $e');
      return [];
    }
  }

  /// Save a master product type - Local database first, then Firebase
  Future<String> saveMasterProductType(
      Map<String, dynamic> productTypeData) async {
    // Generate ID once if not provided
    final generatedId = productTypeData['id'] ??
        DateTime.now().millisecondsSinceEpoch.toString();

    // Always save to local database first (primary storage)
    try {
      final productType = MasterProductType(
        id: generatedId,
        name: productTypeData['name'] ?? '',
        approxQuantity: productTypeData['approx_quantity'] as int? ?? 1,
        createdAt: productTypeData['createdAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                productTypeData['createdAt'] as int)
            : DateTime.now(),
      );
      await _localService.saveMasterProductType(productType);
      _logger.i('Master product type saved to local database successfully');
    } catch (e) {
      _logger.e('Failed to save master product type to local database', e);
      throw Exception(
          'Failed to save master product type to local database: $e');
    }

    // Then save to Firebase (secondary/cloud backup) with the SAME ID
    try {
      if (await _isFirebaseAvailable()) {
        final productType = MasterProductType(
          id: generatedId, // Use the same ID as local
          name: productTypeData['name'] ?? '',
          approxQuantity: productTypeData['approx_quantity'] as int? ?? 1,
          createdAt: productTypeData['createdAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  productTypeData['createdAt'] as int)
              : DateTime.now(),
        );
        await _firebaseService.saveMasterProductType(productType);
        _logger
            .i('Master product type also saved to Firebase for cloud backup');
      }
    } catch (e) {
      _logger.w(
          'Failed to save master product type to Firebase (continuing with local)',
          e);
      // Don't throw error - local save succeeded, Firebase is just backup
    }

    return generatedId;
  }

  /// Update a master product type - Local database first, then Firebase
  Future<void> updateMasterProductType(
      String id, Map<String, dynamic> updates) async {
    // Always update local database first (primary storage)
    try {
      await _localService.updateMasterProductType(id, updates);
      _logger.i('Master product type updated in local database successfully');
    } catch (e) {
      _logger.e('Failed to update master product type in local database', e);
      throw Exception(
          'Failed to update master product type in local database: $e');
    }

    // Then update Firebase if available (secondary/cloud backup)
    try {
      if (await _isFirebaseAvailable()) {
        await _firebaseService.updateMasterProductType(id, updates);
        _logger.i('Master product type also updated in Firebase');
      }
    } catch (e) {
      _logger.w(
          'Failed to update master product type in Firebase (continuing with local)',
          e);
      // Don't throw error - local update succeeded
    }
  }

  /// Delete a master product type - LOCAL FIRST, then Firebase
  Future<void> deleteMasterProductType(String id) async {
    // ALWAYS delete from local database FIRST
    try {
      await _localService.deleteMasterProductType(id);
      print('✅ DELETE: Master product type deleted from LOCAL database');
    } catch (e) {
      print('❌ DELETE: Failed to delete product type from LOCAL: $e');
      throw Exception('Failed to delete from local database: $e');
    }

    // THEN delete from Firebase (backup)
    try {
      if (await _isFirebaseAvailable()) {
        await _firebaseService.deleteMasterProductType(id);
        print('✅ DELETE: Master product type also deleted from FIREBASE');
      }
    } catch (e) {
      print('⚠️ DELETE: Firebase delete failed (local succeeded): $e');
    }
  }

  // ========== FLOWER TYPES ==========

  /// Get all flower types
  /// Get all flower types - LOCAL FIRST: Always return local database results for UI
  Future<List<dynamic>> getFlowerTypes() async {
    try {
      final local = await _localService.getFlowerTypes();

      // Convert to simple Map format expected by UI/provider
      return local.map((item) {
        return {
          'id': item.id,
          'flower_name': item.flowerName,
          'description': item.description,
        };
      }).toList();
    } catch (e) {
      _logger.w('Failed to load flower types from local DB: $e');
      // Fallback: try active service (Firebase) if available
      try {
        final service = await _getActiveService();
        final remote = await service.getFlowerTypes();
        return remote.map((item) {
          if (item is FlowerType) {
            return {
              'id': item.id,
              'flower_name': item.flowerName,
              'description': item.description,
            };
          } else if (item is Map<String, dynamic>) {
            return item;
          }
          return {};
        }).toList();
      } catch (e2) {
        _logger.w('Failed to load flower types from remote: $e2');
        return [];
      }
    }
  }

  /// Save a flower type (local only)
  Future<String> saveFlowerType(Map<String, dynamic> flowerTypeData) async {
    final generatedId = flowerTypeData['id'] ??
        DateTime.now().millisecondsSinceEpoch.toString();

    try {
      final flowerType = FlowerType(
        id: generatedId,
        flowerName:
            flowerTypeData['flower_name'] ?? flowerTypeData['flowerName'] ?? '',
        description: flowerTypeData['description'] ?? '',
      );

      await _localService.saveFlowerType(flowerType);
      _logger.i('Flower type saved to local database successfully');
    } catch (e) {
      _logger.e('Failed to save flower type to local database', e);
      throw Exception('Failed to save flower type to local database: $e');
    }

    // Then save to Firebase (secondary/cloud backup) with the SAME ID if available
    try {
      if (await _isFirebaseAvailable()) {
        final flowerType = FlowerType(
          id: generatedId,
          flowerName: flowerTypeData['flower_name'] ??
              flowerTypeData['flowerName'] ??
              '',
          description: flowerTypeData['description'] ?? '',
        );
        await _firebaseService.saveFlowerType(flowerType);
        _logger.i('Flower type also saved to Firebase for cloud backup');
      }
    } catch (e) {
      _logger.w(
          'Failed to save flower type to Firebase (continuing with local)', e);
      // Don't throw - local save succeeded
    }

    return generatedId;
  }

  /// Update a flower type (local only)
  Future<void> updateFlowerType(String id, Map<String, dynamic> updates) async {
    try {
      await _localService.updateFlowerType(id, updates);
      _logger.i('Flower type updated in local database successfully');
    } catch (e) {
      _logger.e('Failed to update flower type in local database', e);
      throw Exception('Failed to update flower type in local database: $e');
    }
    // Then update Firebase if available
    try {
      if (await _isFirebaseAvailable()) {
        await _firebaseService.updateFlowerType(id, updates);
        _logger.i('Flower type also updated in Firebase');
      }
    } catch (e) {
      _logger.w(
          'Failed to update flower type in Firebase (continuing with local)',
          e);
    }
  }

  /// Delete a flower type (local only)
  Future<void> deleteFlowerType(String id) async {
    // ALWAYS delete from local database FIRST
    try {
      await _localService.deleteFlowerType(id);
      _logger.i('Flower type deleted from LOCAL database');
    } catch (e) {
      _logger.e('Failed to delete flower type from LOCAL: $e');
      throw Exception('Failed to delete flower type from local database: $e');
    }

    // THEN delete from Firebase (backup)
    try {
      if (await _isFirebaseAvailable()) {
        await _firebaseService.deleteFlowerType(id);
        _logger.i('Flower type also deleted from FIREBASE');
      }
    } catch (e) {
      _logger.w('Firebase delete failed (local succeeded): $e');
    }
  }

  // ========== SETTINGS ==========

  /// Get setting value by key
  Future<String?> getSetting(String key) async {
    final service = await _getActiveService();
    return await service.getSetting(key);
  }

  /// Set setting value
  Future<void> setSetting(String key, String value) async {
    final service = await _getActiveService();
    await service.setSetting(key, value);

    // If using Firebase, also set locally (if method exists)
    if (service == _firebaseService) {
      try {
        if ((_localService as dynamic).setSetting != null) {
          await (_localService as dynamic).setSetting(key, value);
        }
      } catch (e) {
        _logger.w('Failed to set setting locally', e);
      }
    }
  }

  // ========== STATISTICS ==========

  /// Get database statistics
  Future<Map<String, dynamic>> getStats() async {
    final service = await _getActiveService();
    return await service.getStats();
  }

  /// Get shipment statistics
  Future<Map<String, dynamic>> getShipmentStats() async {
    final service = await _getActiveService();
    return await service.getShipmentStats();
  }

  // ========== SEARCH ==========

  /// Search shipments
  Future<List<Shipment>> searchShipments(String query) async {
    final service = await _getActiveService();
    return await service.searchShipments(query);
  }

  /// Search master data by name
  Future<List<Map<String, dynamic>>> searchMasterData(
      String collection, String searchTerm) async {
    final service = await _getActiveService();
    return await service.searchMasterData(collection, searchTerm);
  }

  // ========== SYNC OPERATIONS ==========

  /// Sync local data to Firebase (for when coming back online)
  Future<void> syncToFirebase() async {
    try {
      // Check if we're online first
      final isOnline = await _shouldUseFirebase();
      if (!isOnline || _forceOffline) {
        throw Exception(
            'Cannot sync to Firebase: No internet connection or in offline mode');
      }

      _logger.i('Starting sync to Firebase...');

      // Get all local shipments
      final localShipments = await _localService.getShipments();

      if (localShipments.isEmpty) {
        _logger.i('No local shipments to sync');
        return;
      }

      _logger.i('Syncing ${localShipments.length} shipments to Firebase...');

      // Sync each shipment to Firebase
      int successCount = 0;
      int failureCount = 0;

      for (final shipment in localShipments) {
        try {
          await _firebaseService.saveShipment(shipment);
          successCount++;
        } catch (e) {
          failureCount++;
          _logger.w('Failed to sync shipment ${shipment.invoiceNumber}', e);
          // Continue with other shipments instead of failing completely
        }
      }

      _logger.i(
          'Shipment sync completed: $successCount successful, $failureCount failed');

      if (failureCount > 0 && successCount == 0) {
        throw Exception(
            'All shipments failed to sync. Check your internet connection and Firebase permissions.');
      } else if (failureCount > 0) {
        _logger.w(
            '$failureCount shipments failed to sync, but $successCount succeeded');
      }

      // Sync master data to Firebase
      await _syncMasterDataToFirebase();
    } catch (e, s) {
      _logger.e('Failed to sync to Firebase', e, s);
      if (e.toString().contains('User not authenticated')) {
        throw Exception(
            'Authentication required. Please log out and log back in.');
      } else if (e.toString().contains('permission-denied')) {
        throw Exception(
            'Permission denied. Please check your Firebase security rules.');
      } else {
        throw Exception('Sync failed: ${e.toString()}');
      }
    }
  }

  /// Sync local master data to Firebase
  Future<void> _syncMasterDataToFirebase() async {
    try {
      print('🔄 MASTER_DATA_SYNC: Starting master data sync to Firebase...');
      _logger.i('Starting master data sync to Firebase...');

      // Sync master shippers
      final localShippers = await _localService.getMasterShippers();
      print(
          '🔄 MASTER_DATA_SYNC: Found ${localShippers.length} shippers to sync');
      for (final shipper in localShippers) {
        try {
          await _firebaseService.saveMasterShipper(shipper);
          print('✅ MASTER_DATA_SYNC: Synced shipper: ${shipper.name}');
          _logger.i('✅ Synced shipper: ${shipper.name}');
        } catch (e) {
          print('❌ MASTER_DATA_SYNC: Failed to sync shipper ${shipper.name}');
          _logger.w('Failed to sync shipper ${shipper.name} to Firebase', e);
        }
      }

      // Sync master consignees
      final localConsignees = await _localService.getMasterConsignees();
      print(
          '🔄 MASTER_DATA_SYNC: Found ${localConsignees.length} consignees to sync');
      for (final consignee in localConsignees) {
        try {
          await _firebaseService.saveMasterConsignee(consignee);
          print('✅ MASTER_DATA_SYNC: Synced consignee: ${consignee.name}');
          _logger.i('✅ Synced consignee: ${consignee.name}');
        } catch (e) {
          print(
              '❌ MASTER_DATA_SYNC: Failed to sync consignee ${consignee.name}');
          _logger.w(
              'Failed to sync consignee ${consignee.name} to Firebase', e);
        }
      }

      // Sync master product types
      final localProductTypes = await _localService.getMasterProductTypes();
      print(
          '🔄 MASTER_DATA_SYNC: Found ${localProductTypes.length} product types to sync');
      for (final productType in localProductTypes) {
        try {
          await _firebaseService.saveMasterProductType(productType);
          print(
              '✅ MASTER_DATA_SYNC: Synced product type: ${productType.name} (approxQuantity: ${productType.approxQuantity})');
          _logger.i(
              '✅ Synced product type: ${productType.name} (approxQuantity: ${productType.approxQuantity})');
        } catch (e) {
          print(
              '❌ MASTER_DATA_SYNC: Failed to sync product type ${productType.name}');
          _logger.w(
              'Failed to sync product type ${productType.name} to Firebase', e);
        }
      }

      print(
          '✅ MASTER_DATA_SYNC: Master data sync to Firebase completed successfully!');
      _logger.i('Master data sync to Firebase completed');
    } catch (e) {
      print('❌ MASTER_DATA_SYNC: Failed to sync master data to Firebase: $e');
      _logger.e('Failed to sync master data to Firebase', e);
      // Don't rethrow - master data sync failure shouldn't stop overall sync
    }
  }

  /// Sync Firebase data to local (for initial sync)
  Future<void> syncFromFirebase() async {
    try {
      // Check if we're online first
      final isOnline = await _shouldUseFirebase();
      if (!isOnline || _forceOffline) {
        throw Exception(
            'Cannot sync from Firebase: No internet connection or in offline mode');
      }

      _logger.i('Starting sync from Firebase...');

      // Get all Firebase shipments
      final firebaseShipments = await _firebaseService.getShipments();

      // Sync each shipment to local
      for (final shipment in firebaseShipments) {
        try {
          await _localService.saveShipment(shipment);
        } catch (e) {
          _logger.w(
              'Failed to sync shipment ${shipment.invoiceNumber} locally', e);
        }
      }

      // Sync master data (only if methods exist)
      try {
        final masterShippers = await _firebaseService.getMasterShippers();
        for (final shipper in masterShippers) {
          try {
            if ((_localService as dynamic).saveMasterShipper != null) {
              await (_localService as dynamic)
                  .saveMasterShipper(shipper.toMap());
            }
          } catch (e) {
            _logger.w('Failed to sync master shipper ${shipper.id} locally', e);
          }
        }

        final masterConsignees = await _firebaseService.getMasterConsignees();
        for (final consignee in masterConsignees) {
          try {
            if ((_localService as dynamic).saveMasterConsignee != null) {
              await (_localService as dynamic)
                  .saveMasterConsignee(consignee.toMap());
            }
          } catch (e) {
            _logger.w(
                'Failed to sync master consignee ${consignee.id} locally', e);
          }
        }

        final masterProductTypes =
            await _firebaseService.getMasterProductTypes();
        for (final productType in masterProductTypes) {
          try {
            if ((_localService as dynamic).saveMasterProductType != null) {
              await (_localService as dynamic)
                  .saveMasterProductType(productType.toMap());
            }
          } catch (e) {
            _logger.w(
                'Failed to sync master product type ${productType.id} locally',
                e);
          }
        }
      } catch (e) {
        _logger.w('Failed to sync master data from Firebase', e);
      }

      _logger.i('Sync from Firebase completed');
    } catch (e, s) {
      _logger.e('Failed to sync from Firebase', e, s);
    }
  }

  // ========== UTILITY METHODS ==========

  /// Get current data source info
  Future<Map<String, dynamic>> getDataSourceInfo() async {
    final isOnline = await _shouldUseFirebase();
    final service = await _getActiveService();

    return {
      'isOnline': isOnline,
      'usingFirebase': service == _firebaseService,
      'preferFirebase': _preferFirebase,
      'forceOffline': _forceOffline,
      'currentUserId': _firebaseService.currentUserId,
    };
  }

  /// Get the next invoice number in KS format (KS0001, KS0002, etc.)
  Future<String> getNextInvoiceNumber() async {
    try {
      // Always use local database for invoice number generation
      return await _localService.getNextInvoiceNumber();
    } catch (e) {
      _logger.e('Failed to get next invoice number', e);
      // Fallback to timestamp-based number
      return 'KS${DateTime.now().millisecondsSinceEpoch.toString().substring(8, 12)}';
    }
  }

  /// Get the next AWB number in awb format (awb001, awb002, etc.)
  Future<String> getNextAwbNumber() async {
    try {
      // Always use local database for AWB number generation
      return await _localService.getNextAwbNumber();
    } catch (e) {
      _logger.e('Failed to get next AWB number', e);
      // Fallback to timestamp-based number
      return 'awb${DateTime.now().millisecondsSinceEpoch.toString().substring(8, 12)}';
    }
  }

  /// Force switch to offline mode
  void forceOfflineMode(bool offline) {
    _forceOffline = offline;
    _firebaseService
        .setForceOffline(offline); // Also set Firebase service offline
    _logger.i('Forced offline mode: $offline');
  }
}
