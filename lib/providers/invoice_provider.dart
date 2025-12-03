import 'package:flutter/material.dart';
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
      print(
          '📝 DEBUG: createShipmentWithBoxes - checking if shipment ${shipment.invoiceNumber} already exists');
      final existingShipment =
          await _dataService.getShipment(shipment.invoiceNumber);
      final isUpdate = existingShipment != null;

      if (isUpdate) {
        print(
            '📝 DEBUG: Shipment ${shipment.invoiceNumber} already exists - this is an UPDATE');
        // Delete existing boxes/products before adding new ones
        try {
          print(
              '🗑️ DEBUG: Deleting existing boxes for shipment ${shipment.invoiceNumber}');
          await _dataService.deleteAllBoxesForShipment(shipment.invoiceNumber);
          print('✅ DEBUG: Deleted existing boxes successfully');
        } catch (e) {
          print('⚠️ DEBUG: Failed to delete existing boxes: $e');
          _logger.w('Failed to delete existing boxes during update', e);
          // Don't fail the entire operation, just warn
        }
      } else {
        print(
            '📝 DEBUG: Shipment ${shipment.invoiceNumber} is NEW - this is a CREATE');
      }

      // Save shipment first to both local database and Firebase
      print('💾 DEBUG: Saving shipment ${shipment.invoiceNumber}');
      await _dataService.saveShipment(shipment);
      print('✅ DEBUG: Shipment saved successfully');

      // Auto-create boxes and products if provided
      if (boxesData.isNotEmpty) {
        try {
          print(
              '📦 DEBUG: Auto-creating ${boxesData.length} boxes for shipment ${shipment.invoiceNumber}');
          await _dataService.autoCreateBoxesAndProducts(
            shipment.invoiceNumber,
            boxesData,
          );
          print('✅ DEBUG: Auto-created boxes successfully');
          _logger.i(
              'Auto-created ${boxesData.length} boxes for shipment ${shipment.invoiceNumber}');
        } catch (e) {
          print('❌ DEBUG: Failed to auto-create boxes: $e');
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
        print('📝 DEBUG: Updating shipment in list at index $index');
        _shipments[index] = shipment;
      } else {
        print('📝 DEBUG: Adding new shipment to list');
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
      print('✅ DEBUG: $statusMessage');
    } catch (e, s) {
      _logger.e('Failed to create shipment with boxes', e, s);
      _error = 'Failed to create shipment: $e';
      print('❌ DEBUG: Error: $e');
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

  /// Update shipment with boxes/products - saves to both Firebase and local DB
  Future<void> updateShipmentWithBoxes(
      Shipment shipment, List<Map<String, dynamic>> boxesData) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _logger.i('Updating shipment with boxes: ${shipment.invoiceNumber}');

      // First, attempt to update the basic shipment data
      try {
        print(
            '📝 DEBUG: InvoiceProvider.updateShipmentWithBoxes - preparing updates');
        final updates = {
          'invoiceTitle': shipment.invoiceTitle,
          'shipper': shipment.shipper,
          'consignee': shipment.consignee,
          'awb': shipment.awb,
          'flightNo': shipment.flightNo,
          'dischargeAirport': shipment.dischargeAirport,
          'origin': shipment.origin,
          'destination': shipment.destination,
          'eta': shipment.eta.millisecondsSinceEpoch,
          'totalAmount': shipment.totalAmount,
          'shipperAddress': shipment.shipperAddress,
          'consigneeAddress': shipment.consigneeAddress,
          'clientRef': shipment.clientRef,
          'invoiceDate': shipment.invoiceDate?.millisecondsSinceEpoch,
          'dateOfIssue': shipment.dateOfIssue?.millisecondsSinceEpoch,
          'placeOfReceipt': shipment.placeOfReceipt,
          'sgstNo': shipment.sgstNo,
          'iecCode': shipment.iecCode,
          'freightTerms': shipment.freightTerms,
        };
        print('📝 DEBUG: Updates to save - keys: ${updates.keys.toList()}');
        print(
            '📝 DEBUG: flightNo: ${updates['flightNo']}, dischargeAirport: ${updates['dischargeAirport']}');

        await _dataService.updateShipment(shipment.invoiceNumber, updates);
        print('✅ DEBUG: Shipment basic info updated successfully');
      } catch (updateError) {
        // If the update failed (maybe record not found locally), try to create the shipment instead
        _logger.w(
            'Update failed for ${shipment.invoiceNumber}. Attempting to save instead: $updateError');
        print('⚠️ DEBUG: Update failed, attempting saveShipment as fallback');
        try {
          // saveShipment is idempotent via conflictAlgorithm.replace on local DB
          await _dataService.saveShipment(shipment);
          _logger.i(
              'Saved shipment ${shipment.invoiceNumber} after update failure');
          print('✅ DEBUG: Saved shipment as fallback');
        } catch (saveError) {
          _logger.e('Failed to save shipment after update failure', saveError);
          print('❌ DEBUG: Failed to save shipment: $saveError');
          rethrow; // Bubble up to provider layer
        }
      }

      // Handle boxes and products update
      // Only delete and recreate boxes if boxesData is not empty
      // If boxesData is empty, preserve existing boxes (user only updated shipment details)
      if (boxesData.isNotEmpty) {
        try {
          await _dataService.deleteAllBoxesForShipment(shipment.invoiceNumber);
          _logger.i(
              'Deleted existing boxes for shipment: ${shipment.invoiceNumber}');
        } catch (e) {
          _logger.e(
              'Failed to delete existing boxes for shipment ${shipment.invoiceNumber}',
              e);
          rethrow;
        }

        // Auto-create updated boxes and products if provided
        try {
          await _dataService.autoCreateBoxesAndProducts(
            shipment.invoiceNumber,
            boxesData,
          );
          _logger.i(
              'Updated ${boxesData.length} boxes for shipment ${shipment.invoiceNumber}');
        } catch (e) {
          _logger.e(
              'Failed to auto-create boxes/products for shipment ${shipment.invoiceNumber}',
              e);
          rethrow;
        }
      } else {
        _logger.i(
            'No boxes data provided - preserving existing boxes for shipment ${shipment.invoiceNumber}');
      }

      // Update local shipments list
      final index = _shipments
          .indexWhere((s) => s.invoiceNumber == shipment.invoiceNumber);
      if (index != -1) {
        _shipments[index] = shipment;
      }

      // Check save status for user feedback
      final saveStatus = await _dataService.getLastSaveStatus();
      final localSaved = saveStatus['localAvailable'] ?? false;
      final firebaseSaved = saveStatus['firebaseAvailable'] ?? false;

      String statusMessage =
          'Shipment with boxes updated: ${shipment.invoiceNumber}';
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

  /// Delete a shipment using the data service
  Future<void> deleteShipment(String shipmentId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _dataService.deleteShipment(shipmentId);
      _shipments.removeWhere((s) => s.invoiceNumber == shipmentId);

      _logger.i('Shipment deleted: $shipmentId');
    } catch (e, s) {
      _logger.e('Failed to delete shipment', e, s);
      _error = 'Failed to delete shipment: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
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
      dischargeAirport: 'TBD',
      eta: DateTime.now().add(Duration(days: 1)),
      totalAmount: total,
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
        await pdfService.generateShipmentPDF(
            invoice.shipment, invoice.items, true);
        _logger.i('Invoice ${invoice.invoiceNumber} previewed successfully.');
      } catch (e, s) {
        _logger.e('Failed to preview invoice', e, s);
        _error = 'Failed to generate PDF. Please try again.';
        notifyListeners();
      }
    }
  }

  /// Shares the current invoice as a PDF.
  Future<void> shareInvoice() async {
    final invoice = await _createAndSaveInvoice();
    if (invoice != null) {
      try {
        final pdfService = PdfService();
        await pdfService.generateShipmentPDF(
            invoice.shipment, invoice.items, false);
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
        try {
          final localShipments = await _dataService.getShipments();
          _logger.i(
              '📄 Current local database has ${localShipments.length} shipments');

          // Check if Firebase is available and sync from Firebase to local
          final dataSourceInfo = await _dataService.getDataSourceInfo();
          final isOnline = dataSourceInfo['isOnline'] ?? false;
          final currentUserId = dataSourceInfo['currentUserId'];

          if (isOnline && currentUserId != null) {
            _logger.i(
                '📥 Login-time auto-sync - syncing latest data from Firebase...');

            try {
              await _dataService.syncFromFirebaseToLocal(
                onProgress: (progress) {
                  _logger.i('📥 Login sync progress: $progress');
                },
              );

              _logger
                  .i('✅ Login-time sync from Firebase completed successfully');
              _hasPerformedLoginSync = true;

              // Verify sync worked and show updated count
              final updatedShipments = await _dataService.getShipments();
              _logger.i(
                  '📊 After login sync: Found ${updatedShipments.length} shipments in local database');
            } catch (syncError) {
              _logger.e(
                  '❌ Login-time sync from Firebase failed, using existing local data',
                  syncError);
              // Don't block app startup if sync fails, continue with local data
            }
          } else {
            if (currentUserId == null) {
              _logger.i('📶 Not authenticated - using local data only');
            } else {
              _logger.i('📶 Offline - using local data only');
            }
          }
        } catch (e) {
          _logger.e(
              '❌ Failed to perform login-time sync check, continuing with local data',
              e);
        }
      } else {
        _logger.i(
            '🔄 Normal app startup - skipping auto-sync (already performed at login)');
      }

      // Load shipments (after potential sync)
      final shipments = await _dataService.getShipments();
      _shipments = shipments;

      // Load master data
      final masterShippers = await _dataService.getMasterShippers();
      final masterConsignees = await _dataService.getMasterConsignees();
      final masterProductTypes = await _dataService.getMasterProductTypes();
      final flowerTypes = await _dataService.getFlowerTypes();

      _masterData = {
        'shippers': masterShippers,
        'consignees': masterConsignees,
        'productTypes': masterProductTypes,
        'flowerTypes': flowerTypes,
      };

      // Load drafts
      final drafts = await _dataService.getDrafts();
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
    _logger.i('🔐 Performing login-time auto-sync...');
    _hasPerformedLoginSync = false; // Reset flag to allow sync
    await loadInitialData(isLoginTime: true);
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
}
