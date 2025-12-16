import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:invoice_generator/models/shipment.dart';
import 'package:invoice_generator/models/box_product.dart';
import 'package:invoice_generator/models/product.dart';
import 'package:invoice_generator/models/master_shipper.dart';
import 'package:invoice_generator/models/master_consignee.dart';
import 'package:invoice_generator/models/master_product_type.dart';
import 'package:invoice_generator/main.dart';
import 'package:logger/logger.dart';

/// Firebase service that replaces SQLite functionality with Firestore
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final Connectivity _connectivity = Connectivity();
  final _logger = Logger();

  bool _isNetworkAvailable = true;
  bool _forceOffline = false;
  bool _isInitialized = false; // Track initialization status

  /// Get Firebase Firestore instance (lazy-initialized)
  FirebaseFirestore get firestore {
    if (!FirebaseAvailability.isAvailable) {
      throw Exception('Firebase is not available');
    }
    return FirebaseFirestore.instance;
  }

  /// Get Firebase Auth instance (lazy-initialized)
  FirebaseAuth get auth {
    if (!FirebaseAvailability.isAvailable) {
      throw Exception('Firebase is not available');
    }
    return FirebaseAuth.instance;
  }

  /// Get current user ID - safe version that doesn't throw when Firebase unavailable
  String? get currentUserId {
    if (!FirebaseAvailability.isAvailable) {
      return null; // Firebase not available, return null safely
    }
    try {
      return auth.currentUser?.uid;
    } catch (e) {
      return null; // Firebase not available
    }
  }

  /// Check if Firebase service is properly initialized
  bool get isInitialized => _isInitialized;

  /// Get user-specific collection path
  String get _userPath => 'users/${currentUserId}';

  /// Check if network is available before Firebase operations
  Future<bool> _checkConnectivity() async {
    if (_forceOffline) {
      _logger.i('Firebase operations blocked: forced offline mode');
      return false;
    }

    try {
      final results = await _connectivity.checkConnectivity();
      _isNetworkAvailable = results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none);

      if (!_isNetworkAvailable) {
        _logger.w('Firebase operations blocked: no network connectivity');
      }

      return _isNetworkAvailable;
    } catch (e) {
      _logger.w('Connectivity check failed, assuming offline: $e');
      _isNetworkAvailable = false;
      return false;
    }
  }

  /// Force offline mode to prevent all Firebase operations
  void setForceOffline(bool offline) {
    _forceOffline = offline;
    _logger.i('Firebase force offline mode: $offline');
  }

  /// Initialize the service with connectivity awareness
  Future<void> initialize() async {
    try {
      // Check connectivity before attempting Firebase operations
      final isConnected = await _checkConnectivity();

      if (!isConnected) {
        _logger.i('Skipping Firebase initialization - no network connectivity');
        _isInitialized = false;
        return;
      }

      // Only attempt Firebase operations if we have connectivity
      await firestore.waitForPendingWrites().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _logger.w('Firebase waitForPendingWrites timed out');
          throw Exception('Firebase connection timeout');
        },
      );

      _isInitialized = true;
      _logger.i('FirebaseService initialized successfully');
    } catch (e, s) {
      _logger.e(
          'Failed to initialize FirebaseService (will fall back to local): $e',
          e,
          s);
      _isNetworkAvailable = false;
      _isInitialized = false;
      // Don't rethrow - allow app to continue with local database
    }
  }

  /// Initialize user collections structure with connectivity check
  Future<void> initializeUserCollections() async {
    try {
      // Check connectivity first
      if (!(await _checkConnectivity())) {
        throw Exception(
            'Cannot initialize user collections: no network connectivity');
      }

      if (currentUserId == null) throw Exception('User not authenticated');

      _logger.i('Initializing user collections for $currentUserId...');

      // Add timeout to prevent hanging
      await Future.wait([
        firestore.collection('users').doc(currentUserId).set({
          'userId': currentUserId,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
        firestore.collection('${_userPath}/settings').doc('config').set({
          'initialized': true,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)),
      ]).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Firebase initialization timeout');
        },
      );

      // Create a placeholder document in each main collection to ensure they exist
      // This helps with queries that might fail on empty collections
      final collections = [
        'shipments',
        'drafts',
        'master_shippers',
        'master_consignees',
        'master_product_types',
        'flower_types'
      ];

      for (final collection in collections) {
        final placeholderId = '_placeholder_${collection}';
        await firestore
            .collection('${_userPath}/$collection')
            .doc(placeholderId)
            .set({
          'isPlaceholder': true,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      _logger.i('User collections initialized successfully');
    } catch (e, s) {
      _logger.e('Failed to initialize user collections', e, s);
      rethrow;
    }
  }

  // ========== DATA LOADING ==========

  /// Load all necessary data for the app
  Future<Map<String, dynamic>> loadData() async {
    try {
      _logger.i('Loading app data from Firebase...');

      // Load flower types (items)
      final flowerTypes = await getFlowerTypes();

      // Load recent shipments as items for backward compatibility
      final shipments = await getShipments(limit: 50);
      final items = shipments.map((s) => Item.fromShipment(s.toMap())).toList();

      // Get sign URL from settings
      final signUrl = await getSetting('signURL') ?? 'assets/images/sign.png';

      final data = {
        'items': items,
        'flowerTypes': flowerTypes,
        'signUrl': signUrl,
        // Keep old keys for backward compatibility
        'products': items,
        'customers': <FlowerType>[],
      };

      _logger.i(
          'App data loaded successfully: ${items.length} items, ${flowerTypes.length} flower types');
      return data;
    } catch (e, s) {
      _logger.e('Failed to load app data', e, s);
      throw Exception('Failed to load app data: ${e.toString()}');
    }
  }

  // ========== SHIPMENT OPERATIONS ==========

  /// Wrapper for Firebase operations with connectivity check
  Future<T> _executeFirebaseOperation<T>(Future<T> Function() operation) async {
    if (!(await _checkConnectivity())) {
      throw Exception('Firebase operation blocked: no network connectivity');
    }

    try {
      return await operation().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Firebase operation timed out');
        },
      );
    } catch (e) {
      if (e.toString().contains('Unable to resolve host') ||
          e.toString().contains('UNAVAILABLE') ||
          e.toString().contains('network')) {
        _isNetworkAvailable = false;
        throw Exception('Network connectivity lost during Firebase operation');
      }
      rethrow;
    }
  }

  /// Save a shipment to Firestore with connectivity check
  Future<void> saveShipment(Shipment shipment) async {
    return await _executeFirebaseOperation(() async {
      if (currentUserId == null) throw Exception('User not authenticated');

      // Normalize invoice number and awb to UPPERCASE for consistency
      final normalizedInvoiceNumber =
          shipment.invoiceNumber.toUpperCase().trim();
      final normalizedAwb = shipment.awb.toUpperCase().trim();

      _logger.i('Saving shipment $normalizedInvoiceNumber to Firebase...');

      final shipmentData = {
        ...shipment.toFirebase(),
        'invoiceNumber': normalizedInvoiceNumber,
        'awb': normalizedAwb,
        'userId': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'boxIds': [], // Initialize empty boxIds array
      };

      print(
          '🔥 DEBUG: FirebaseService.saveShipment - Saving to Firestore with invoiceNumber: $normalizedInvoiceNumber (uppercase), awb: $normalizedAwb (uppercase)');

      await firestore
          .collection('${_userPath}/shipments')
          .doc(normalizedInvoiceNumber)
          .set(shipmentData, SetOptions(merge: true));

      _logger.i(
          'Shipment $normalizedInvoiceNumber saved successfully to Firebase');
      print(
          '✅ DEBUG: Shipment saved to Firebase with uppercase invoice number');
    });
  }

  /// Auto-create boxes and products for a shipment with box_ids array update
  Future<void> autoCreateBoxesAndProducts(
    String shipmentId,
    List<Map<String, dynamic>> boxesData,
  ) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      _logger.i(
          'Auto-creating ${boxesData.length} boxes for shipment $shipmentId...');

      final List<String> createdBoxIds = [];

      // Create each box and its products
      for (int i = 0; i < boxesData.length; i++) {
        final boxData = boxesData[i];

        // Generate or use existing box ID
        final boxId = boxData['id'] ??
            '${shipmentId}_box_${i + 1}_${DateTime.now().millisecondsSinceEpoch}';

        // Ensure box has proper shipment reference
        final enhancedBoxData = {
          ...boxData,
          'id': boxId,
          'shipmentId': shipmentId,
          'boxNumber': boxData['boxNumber'] ?? 'Box ${i + 1}',
        };

        // Create the box
        await saveBox(shipmentId, enhancedBoxData);
        createdBoxIds.add(boxId);

        // Auto-create products for this box if they exist
        if (boxData['products'] != null && boxData['products'] is List) {
          final products = boxData['products'] as List<dynamic>;

          _logger.i('Creating ${products.length} products for box $boxId...');
          print('💡 Creating ${products.length} products for box $boxId...');

          for (int j = 0; j < products.length; j++) {
            final productData = products[j];
            if (productData is Map<String, dynamic>) {
              // Generate or use existing product ID - ensure non-empty
              String productId = productData['id'] ?? '';
              if (productId.isEmpty || productId.trim().isEmpty) {
                productId =
                    '${boxId}_product_${j + 1}_${DateTime.now().millisecondsSinceEpoch}';
              }

              final enhancedProductData = {
                ...productData,
                'id': productId,
                'boxId': boxId,
                'shipmentId': shipmentId,
              };

              print(
                  '💡 DEBUG: Saving product with shipmentId=$shipmentId, boxId=$boxId, productId=$productId');
              await saveProduct(boxId, enhancedProductData);
              print('✅ DEBUG: Product saved successfully');
            }
          }
        }
      }

      // Update shipment with boxIds array
      await updateShipment(shipmentId, {
        'boxIds': createdBoxIds,
        'totalBoxes': createdBoxIds.length,
      });

      _logger.i(
          'Auto-created ${createdBoxIds.length} boxes for shipment $shipmentId with IDs: ${createdBoxIds.join(', ')}');
    } catch (e, s) {
      _logger.e('Failed to auto-create boxes and products', e, s);
      throw Exception(
          'Failed to auto-create boxes and products: ${e.toString()}');
    }
  }

  /// Example: Create a complete shipment with sample boxes and products
  Future<String> createSampleShipmentWithBoxes(String baseInvoiceNumber) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      final invoiceNumber =
          '${baseInvoiceNumber}_sample_${DateTime.now().millisecondsSinceEpoch}';

      // Create sample shipment
      final shipment = Shipment(
        invoiceNumber: invoiceNumber,
        shipper: 'Sample Shipper Ltd',
        shipperAddress: '123 Business Street, Trade City',
        consignee: 'Sample Consignee Corp',
        consigneeAddress: '456 Delivery Lane, Target Town',
        clientRef: 'REF001',
        awb: 'AWB$invoiceNumber',
        flightNo: 'FL${DateTime.now().hour}${DateTime.now().minute}',
        flightDate: DateTime.now().add(Duration(days: 1)),
        dischargeAirport: 'Sample Airport (SAM)',
        eta: DateTime.now().add(Duration(days: 2)),
        grossWeight: 1200.50,
        invoiceTitle: 'Sample Shipment Invoice',
        status: 'pending',
      );

      // Save shipment first
      await saveShipment(shipment);

      // Sample boxes with products data
      final sampleBoxesData = [
        {
          'boxNumber': 'Box 1',
          'length': 50.0,
          'width': 30.0,
          'height': 25.0,
          'products': [
            {
              'type': 'ROSES',
              'description': 'Fresh Red Roses - Premium Quality',
              'weight': 10.5,
              'rate': 25.0,
              'flowerType': 'LOOSE FLOWERS',
              'hasStems': true,
              'approxQuantity': 250,
            },
            {
              'type': 'CARNATIONS',
              'description': 'White Carnations - Export Grade',
              'weight': 8.2,
              'rate': 18.0,
              'flowerType': 'TIED GARLANS',
              'hasStems': false,
              'approxQuantity': 150,
            }
          ]
        },
        {
          'boxNumber': 'Box 2',
          'length': 45.0,
          'width': 35.0,
          'height': 20.0,
          'products': [
            {
              'type': 'ORCHIDS',
              'description': 'Exotic Orchids - Mixed Varieties',
              'weight': 12.3,
              'rate': 45.0,
              'flowerType': 'LOOSE FLOWERS',
              'hasStems': true,
              'approxQuantity': 100,
            }
          ]
        }
      ];

      // Auto-create boxes and products
      await autoCreateBoxesAndProducts(invoiceNumber, sampleBoxesData);

      _logger.i('Sample shipment created with ID: $invoiceNumber');
      return invoiceNumber;
    } catch (e, s) {
      _logger.e('Failed to create sample shipment', e, s);
      throw Exception('Failed to create sample shipment: ${e.toString()}');
    }
  }

  /// Get all shipments
  Future<List<Shipment>> getShipments({String? status, int limit = 50}) async {
    try {
      if (currentUserId == null) return [];

      Query query = firestore.collection('${_userPath}/shipments');

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      final snapshot = await query.get();
      final shipments = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Shipment.fromFirebase(data);
      }).toList();

      return shipments;
    } catch (e, s) {
      _logger.e('Failed to get shipments', e, s);
      return [];
    }
  }

  /// Get all shipments from global collection (fallback for when user collection is empty)
  Future<List<Shipment>> getGlobalShipments(
      {String? status, int limit = 50}) async {
    try {
      Query query = firestore.collection('shipments');

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      query = query.orderBy('createdAt', descending: true).limit(limit);

      final snapshot = await query.get();
      final shipments = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Shipment.fromFirebase(data);
      }).toList();

      return shipments;
    } catch (e, s) {
      _logger.e('Failed to get global shipments', e, s);
      return [];
    }
  }

  /// Get shipment by ID
  Future<Shipment?> getShipment(String invoiceNumber) async {
    try {
      if (currentUserId == null) return null;

      final doc = await firestore
          .collection('${_userPath}/shipments')
          .doc(invoiceNumber)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      return Shipment.fromFirebase(data);
    } catch (e, s) {
      _logger.e('Failed to get shipment $invoiceNumber', e, s);
      return null;
    }
  }

  /// Update shipment
  Future<void> updateShipment(
      String invoiceNumber, Map<String, dynamic> updates) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      // Normalize invoice number to UPPERCASE for Firestore document ID
      final normalizedInvoiceNumber = invoiceNumber.toUpperCase().trim();

      // Convert updates to data, keeping camelCase keys
      final data = <String, dynamic>{};
      updates.forEach((key, value) {
        // UPPERCASE normalize awb if present
        if (key == 'awb') {
          data[key] = value?.toString().toUpperCase().trim() ?? value;
        } else {
          data[key] = value;
        }
      });

      // Add server timestamp
      data['updatedAt'] = FieldValue.serverTimestamp();

      print(
          '🔥 DEBUG: FirebaseService.updateShipment - invoiceNumber: $normalizedInvoiceNumber (uppercase)');
      print('🔥 DEBUG: Original updates keys: ${updates.keys.toList()}');
      print('🔥 DEBUG: Data keys: ${data.keys.toList()}');
      print('🔥 DEBUG: awb value: ${data['awb']} (uppercased if present)');

      await firestore
          .collection('${_userPath}/shipments')
          .doc(normalizedInvoiceNumber)
          .set(data, SetOptions(merge: true));

      _logger.i('Shipment $invoiceNumber updated successfully in Firebase');
      print(
          '✅ DEBUG: Shipment $invoiceNumber updated in Firebase successfully');
    } catch (e, s) {
      _logger.e('Failed to update shipment $invoiceNumber in Firebase', e, s);
      print(
          '❌ DEBUG: Failed to update shipment $invoiceNumber in Firebase: $e');
      throw Exception('Failed to update shipment: ${e.toString()}');
    }
  }

  /// Delete shipment
  Future<void> deleteShipment(String invoiceNumber) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      // First delete all boxes and products for this shipment
      await deleteAllBoxesForShipment(invoiceNumber);

      // Then delete shipment document
      await firestore
          .collection('${_userPath}/shipments')
          .doc(invoiceNumber)
          .delete();

      _logger.i('Shipment $invoiceNumber deleted successfully');
    } catch (e, s) {
      _logger.e('Failed to delete shipment $invoiceNumber', e, s);
      throw Exception('Failed to delete shipment: ${e.toString()}');
    }
  }

  /// Delete all boxes and products for a shipment (used during updates)
  Future<void> deleteAllBoxesForShipment(String shipmentId) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      _logger.i('Deleting all boxes for shipment $shipmentId from Firebase');
      print(
          '🗑️ DEBUG: FirebaseService.deleteAllBoxesForShipment - shipmentId: $shipmentId');

      // Get all box documents
      final boxesSnapshot = await firestore
          .collection('${_userPath}/shipments/$shipmentId/boxes')
          .get();

      print('🗑️ DEBUG: Found ${boxesSnapshot.docs.length} boxes to delete');

      // Delete each box and its products in batch
      final batch = firestore.batch();

      for (final boxDoc in boxesSnapshot.docs) {
        print('🗑️ DEBUG: Processing box ${boxDoc.id} for deletion');

        // Delete all products for this box FIRST using individual deletions
        final productsPath =
            '${_userPath}/shipments/$shipmentId/boxes/${boxDoc.id}/products';
        print('🗑️ DEBUG: Products path: $productsPath');

        try {
          final productsSnapshot =
              await firestore.collection(productsPath).get();

          print(
              '🗑️ DEBUG: Box ${boxDoc.id} has ${productsSnapshot.docs.length} products');

          // Delete products individually to ensure they're removed
          for (final productDoc in productsSnapshot.docs) {
            print('🗑️ DEBUG: Deleting product ${productDoc.id} individually');
            try {
              await productDoc.reference.delete();
              print('🗑️ DEBUG: Successfully deleted product ${productDoc.id}');
            } catch (e) {
              print('❌ DEBUG: Error deleting product ${productDoc.id}: $e');
            }
          }
          print(
              '🗑️ DEBUG: Individual product deletions completed for box ${boxDoc.id}');
        } catch (e) {
          print('❌ DEBUG: Error getting products for box ${boxDoc.id}: $e');
          // Continue with box deletion even if products query fails
        }

        // Add the box to batch deletion
        print('🗑️ DEBUG: Adding box ${boxDoc.id} to deletion batch');
        batch.delete(boxDoc.reference);
      }

      // Execute the batch delete
      try {
        await batch.commit();
        print(
            '✅ DEBUG: Batch delete committed successfully for shipment $shipmentId');
      } catch (e) {
        print('❌ DEBUG: Error committing batch delete: $e');
        throw e; // Re-throw to handle in outer catch
      }

      print('✅ DEBUG: Deleted all boxes and products for shipment $shipmentId');

      // Update shipment to remove boxIds and totalBoxes
      await firestore
          .collection('${_userPath}/shipments')
          .doc(shipmentId)
          .update({
        'boxIds': FieldValue.delete(),
        'totalBoxes': 0,
      });

      print('✅ DEBUG: Updated shipment $shipmentId to clear box references');

      _logger.i(
          'Successfully deleted ${boxesSnapshot.docs.length} boxes for shipment $shipmentId');
    } catch (e, s) {
      _logger.e('Failed to delete boxes for shipment $shipmentId', e, s);
      throw Exception('Failed to delete boxes: ${e.toString()}');
    }
  }

  /// Update shipment status
  Future<void> updateShipmentStatus(String shipmentId, String status) async {
    try {
      await updateShipment(shipmentId, {'status': status});
      _logger.i('Shipment $shipmentId status updated to $status');
    } catch (e, s) {
      _logger.e('Failed to update shipment status', e, s);
      throw Exception('Failed to update shipment status: ${e.toString()}');
    }
  }

  // ========== BOX OPERATIONS ==========

  /// Save a box to a shipment
  Future<String> saveBox(
      String shipmentId, Map<String, dynamic> boxData) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      final boxId =
          boxData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();

      final box = ShipmentBox(
        id: boxId,
        shipmentId: shipmentId,
        boxNumber: boxData['boxNumber'] ?? 'Box 1',
        length: (boxData['length'] ?? 0.0).toDouble(),
        width: (boxData['width'] ?? 0.0).toDouble(),
        height: (boxData['height'] ?? 0.0).toDouble(),
      );

      final boxDataMap = {
        ...box.toMap(),
        'userId': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await firestore
          .collection('${_userPath}/shipments/$shipmentId/boxes')
          .doc(boxId)
          .set(boxDataMap, SetOptions(merge: true));

      _logger.i('Box $boxId saved successfully');
      return boxId;
    } catch (e, s) {
      _logger.e('Failed to save box', e, s);
      throw Exception('Failed to save box: ${e.toString()}');
    }
  }

  /// Get boxes for a shipment
  Future<List<ShipmentBox>> getBoxesForShipment(String shipmentId) async {
    try {
      if (currentUserId == null) return [];

      final snapshot = await firestore
          .collection('${_userPath}/shipments/$shipmentId/boxes')
          .orderBy('createdAt')
          .get();

      final boxes = <ShipmentBox>[];

      for (final doc in snapshot.docs) {
        final boxData = doc.data();
        final box = ShipmentBox.fromMap(doc.id, boxData);

        // Load products for this box
        final products = await getProductsForBox(shipmentId, box.id);
        final boxWithProducts = box.copyWith(products: products);
        boxes.add(boxWithProducts);
      }

      return boxes;
    } catch (e, s) {
      _logger.e('Failed to get boxes for shipment $shipmentId', e, s);
      return [];
    }
  }

  // ========== PRODUCT OPERATIONS ==========

  /// Save a product to a box
  Future<String> saveProduct(
      String boxId, Map<String, dynamic> productData) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      // Get shipmentId from productData (added by data service)
      final shipmentId = productData['shipmentId'] ?? '';
      if (shipmentId.isEmpty) {
        throw Exception('shipmentId is required for Firebase product save');
      }

      // Generate productId, ensuring it's never empty
      String productId = productData['id'] ?? '';
      if (productId.isEmpty || productId.trim().isEmpty) {
        productId =
            '${DateTime.now().millisecondsSinceEpoch}_${shipmentId}_$boxId';
        _logger.w('Product ID was empty, generated: $productId');
      }

      _logger.i(
          'DEBUG: Saving product with shipmentId=$shipmentId, boxId=$boxId, productId=$productId');

      final product = ShipmentProduct(
        id: productId,
        boxId: boxId,
        type: productData['type'] ?? '',
        description: productData['description'] ??
            '${productData['flowerType'] ?? 'LOOSE FLOWERS'}${productData['hasStems'] == true ? ', WITH STEMS' : ', NO STEMS'} - APPROX ${productData['approxQuantity'] ?? 0} NOS',
        flowerType: productData['flowerType'] ?? '',
        hasStems: productData['hasStems'] ?? false,
        weight: (productData['weight'] ?? 0.0).toDouble(),
        rate: (productData['rate'] ?? 0.0).toDouble(),
        approxQuantity: (productData['approxQuantity'] ?? 0).toInt(),
      );

      final productDataMap = {
        ...product.toFirebase(),
        'userId': currentUserId,
      };

      await firestore
          .collection(
              '${_userPath}/shipments/$shipmentId/boxes/$boxId/products')
          .doc(productId)
          .set(productDataMap, SetOptions(merge: true));

      _logger.i('Product $productId saved successfully');
      return productId;
    } catch (e, s) {
      _logger.e('Failed to save product', e, s);
      throw Exception('Failed to save product: ${e.toString()}');
    }
  }

  /// Get products for a box
  Future<List<ShipmentProduct>> getProductsForBox(
      String shipmentId, String boxId) async {
    try {
      if (currentUserId == null) return [];

      final snapshot = await firestore
          .collection(
              '${_userPath}/shipments/$shipmentId/boxes/$boxId/products')
          .orderBy('createdAt')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ShipmentProduct.fromMap(doc.id, data);
      }).toList();
    } catch (e, s) {
      _logger.e('Failed to get products for box $boxId', e, s);
      return [];
    }
  }

  // ========== DRAFT OPERATIONS ==========

  /// Save draft
  Future<String> saveDraft(Map<String, dynamic> draftData) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      _logger.i('Saving draft to Firebase...');

      final draftId = DateTime.now().millisecondsSinceEpoch.toString();

      final draft = {
        'id': draftId,
        'invoiceNumber': draftData['invoiceNumber'] ?? '',
        'shipperName': draftData['shipper'] ?? '',
        'consigneeName': draftData['consignee'] ?? '',
        'draftData': jsonEncode(draftData), // Store complete draft as JSON
        'status': 'draft',
        'userId': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await firestore.collection('${_userPath}/drafts').doc(draftId).set(draft);

      _logger.i('Draft $draftId saved successfully');
      return draftId;
    } catch (e, s) {
      _logger.e('Failed to save draft', e, s);
      throw Exception('Failed to save draft: ${e.toString()}');
    }
  }

  /// Get all drafts
  Future<List<Map<String, dynamic>>> getDrafts() async {
    try {
      if (currentUserId == null) return [];

      final snapshot = await firestore
          .collection('${_userPath}/drafts')
          .orderBy('updatedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        try {
          final draftData = jsonDecode(data['draftData'] ?? '{}');
          return {
            'id': doc.id,
            'invoiceNumber': data['invoiceNumber'],
            'shipperName': data['shipperName'],
            'consigneeName': data['consigneeName'],
            'status': data['status'],
            'createdAt': data['createdAt'],
            'updatedAt': data['updatedAt'],
            'draftData': draftData,
          };
        } catch (e) {
          _logger.w('Failed to parse draft data for ${doc.id}');
          return data;
        }
      }).toList();
    } catch (e, s) {
      _logger.e('Failed to get drafts', e, s);
      return [];
    }
  }

  /// Delete draft
  Future<void> deleteDraft(String draftId) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      await firestore.collection('${_userPath}/drafts').doc(draftId).delete();

      _logger.i('Draft $draftId deleted successfully');
    } catch (e, s) {
      _logger.e('Failed to delete draft $draftId', e, s);
      throw Exception('Failed to delete draft: ${e.toString()}');
    }
  }

  /// Convert draft to shipment
  /// Publish draft as shipment with auto box/product creation
  Future<String> publishDraft(String draftId) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      _logger.i('Publishing draft $draftId to shipment...');

      final drafts = await getDrafts();
      final draft = drafts.firstWhere((d) => d['id'] == draftId);
      final draftData = draft['draftData'] as Map<String, dynamic>;

      // Create shipment from draft
      final shipment = Shipment(
        invoiceNumber: draftData['invoiceNumber'] ??
            draftData['awb'] ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        shipper: draftData['shipper'] ?? '',
        consignee: draftData['consignee'] ?? '',
        awb: draftData['awb'] ?? '',
        flightNo: draftData['flightNo'] ?? '',
        flightDate: DateTime.tryParse(draftData['flightDate'] ?? '') ??
            DateTime.now().add(Duration(days: 1)),
        dischargeAirport: draftData['dischargeAirport'] ?? '',
        eta: DateTime.tryParse(draftData['eta'] ?? '') ??
            DateTime.now().add(Duration(days: 1)),
        grossWeight: double.tryParse(draftData['grossWeight'] ?? '0') ?? 0.0,
        invoiceTitle: draftData['invoiceTitle'] ?? '',
        status: 'pending',
      );

      // Save shipment first
      await saveShipment(shipment);

      // Auto-create boxes and products if they exist in draft
      if (draftData['boxes'] != null && draftData['boxes'] is List) {
        final boxesData = draftData['boxes'] as List<dynamic>;
        final boxesList = boxesData
            .map((box) =>
                box is Map<String, dynamic> ? box : <String, dynamic>{})
            .toList();

        if (boxesList.isNotEmpty) {
          _logger.i('Creating ${boxesList.length} boxes from draft data');
          await autoCreateBoxesAndProducts(shipment.invoiceNumber, boxesList);
        } else {
          _logger
              .i('Draft contains empty boxes list - no boxes will be created');
        }
      } else {
        _logger.i('No boxes data found in draft - no boxes will be created');
      }

      // Delete the draft
      await deleteDraft(draftId);

      _logger
          .i('Draft $draftId published as shipment ${shipment.invoiceNumber}');
      return shipment.invoiceNumber;
    } catch (e, s) {
      _logger.e('Failed to publish draft $draftId', e, s);
      throw Exception('Failed to publish draft: ${e.toString()}');
    }
  }

  // ========== MASTER DATA OPERATIONS ==========

  // ---------- MASTER SHIPPERS ----------

  /// Get all master shippers
  Future<List<MasterShipper>> getMasterShippers() async {
    try {
      if (currentUserId == null) return [];

      final snapshot = await firestore
          .collection('${_userPath}/master_shippers')
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return MasterShipper.fromMap(data);
      }).toList();
    } catch (e, s) {
      _logger.e('Failed to get master shippers', e, s);
      return [];
    }
  }

  /// Save a master shipper
  Future<String> saveMasterShipper(MasterShipper shipper) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      final data = {
        ...shipper.toFirebase(),
        'userId': currentUserId,
      };

      await firestore
          .collection('${_userPath}/master_shippers')
          .doc(shipper.id)
          .set(data, SetOptions(merge: true));

      _logger.i('Master shipper saved: ${shipper.id}');
      return shipper.id;
    } catch (e, s) {
      _logger.e('Failed to save master shipper', e, s);
      rethrow;
    }
  }

  /// Update a master shipper
  Future<void> updateMasterShipper(
      String id, Map<String, dynamic> updates) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      final data = {
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await firestore
          .collection('${_userPath}/master_shippers')
          .doc(id)
          .update(data);

      _logger.i('Master shipper updated: $id');
    } catch (e, s) {
      _logger.e('Failed to update master shipper', e, s);
      rethrow;
    }
  }

  /// Delete a master shipper
  Future<void> deleteMasterShipper(String id) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      await firestore
          .collection('${_userPath}/master_shippers')
          .doc(id)
          .delete();

      _logger.i('Master shipper deleted: $id');
    } catch (e, s) {
      _logger.e('Failed to delete master shipper', e, s);
      rethrow;
    }
  }

  // ---------- MASTER CONSIGNEES ----------

  /// Get all master consignees
  Future<List<MasterConsignee>> getMasterConsignees() async {
    try {
      if (currentUserId == null) return [];

      final snapshot = await firestore
          .collection('${_userPath}/master_consignees')
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return MasterConsignee.fromMap(data);
      }).toList();
    } catch (e, s) {
      _logger.e('Failed to get master consignees', e, s);
      return [];
    }
  }

  /// Save a master consignee
  Future<String> saveMasterConsignee(MasterConsignee consignee) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      final data = {
        ...consignee.toFirebase(),
        'userId': currentUserId,
      };

      await firestore
          .collection('${_userPath}/master_consignees')
          .doc(consignee.id)
          .set(data, SetOptions(merge: true));

      _logger.i('Master consignee saved: ${consignee.id}');
      return consignee.id;
    } catch (e, s) {
      _logger.e('Failed to save master consignee', e, s);
      rethrow;
    }
  }

  /// Update a master consignee
  Future<void> updateMasterConsignee(
      String id, Map<String, dynamic> updates) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      final data = {
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await firestore
          .collection('${_userPath}/master_consignees')
          .doc(id)
          .update(data);

      _logger.i('Master consignee updated: $id');
    } catch (e, s) {
      _logger.e('Failed to update master consignee', e, s);
      rethrow;
    }
  }

  /// Delete a master consignee
  Future<void> deleteMasterConsignee(String id) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      await firestore
          .collection('${_userPath}/master_consignees')
          .doc(id)
          .delete();

      _logger.i('Master consignee deleted: $id');
    } catch (e, s) {
      _logger.e('Failed to delete master consignee', e, s);
      rethrow;
    }
  }

  // ---------- MASTER PRODUCT TYPES ----------

  /// Get all master product types
  Future<List<MasterProductType>> getMasterProductTypes() async {
    try {
      if (currentUserId == null) return [];

      final snapshot = await firestore
          .collection('${_userPath}/master_product_types')
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return MasterProductType.fromMap(data);
      }).toList();
    } catch (e, s) {
      _logger.e('Failed to get master product types', e, s);
      return [];
    }
  }

  /// Save a master product type
  Future<String> saveMasterProductType(MasterProductType productType) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      final data = {
        ...productType.toFirebase(),
        'userId': currentUserId,
      };

      await firestore
          .collection('${_userPath}/master_product_types')
          .doc(productType.id)
          .set(data, SetOptions(merge: true));

      _logger.i('Master product type saved: ${productType.id}');
      return productType.id;
    } catch (e, s) {
      _logger.e('Failed to save master product type', e, s);
      rethrow;
    }
  }

  /// Update a master product type
  Future<void> updateMasterProductType(
      String id, Map<String, dynamic> updates) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      final data = {
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await firestore
          .collection('${_userPath}/master_product_types')
          .doc(id)
          .update(data);

      _logger.i('Master product type updated: $id');
    } catch (e, s) {
      _logger.e('Failed to update master product type', e, s);
      rethrow;
    }
  }

  /// Delete a master product type
  Future<void> deleteMasterProductType(String id) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      await firestore
          .collection('${_userPath}/master_product_types')
          .doc(id)
          .delete();

      _logger.i('Master product type deleted: $id');
    } catch (e, s) {
      _logger.e('Failed to delete master product type', e, s);
      rethrow;
    }
  }

  // ========== FLOWER TYPES ==========

  /// Get all flower types
  Future<List<FlowerType>> getFlowerTypes() async {
    try {
      if (currentUserId == null) return [];

      final snapshot = await firestore
          .collection('${_userPath}/flower_types')
          .orderBy('flowerName')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return FlowerType(
          id: doc.id,
          flowerName: data['flowerName'] ?? data['flower_name'] ?? '',
          description: data['description'] ?? '',
        );
      }).toList();
    } catch (e, s) {
      _logger.e('Failed to get flower types', e, s);
      return [];
    }
  }

  /// Save a flower type to Firebase
  Future<String> saveFlowerType(FlowerType flowerType) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      final data = {
        'flowerName': flowerType.flowerName,
        'description': flowerType.description,
        'userId': currentUserId,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await firestore
          .collection('${_userPath}/flower_types')
          .doc(flowerType.id)
          .set(data, SetOptions(merge: true));

      _logger.i('Flower type saved: ${flowerType.id}');
      return flowerType.id;
    } catch (e, s) {
      _logger.e('Failed to save flower type', e, s);
      rethrow;
    }
  }

  /// Update a flower type in Firebase
  Future<void> updateFlowerType(String id, Map<String, dynamic> updates) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      final data = Map<String, dynamic>.from(updates);
      // Map local column names to Firebase field names if necessary
      if (data.containsKey('flower_name')) {
        data['flowerName'] = data.remove('flower_name');
      }

      data['updatedAt'] = FieldValue.serverTimestamp();

      await firestore
          .collection('${_userPath}/flower_types')
          .doc(id)
          .update(data);

      _logger.i('Flower type updated: $id');
    } catch (e, s) {
      _logger.e('Failed to update flower type', e, s);
      rethrow;
    }
  }

  /// Delete a flower type from Firebase
  Future<void> deleteFlowerType(String id) async {
    try {
      if (currentUserId == null) throw Exception('User not authenticated');

      await firestore.collection('${_userPath}/flower_types').doc(id).delete();

      _logger.i('Flower type deleted: $id');
    } catch (e, s) {
      _logger.e('Failed to delete flower type', e, s);
      rethrow;
    }
  }

  // ========== SETTINGS ==========

  /// Get setting value by key
  Future<String?> getSetting(String key) async {
    try {
      if (!FirebaseAvailability.isAvailable) {
        return null; // Firebase not available, return null safely
      }
      if (currentUserId == null) return null;

      final doc = await firestore
          .collection('${_userPath}/settings')
          .doc('config')
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      return data[key];
    } catch (e, s) {
      _logger.e('Failed to get setting $key', e, s);
      return null;
    }
  }

  /// Set setting value
  Future<void> setSetting(String key, String value) async {
    try {
      if (!FirebaseAvailability.isAvailable) {
        throw Exception('Firebase is not available');
      }
      if (currentUserId == null) throw Exception('User not authenticated');

      await firestore.collection('${_userPath}/settings').doc('config').set({
        key: value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, s) {
      _logger.e('Failed to set setting $key', e, s);
      throw Exception('Failed to set setting: ${e.toString()}');
    }
  }

  // ========== STATISTICS ==========

  /// Get database statistics
  Future<Map<String, dynamic>> getStats() async {
    try {
      if (currentUserId == null) return {};

      final shipmentsCount =
          (await firestore.collection('${_userPath}/shipments').count().get())
              .count;

      final boxesCount = (await firestore
              .collectionGroup('boxes')
              .where('userId', isEqualTo: currentUserId)
              .count()
              .get())
          .count;

      final productsCount = (await firestore
              .collectionGroup('products')
              .where('userId', isEqualTo: currentUserId)
              .count()
              .get())
          .count;

      final draftsCount =
          (await firestore.collection('${_userPath}/drafts').count().get())
              .count;

      return {
        'shipments': shipmentsCount,
        'boxes': boxesCount,
        'products': productsCount,
        'drafts': draftsCount,
      };
    } catch (e, s) {
      _logger.e('Failed to get database stats', e, s);
      return {};
    }
  }

  /// Get shipment statistics
  Future<Map<String, dynamic>> getShipmentStats() async {
    try {
      if (currentUserId == null) return {};

      final stats = await getStats();

      // Get shipments by status
      final pendingShipments = await getShipments(status: 'pending');
      final inTransitShipments = await getShipments(status: 'in_transit');
      final deliveredShipments = await getShipments(status: 'delivered');
      final cancelledShipments = await getShipments(status: 'cancelled');

      // Calculate total amount
      final allShipments = await getShipments();
      final totalAmount =
          allShipments.fold(0.0, (sum, shipment) => sum + shipment.totalAmount);

      return {
        'total': stats['shipments'] ?? 0,
        'byStatus': {
          'pending': pendingShipments.length,
          'in_transit': inTransitShipments.length,
          'delivered': deliveredShipments.length,
          'cancelled': cancelledShipments.length,
        },
        'totalAmount': totalAmount,
        'recentActivity': allShipments.take(10).map((s) => s.toMap()).toList(),
      };
    } catch (e, s) {
      _logger.e('Failed to get shipment statistics', e, s);
      return {};
    }
  }

  // ========== SEARCH ==========

  /// Search shipments
  Future<List<Shipment>> searchShipments(String query) async {
    try {
      if (currentUserId == null) return [];

      // Note: Firestore doesn't support full-text search natively
      // This is a basic implementation using where clauses
      final queryLower = query.toLowerCase();

      final snapshot = await firestore
          .collection('${_userPath}/shipments')
          .orderBy('createdAt', descending: true)
          .get();

      final shipments = snapshot.docs.map((doc) {
        final data = doc.data();
        return Shipment.fromFirebase(data);
      }).where((shipment) {
        return shipment.shipper.toLowerCase().contains(queryLower) ||
            shipment.consignee.toLowerCase().contains(queryLower) ||
            shipment.awb.toLowerCase().contains(queryLower) ||
            shipment.invoiceTitle.toLowerCase().contains(queryLower);
      }).toList();

      return shipments;
    } catch (e, s) {
      _logger.e('Failed to search shipments', e, s);
      return [];
    }
  }

  /// Search master data by name
  Future<List<Map<String, dynamic>>> searchMasterData(
      String collection, String searchTerm) async {
    try {
      if (currentUserId == null) return [];

      final snapshot = await firestore
          .collection('${_userPath}/$collection')
          .orderBy('name')
          .get();

      return snapshot.docs.map((doc) => doc.data()).where((data) {
        final name = (data['name'] ?? '').toString().toLowerCase();
        return name.contains(searchTerm.toLowerCase());
      }).toList();
    } catch (e, s) {
      _logger.e('Failed to search master data in $collection', e, s);
      return [];
    }
  }

  // ========== LEGACY METHODS FOR BACKWARD COMPATIBILITY ==========

  /// Fetches the initial data (items, flower types, etc.) from Firestore.
  Future<Map<String, dynamic>> fetchData() async => loadData();

  /// Saves an invoice to Firestore (converts to shipment)
  Future<void> saveInvoice(invoice) async {
    // This method is kept for backward compatibility
    // Implementation would need to be updated based on invoice structure
    throw UnimplementedError('Use saveShipment instead');
  }

  // ========== BOX OPERATIONS ==========

  /// Update a box in Firebase
  Future<void> updateBox(String boxId, Map<String, dynamic> boxData,
      [String? shipmentId]) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      print(
          '📝 FIREBASE: Starting updateBox for boxId: $boxId, shipmentId: $shipmentId');
      print('📝 FIREBASE: Using _userPath: $_userPath');

      // If shipmentId not provided, search for the box
      if (shipmentId == null) {
        print('🔍 FIREBASE: Searching for shipment containing box $boxId...');
        final shipmentsSnapshot =
            await firestore.collection('$_userPath/shipments').get();

        print(
            '🔍 FIREBASE: Found ${shipmentsSnapshot.docs.length} shipments to search');

        for (final shipmentDoc in shipmentsSnapshot.docs) {
          print(
              '🔍 FIREBASE: Checking shipment ${shipmentDoc.id} for box $boxId');
          final boxPath = '$_userPath/shipments/${shipmentDoc.id}/boxes';
          print('🔍 FIREBASE: Checking path: $boxPath');

          final boxDoc = await firestore.collection(boxPath).doc(boxId).get();
          if (boxDoc.exists) {
            shipmentId = shipmentDoc.id;
            print('🔍 FIREBASE: Found box $boxId in shipment $shipmentId');
            break;
          }
        }
      }

      if (shipmentId == null) {
        print('❌ FIREBASE: Could not find shipment for box $boxId');
        throw Exception('Could not find shipment for box $boxId');
      }

      final boxRef = firestore
          .collection('$_userPath/shipments/$shipmentId/boxes')
          .doc(boxId);
      print(
          '📝 FIREBASE: Updating box at path: $_userPath/shipments/$shipmentId/boxes/$boxId');

      await boxRef.update({
        ...boxData,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _logger.i('Box updated in Firebase: $boxId in shipment $shipmentId');
      print('✅ FIREBASE: Successfully updated box $boxId');
    } catch (e, s) {
      print('❌ FIREBASE: Failed to update box $boxId: $e');
      _logger.e('Failed to update box in Firebase', e, s);
      rethrow;
    }
  }

  /// Delete a box from Firebase
  Future<void> deleteBox(String boxId, [String? shipmentId]) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      print(
          '🗑️ FIREBASE: Starting deleteBox for boxId: $boxId, shipmentId: $shipmentId');
      print('🗑️ FIREBASE: Using _userPath: $_userPath');

      // If shipmentId not provided, try to find it by searching through shipments
      if (shipmentId == null) {
        print('🔍 FIREBASE: Searching for shipment containing box $boxId...');
        final shipmentsSnapshot =
            await firestore.collection('$_userPath/shipments').get();

        print(
            '🔍 FIREBASE: Found ${shipmentsSnapshot.docs.length} shipments to search');

        for (final shipmentDoc in shipmentsSnapshot.docs) {
          print(
              '🔍 FIREBASE: Checking shipment ${shipmentDoc.id} for box $boxId');
          final boxPath = '$_userPath/shipments/${shipmentDoc.id}/boxes';
          print('🔍 FIREBASE: Checking path: $boxPath');

          final boxDoc = await firestore.collection(boxPath).doc(boxId).get();
          if (boxDoc.exists) {
            shipmentId = shipmentDoc.id;
            print('🔍 FIREBASE: Found box $boxId in shipment $shipmentId');
            break;
          }
        }
      }

      if (shipmentId == null) {
        print('❌ FIREBASE: Could not find shipment for box $boxId');
        throw Exception('Could not find shipment for box $boxId');
      }

      print('🗑️ FIREBASE: Deleting box $boxId from shipment $shipmentId');

      // First delete all products for this box BEFORE deleting the box
      final productsPath =
          '$_userPath/shipments/$shipmentId/boxes/$boxId/products';
      print('🗑️ FIREBASE: Deleting products from path: $productsPath');
      print(
          '🗑️ FIREBASE: Full collection path: $_userPath/shipments/$shipmentId/boxes/$boxId/products');

      try {
        final productsSnapshot = await firestore.collection(productsPath).get();
        print(
            '🗑️ FIREBASE: Found ${productsSnapshot.docs.length} products to delete');

        if (productsSnapshot.docs.isNotEmpty) {
          // Delete products individually to ensure they're removed
          for (final doc in productsSnapshot.docs) {
            print('🗑️ FIREBASE: Deleting product ${doc.id} individually');
            try {
              await doc.reference.delete();
              print('🗑️ FIREBASE: Successfully deleted product ${doc.id}');
            } catch (e) {
              print('❌ FIREBASE: Error deleting product ${doc.id}: $e');
            }
          }
          print('🗑️ FIREBASE: Individual product deletions completed');
        } else {
          print('🗑️ FIREBASE: No products found to delete for box $boxId');
        }
      } catch (e) {
        print('❌ FIREBASE: Error getting products for box $boxId: $e');
        // Continue with box deletion even if products query fails
      }

      // Now delete the box document
      final boxPath = '$_userPath/shipments/$shipmentId/boxes';
      print('🗑️ FIREBASE: Box deletion path: $boxPath/$boxId');

      final boxRef = firestore.collection(boxPath).doc(boxId);
      await boxRef.delete();
      print('🗑️ FIREBASE: Box document deleted successfully');

      _logger.i(
          'Box and its products deleted from Firebase: $boxId from shipment $shipmentId');
      print(
          '✅ FIREBASE: Successfully deleted box $boxId and all its products from Firebase');
    } catch (e, s) {
      print('❌ FIREBASE: Failed to delete box $boxId: $e');
      _logger.e('Failed to delete box from Firebase', e, s);
      rethrow;
    }
  }

  // ========== PRODUCT OPERATIONS ==========

  /// Update a product in Firebase
  Future<void> updateProduct(String productId, Map<String, dynamic> productData,
      [String? shipmentId, String? boxId]) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      print(
          '📝 FIREBASE: Starting updateProduct for productId: $productId, shipmentId: $shipmentId, boxId: $boxId');
      print('📝 FIREBASE: Using _userPath: $_userPath');

      // If shipmentId and boxId not provided, search for the product
      if (shipmentId == null || boxId == null) {
        print('🔍 FIREBASE: Searching for product $productId location...');
        final shipmentsSnapshot =
            await firestore.collection('$_userPath/shipments').get();

        print(
            '🔍 FIREBASE: Found ${shipmentsSnapshot.docs.length} shipments to search');

        bool found = false;
        for (final shipmentDoc in shipmentsSnapshot.docs) {
          print('🔍 FIREBASE: Checking shipment ${shipmentDoc.id}');
          final boxesPath = '$_userPath/shipments/${shipmentDoc.id}/boxes';
          final boxesSnapshot = await firestore.collection(boxesPath).get();

          print(
              '🔍 FIREBASE: Found ${boxesSnapshot.docs.length} boxes in shipment ${shipmentDoc.id}');

          for (final boxDoc in boxesSnapshot.docs) {
            final productsPath =
                '$_userPath/shipments/${shipmentDoc.id}/boxes/${boxDoc.id}/products';
            print('🔍 FIREBASE: Checking products path: $productsPath');

            final productDoc =
                await firestore.collection(productsPath).doc(productId).get();
            if (productDoc.exists) {
              shipmentId = shipmentDoc.id;
              boxId = boxDoc.id;
              found = true;
              print(
                  '🔍 FIREBASE: Found product $productId in shipment $shipmentId, box $boxId');
              break;
            }
          }
          if (found) break;
        }
      }

      if (shipmentId == null || boxId == null) {
        print('❌ FIREBASE: Could not find location for product $productId');
        throw Exception('Could not find location for product $productId');
      }

      final productRef = firestore
          .collection('$_userPath/shipments/$shipmentId/boxes/$boxId/products')
          .doc(productId);
      print(
          '📝 FIREBASE: Updating product at path: $_userPath/shipments/$shipmentId/boxes/$boxId/products/$productId');

      await productRef.update({
        ...productData,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _logger.i(
          'Product updated in Firebase: $productId in shipment $shipmentId, box $boxId');
      print('✅ FIREBASE: Successfully updated product $productId');
    } catch (e, s) {
      print('❌ FIREBASE: Failed to update product $productId: $e');
      _logger.e('Failed to update product in Firebase', e, s);
      rethrow;
    }
  }

  /// Delete a product from Firebase
  Future<void> deleteProduct(String productId,
      [String? shipmentId, String? boxId]) async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      print(
          '🗑️ FIREBASE: Starting deleteProduct for productId: $productId, shipmentId: $shipmentId, boxId: $boxId');
      print('🗑️ FIREBASE: Using _userPath: $_userPath');

      // If shipmentId and boxId not provided, search for the product
      if (shipmentId == null || boxId == null) {
        print('🔍 FIREBASE: Searching for product $productId location...');
        final shipmentsSnapshot =
            await firestore.collection('$_userPath/shipments').get();

        print(
            '🔍 FIREBASE: Found ${shipmentsSnapshot.docs.length} shipments to search');

        bool found = false;
        for (final shipmentDoc in shipmentsSnapshot.docs) {
          print('🔍 FIREBASE: Checking shipment ${shipmentDoc.id}');
          final boxesPath = '$_userPath/shipments/${shipmentDoc.id}/boxes';
          final boxesSnapshot = await firestore.collection(boxesPath).get();

          print(
              '🔍 FIREBASE: Found ${boxesSnapshot.docs.length} boxes in shipment ${shipmentDoc.id}');

          for (final boxDoc in boxesSnapshot.docs) {
            final productsPath =
                '$_userPath/shipments/${shipmentDoc.id}/boxes/${boxDoc.id}/products';
            print('🔍 FIREBASE: Checking products path: $productsPath');

            final productDoc =
                await firestore.collection(productsPath).doc(productId).get();
            if (productDoc.exists) {
              shipmentId = shipmentDoc.id;
              boxId = boxDoc.id;
              found = true;
              print(
                  '🔍 FIREBASE: Found product $productId in shipment $shipmentId, box $boxId');
              break;
            }
          }
          if (found) break;
        }
      }

      if (shipmentId == null || boxId == null) {
        print('❌ FIREBASE: Could not find location for product $productId');
        throw Exception('Could not find location for product $productId');
      }

      print(
          '🗑️ FIREBASE: Deleting product $productId from shipment $shipmentId, box $boxId');

      // Delete product from correct collection path
      final productsPath =
          '$_userPath/shipments/$shipmentId/boxes/$boxId/products';
      print('🗑️ FIREBASE: Product deletion path: $productsPath/$productId');

      final productRef = firestore.collection(productsPath).doc(productId);
      await productRef.delete();

      _logger.i(
          'Product deleted from Firebase: $productId from shipment $shipmentId, box $boxId');
      print(
          '✅ FIREBASE: Successfully deleted product $productId from Firebase');
    } catch (e, s) {
      print('❌ FIREBASE: Failed to delete product $productId: $e');
      _logger.e('Failed to delete product from Firebase', e, s);
      rethrow;
    }
  }
}
