import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:invoice_generator/services/database_service.dart';
import 'package:invoice_generator/models/shipment.dart';
import 'package:invoice_generator/models/box_product.dart';
import 'package:invoice_generator/models/product.dart';
import 'package:invoice_generator/models/invoice.dart';
import 'package:invoice_generator/models/master_shipper.dart';
import 'package:invoice_generator/models/master_consignee.dart';
import 'package:invoice_generator/models/master_product_type.dart';
import 'package:logger/logger.dart';

/// Local database service that replaces Firebase functionality with SQLite
class LocalDatabaseService {
  static final LocalDatabaseService _instance =
      LocalDatabaseService._internal();
  factory LocalDatabaseService() => _instance;
  LocalDatabaseService._internal();

  final DatabaseService _db = DatabaseService();
  final _logger = Logger();

  /// Initialize the service and database
  Future<void> initialize() async {
    try {
      await _db.database; // This will create tables if needed
      await _db.initializeDefaultData();
      // Clean up any orphaned boxes from previous issues
      await _db.cleanupOrphanedBoxes();
      _logger.i('LocalDatabaseService initialized successfully');
    } catch (e, s) {
      _logger.e('Failed to initialize LocalDatabaseService', e, s);
      rethrow;
    }
  }

  // ========== DATA LOADING ==========

  /// Load all necessary data for the app (replaces Firebase loadData)
  Future<Map<String, dynamic>> loadData() async {
    try {
      _logger.i('Loading app data from local database...');

      // Load flower types (items)
      final flowerTypes = await getFlowerTypes();

      // Load recent shipments as items for backward compatibility
      final shipments = await getShipments(limit: 50);
      final items =
          shipments.map((s) => Item.fromShipment(s.toSQLite())).toList();

      // Get sign URL from resources
      final signUrl = await getResource('signURL') ?? 'assets/images/sign.png';

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

  /// Save a shipment (replaces Firebase saveShipment)
  Future<void> saveShipment(Shipment shipment) async {
    try {
      _logger
          .i('Saving shipment ${shipment.invoiceNumber} to local database...');
      await _db.saveShipment(shipment.toSQLite());
      _logger.i('Shipment ${shipment.invoiceNumber} saved successfully');
    } catch (e, s) {
      _logger.e('Failed to save shipment to local database', e, s);
      throw Exception('Failed to save shipment to local database');
    }
  }

  /// Get all shipments
  Future<List<Shipment>> getShipments({String? status, int limit = 50}) async {
    try {
      final results = await _db.getShipments(status: status);
      final shipments =
          results.take(limit).map((data) => Shipment.fromSQLite(data)).toList();
      return shipments;
    } catch (e, s) {
      _logger.e('Failed to get shipments', e, s);
      return [];
    }
  }

  /// Get shipment by ID
  Future<Shipment?> getShipment(String invoiceNumber) async {
    try {
      final data = await _db.getShipment(invoiceNumber);
      return data != null ? Shipment.fromSQLite(data) : null;
    } catch (e, s) {
      _logger.e('Failed to get shipment $invoiceNumber', e, s);
      return null;
    }
  }

  /// Update shipment
  Future<void> updateShipment(String id, Map<String, dynamic> updates) async {
    try {
      await _db.updateShipment(id, updates);
      _logger.i('Shipment $id updated successfully');
    } catch (e, s) {
      _logger.e('Failed to update shipment $id', e, s);
      throw Exception('Failed to update shipment: ${e.toString()}');
    }
  }

  /// Delete shipment
  Future<void> deleteShipment(String id) async {
    try {
      await _db.deleteShipment(id);
      _logger.i('Shipment $id deleted successfully');
    } catch (e, s) {
      _logger.e('Failed to delete shipment $id', e, s);
      throw Exception('Failed to delete shipment: ${e.toString()}');
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
      final box = ShipmentBox(
        id: boxData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        shipmentId: shipmentId,
        boxNumber: boxData['boxNumber'] ?? 'Box 1',
        length: (boxData['length'] ?? 0.0).toDouble(),
        width: (boxData['width'] ?? 0.0).toDouble(),
        height: (boxData['height'] ?? 0.0).toDouble(),
      );

      print(
          '💾 DEBUG: LocalDatabaseService.saveBox - saving box ${box.id} (${box.boxNumber}) for shipment $shipmentId');
      await _db.saveBox(shipmentId, box.toSQLite());
      _logger.i('Box ${box.id} saved successfully');
      return box.id;
    } catch (e, s) {
      _logger.e('Failed to save box', e, s);
      throw Exception('Failed to save box: ${e.toString()}');
    }
  }

  /// Get boxes for a shipment
  Future<List<ShipmentBox>> getBoxesForShipment(String shipmentId) async {
    try {
      final results = await _db.getBoxesForShipment(shipmentId);
      print(
          '📦 DEBUG: LocalDatabaseService.getBoxesForShipment - found ${results.length} boxes in DB for shipment $shipmentId');
      final boxes = <ShipmentBox>[];

      for (final boxData in results) {
        final box = ShipmentBox.fromSQLite(boxData);
        // Load products for this box
        final products = await getProductsForBox(box.id);
        final boxWithProducts = box.copyWith(products: products);
        print(
            '   Loaded box ${box.id} (${box.boxNumber}) with ${products.length} products');
        boxes.add(boxWithProducts);
      }

      print(
          '📦 DEBUG: Returning ${boxes.length} boxes for shipment $shipmentId');
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
      final product = ShipmentProduct(
        id: productData['id'] ??
            DateTime.now().millisecondsSinceEpoch.toString(),
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

      await _db.saveProduct(boxId, product.toSQLite());
      _logger.i('Product ${product.id} saved successfully');
      return product.id;
    } catch (e, s) {
      _logger.e('Failed to save product', e, s);
      throw Exception('Failed to save product: ${e.toString()}');
    }
  }

  /// Get products for a box
  Future<List<ShipmentProduct>> getProductsForBox(String boxId) async {
    try {
      final results = await _db.getProductsForBox(boxId);
      return results.map((data) => ShipmentProduct.fromSQLite(data)).toList();
    } catch (e, s) {
      _logger.e('Failed to get products for box $boxId', e, s);
      return [];
    }
  }

  /// Delete all boxes and their products for a shipment (used during updates)
  Future<void> deleteAllBoxesForShipment(String shipmentId) async {
    try {
      _logger.i('Deleting all boxes and products for shipment: $shipmentId');

      // Get all boxes for this shipment first
      final boxes = await getBoxesForShipment(shipmentId);
      _logger
          .i('Found ${boxes.length} boxes to delete for shipment $shipmentId');

      // Get database instance
      final db = await _db.database;

      // Delete all products for each box, then delete the boxes
      for (final box in boxes) {
        // Delete products for this box
        await db.delete(
          'products',
          where: 'box_id = ?',
          whereArgs: [box.id],
        );
        _logger.i('Deleted products for box ${box.id}');
      }

      // Delete all boxes for this shipment
      final deletedBoxes = await db.delete(
        'boxes',
        where: 'shipment_invoice_number = ?',
        whereArgs: [shipmentId],
      );

      _logger.i(
          'Deleted $deletedBoxes boxes and their products for shipment $shipmentId');
    } catch (e, s) {
      _logger.e(
          'Failed to delete boxes and products for shipment $shipmentId', e, s);
      throw Exception(
          'Failed to delete boxes and products for shipment: ${e.toString()}');
    }
  }

  // ========== DRAFT OPERATIONS ==========

  /// Save draft (replaces Firebase saveDraft)
  Future<String> saveDraft(Map<String, dynamic> draftData) async {
    try {
      // Ensure database is initialized
      await _db.database;

      _logger.i('Saving draft to local database...');
      print(
          'DEBUG: LocalDatabaseService.saveDraft called with data: $draftData');

      final draft = {
        'invoice_number': draftData['invoiceNumber'] ?? '',
        'shipper_name': draftData['shipper'] ?? '',
        'consignee_name': draftData['consignee'] ?? '',
        'draft_data': jsonEncode(draftData), // Store complete draft as JSON
        'status': 'draft',
      };

      print('DEBUG: Prepared draft for database: $draft');
      print('DEBUG: JSON encoded draft_data: ${draft['draft_data']}');
      final draftId = await _db.saveDraft(draft);
      _logger.i('Draft $draftId saved successfully');
      print('DEBUG: Draft saved to database with ID: $draftId');
      return draftId;
    } catch (e, s) {
      _logger.e('Failed to save draft', e, s);
      throw Exception('Failed to save draft: ${e.toString()}');
    }
  }

  /// Update existing draft
  Future<void> updateDraft(
      String draftId, Map<String, dynamic> draftData) async {
    try {
      // Ensure database is initialized
      await _db.database;

      _logger.i('Updating draft $draftId in local database...');

      final draft = {
        'invoice_number': draftData['invoiceNumber'] ?? '',
        'shipper_name': draftData['shipper'] ?? '',
        'consignee_name': draftData['consignee'] ?? '',
        'draft_data': jsonEncode(draftData), // Store complete draft as JSON
        'status': 'draft',
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

      await _db.updateDraft(draftId, draft);
      _logger.i('Draft $draftId updated successfully');
    } catch (e, s) {
      _logger.e('Failed to update draft $draftId', e, s);
      throw Exception('Failed to update draft: ${e.toString()}');
    }
  }

  /// Get all drafts
  Future<List<Map<String, dynamic>>> getDrafts() async {
    try {
      final results = await _db.getDrafts();

      // Parse JSON data for each draft
      return results.map((draft) {
        try {
          final draftData = jsonDecode(draft['draft_data'] ?? '{}');
          return {
            'id': draft['id'],
            'invoiceNumber': draft['invoice_number'],
            'shipperName': draft['shipper_name'],
            'consigneeName': draft['consignee_name'],
            'status': draft['status'],
            'createdAt': draft['created_at'],
            'updatedAt': draft['updated_at'],
            'draftData': draftData,
          };
        } catch (e) {
          _logger.w('Failed to parse draft data for ${draft['id']}');
          return draft;
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
      final db = await _db.database;
      await db.delete('drafts', where: 'id = ?', whereArgs: [draftId]);
      _logger.i('Draft $draftId deleted successfully');
    } catch (e, s) {
      _logger.e('Failed to delete draft $draftId', e, s);
      throw Exception('Failed to delete draft: ${e.toString()}');
    }
  }

  /// Convert draft to shipment
  Future<String> publishDraft(String draftId) async {
    try {
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

      await saveShipment(shipment);

      // Save boxes and products if they exist in draft
      if (draftData['boxes'] != null && draftData['boxes'] is List) {
        final boxes = draftData['boxes'] as List<dynamic>;
        for (final boxData in boxes) {
          if (boxData is Map<String, dynamic>) {
            // Save box using the shipment invoice number (DB links boxes to invoice_number)
            final boxId = await saveBox(shipment.invoiceNumber, boxData);

            // Save products for this box
            if (boxData['products'] != null && boxData['products'] is List) {
              final products = boxData['products'] as List<dynamic>;
              for (final productData in products) {
                if (productData is Map<String, dynamic>) {
                  await saveProduct(boxId, productData);
                }
              }
            }
          }
        }
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

  // ========== INVOICE OPERATIONS (for backward compatibility) ==========

  /// Save invoice (converts to shipment)
  Future<void> saveInvoice(Invoice invoice) async {
    try {
      _logger.i('Saving invoice ${invoice.invoiceNumber} as shipment...');

      final shipment = Shipment(
        invoiceNumber: invoice.invoiceNumber,
        shipper: 'Default Shipper',
        consignee: invoice.shipment.consignee,
        awb: invoice.invoiceNumber,
        flightNo: invoice.shipment.flightNo,
        flightDate: DateTime.now(),
        dischargeAirport: invoice.shipment.dischargeAirport,
        eta: invoice.shipment.eta,
        grossWeight: invoice.total,
        invoiceTitle: 'Invoice ${invoice.invoiceNumber}',
      );

      await saveShipment(shipment);

      // Save invoice items
      if (invoice.items.isNotEmpty) {
        final db = await _db.database;
        for (var item in invoice.items) {
          await db.insert('items', {
            'id': DateTime.now().millisecondsSinceEpoch.toString(),
            'shipment_invoice_number': shipment.invoiceNumber,
            'flower_type_id': item.flowerTypeId,
            'weight_kg': item.weightKg,
            'form': item.form,
            'quantity': item.quantity,
            'notes': item.notes,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }

      _logger.i('Invoice ${invoice.invoiceNumber} saved successfully');
    } catch (e, s) {
      _logger.e('Failed to save invoice', e, s);
      throw Exception('Failed to save invoice: ${e.toString()}');
    }
  }

  // ========== FLOWER TYPES ==========

  /// Get all flower types
  Future<List<FlowerType>> getFlowerTypes() async {
    try {
      final db = await _db.database;
      final results =
          await db.query('flower_types', orderBy: 'flower_name ASC');

      return results
          .map((data) => FlowerType(
                id: data['id'] as String,
                flowerName: data['flower_name'] as String,
                description: data['description'] as String? ?? '',
              ))
          .toList();
    } catch (e, s) {
      _logger.e('Failed to get flower types', e, s);
      return [];
    }
  }

  /// Save a flower type
  Future<String> saveFlowerType(FlowerType flowerType) async {
    try {
      final db = await _db.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final userId = _db.getCurrentUserId();

      final id = flowerType.id.isNotEmpty
          ? flowerType.id
          : DateTime.now().millisecondsSinceEpoch.toString();

      if (userId == null) {
        throw Exception('User not authenticated. Cannot save flower type.');
      }

      await db.insert(
        'flower_types',
        {
          'id': id,
          'user_id': userId,
          'flower_name': flowerType.flowerName,
          'description': flowerType.description,
          'created_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _logger.i('Flower type saved: $id');
      return id;
    } catch (e, s) {
      _logger.e('Failed to save flower type', e, s);
      rethrow;
    }
  }

  /// Update a flower type
  Future<void> updateFlowerType(String id, Map<String, dynamic> updates) async {
    try {
      final db = await _db.database;
      final data = {
        ...updates,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

      final rows = await db.update(
        'flower_types',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rows == 0) {
        throw Exception('Flower type not found: $id');
      }

      _logger.i('Flower type updated: $id');
    } catch (e, s) {
      _logger.e('Failed to update flower type', e, s);
      rethrow;
    }
  }

  /// Delete a flower type
  Future<void> deleteFlowerType(String id) async {
    try {
      final db = await _db.database;
      await db.delete('flower_types', where: 'id = ?', whereArgs: [id]);
      _logger.i('Flower type deleted: $id');
    } catch (e, s) {
      _logger.e('Failed to delete flower type', e, s);
      rethrow;
    }
  }

  // ========== RESOURCES ==========

  /// Get resource value by key
  Future<String?> getResource(String key) async {
    try {
      final db = await _db.database;
      final results =
          await db.query('resources', where: 'key = ?', whereArgs: [key]);
      return results.isNotEmpty ? results.first['value'] as String? : null;
    } catch (e, s) {
      _logger.e('Failed to get resource $key', e, s);
      return null;
    }
  }

  /// Set resource value
  Future<void> setResource(String key, String value) async {
    try {
      final db = await _db.database;
      await db.insert(
          'resources',
          {
            'key': key,
            'value': value,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e, s) {
      _logger.e('Failed to set resource $key', e, s);
      throw Exception('Failed to set resource: ${e.toString()}');
    }
  }

  // ========== STATISTICS ==========

  /// Get database statistics
  Future<Map<String, dynamic>> getStats() async {
    try {
      return await _db.getDatabaseStats();
    } catch (e, s) {
      _logger.e('Failed to get database stats', e, s);
      return {};
    }
  }

  /// Get shipment statistics
  Future<Map<String, dynamic>> getShipmentStats() async {
    try {
      final stats = await _db.getDatabaseStats();

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
      final db = await _db.database;
      final results = await db.rawQuery('''
        SELECT * FROM shipments 
        WHERE shipper LIKE ? OR consignee LIKE ? OR awb LIKE ? OR invoice_title LIKE ?
        ORDER BY created_at DESC
      ''', ['%$query%', '%$query%', '%$query%', '%$query%']);

      return results.map((data) => Shipment.fromSQLite(data)).toList();
    } catch (e, s) {
      _logger.e('Failed to search shipments', e, s);
      return [];
    }
  }

  /// Close database connection
  Future<void> close() async {
    await _db.close();
  }

  // ========== MASTER DATA OPERATIONS ==========

  // ---------- MASTER SHIPPERS ----------

  /// Get all master shippers
  Future<List<MasterShipper>> getMasterShippers() async {
    try {
      final results = await _db.getMasterShippers();
      return results.map((data) => MasterShipper.fromMap(data)).toList();
    } catch (e, s) {
      _logger.e('Failed to get master shippers', e, s);
      return [];
    }
  }

  /// Save a master shipper
  Future<String> saveMasterShipper(MasterShipper shipper) async {
    try {
      final id = await _db.saveMasterShipper(shipper.toMap());
      _logger.i('Master shipper saved: $id');
      return id;
    } catch (e, s) {
      _logger.e('Failed to save master shipper', e, s);
      rethrow;
    }
  }

  /// Update a master shipper
  Future<void> updateMasterShipper(
      String id, Map<String, dynamic> updates) async {
    try {
      await _db.updateMasterShipper(id, updates);
      _logger.i('Master shipper updated: $id');
    } catch (e, s) {
      _logger.e('Failed to update master shipper', e, s);
      rethrow;
    }
  }

  /// Delete a master shipper
  Future<void> deleteMasterShipper(String id) async {
    try {
      await _db.deleteMasterShipper(id);
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
      final results = await _db.getMasterConsignees();
      return results.map((data) => MasterConsignee.fromMap(data)).toList();
    } catch (e, s) {
      _logger.e('Failed to get master consignees', e, s);
      return [];
    }
  }

  /// Save a master consignee
  Future<String> saveMasterConsignee(MasterConsignee consignee) async {
    try {
      final id = await _db.saveMasterConsignee(consignee.toMap());
      _logger.i('Master consignee saved: $id');
      return id;
    } catch (e, s) {
      _logger.e('Failed to save master consignee', e, s);
      rethrow;
    }
  }

  /// Update a master consignee
  Future<void> updateMasterConsignee(
      String id, Map<String, dynamic> updates) async {
    try {
      await _db.updateMasterConsignee(id, updates);
      _logger.i('Master consignee updated: $id');
    } catch (e, s) {
      _logger.e('Failed to update master consignee', e, s);
      rethrow;
    }
  }

  /// Delete a master consignee
  Future<void> deleteMasterConsignee(String id) async {
    try {
      await _db.deleteMasterConsignee(id);
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
      final results = await _db.getMasterProductTypes();
      return results.map((data) => MasterProductType.fromMap(data)).toList();
    } catch (e, s) {
      _logger.e('Failed to get master product types', e, s);
      return [];
    }
  }

  /// Save a master product type
  Future<String> saveMasterProductType(MasterProductType productType) async {
    try {
      final id = await _db.saveMasterProductType(productType.toMap());
      _logger.i('Master product type saved: $id');
      return id;
    } catch (e, s) {
      _logger.e('Failed to save master product type', e, s);
      rethrow;
    }
  }

  /// Update a master product type
  Future<void> updateMasterProductType(
      String id, Map<String, dynamic> updates) async {
    try {
      await _db.updateMasterProductType(id, updates);
      _logger.i('Master product type updated: $id');
    } catch (e, s) {
      _logger.e('Failed to update master product type', e, s);
      rethrow;
    }
  }

  /// Get the next invoice number in CS format (CS0001, CS0002, etc.)
  Future<String> getNextInvoiceNumber() async {
    try {
      final db = await _db.database;

      // Query all shipments to find existing CS invoice numbers
      final results = await db.rawQuery('''
        SELECT invoice_number FROM shipments
        WHERE invoice_number LIKE 'CS%'
        ORDER BY invoice_number DESC
        LIMIT 1
      ''');

      if (results.isNotEmpty) {
        final lastInvoiceNumber = results.first['invoice_number'] as String;
        // Extract the numeric part after "CS"
        final numericPart = lastInvoiceNumber.substring(2); // Remove "CS"
        final lastNumber = int.tryParse(numericPart) ?? 0;
        final nextNumber = lastNumber + 1;
        return 'CS${nextNumber.toString().padLeft(4, '0')}';
      } else {
        // No existing CS invoices, start with CS0001
        return 'CS0001';
      }
    } catch (e, s) {
      _logger.e('Failed to get next invoice number', e, s);
      // Fallback to timestamp-based number if database query fails
      return 'KS${DateTime.now().millisecondsSinceEpoch.toString().substring(8, 12)}';
    }
  }

  /// Get the next AWB number in awb format (awb001, awb002, etc.)
  Future<String> getNextAwbNumber() async {
    try {
      final db = await _db.database;

      // Query all shipments to find existing AWB numbers (both uppercase and lowercase for compatibility)
      final results = await db.rawQuery('''
        SELECT awb FROM shipments
        WHERE awb LIKE 'AWB%' OR awb LIKE 'awb%'
        ORDER BY awb DESC
        LIMIT 1
      ''');

      if (results.isNotEmpty) {
        final lastAwb = results.first['awb'] as String;
        // Extract the numeric part after "AWB" or "awb"
        final numericPart = lastAwb.substring(3); // Remove "AWB" or "awb"
        final lastNumber = int.tryParse(numericPart) ?? 0;
        final nextNumber = lastNumber + 1;
        return 'AWB${nextNumber.toString().padLeft(3, '0')}';
      } else {
        // No existing AWB numbers, start with AWB001
        return 'AWB001';
      }
    } catch (e, s) {
      _logger.e('Failed to get next AWB number', e, s);
      // Fallback to timestamp-based number if database query fails
      return 'AWB${DateTime.now().millisecondsSinceEpoch.toString().substring(8, 11)}';
    }
  }

  /// Delete a master product type
  Future<void> deleteMasterProductType(String id) async {
    try {
      await _db.deleteMasterProductType(id);
      _logger.i('Master product type deleted: $id');
    } catch (e, s) {
      _logger.e('Failed to delete master product type', e, s);
      rethrow;
    }
  }

  // ========== BOX OPERATIONS ==========

  /// Update a box
  Future<void> updateBox(String boxId, Map<String, dynamic> boxData) async {
    try {
      await _db.updateBox(boxId, boxData);
      _logger.i('Box updated: $boxId');
    } catch (e, s) {
      _logger.e('Failed to update box', e, s);
      rethrow;
    }
  }

  /// Delete a box
  Future<void> deleteBox(String boxId) async {
    try {
      await _db.deleteBox(boxId);
      _logger.i('Box deleted: $boxId');
    } catch (e, s) {
      _logger.e('Failed to delete box', e, s);
      rethrow;
    }
  }

  // ========== PRODUCT OPERATIONS ==========

  /// Update a product
  Future<void> updateProduct(
      String productId, Map<String, dynamic> productData) async {
    try {
      await _db.updateProduct(productId, productData);
      _logger.i('Product updated: $productId');
    } catch (e, s) {
      _logger.e('Failed to update product', e, s);
      rethrow;
    }
  }

  /// Delete a product
  Future<void> deleteProduct(String productId) async {
    try {
      await _db.deleteProduct(productId);
      _logger.i('Product deleted: $productId');
    } catch (e, s) {
      _logger.e('Failed to delete product', e, s);
      rethrow;
    }
  }
}
