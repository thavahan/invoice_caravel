import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:logger/logger.dart';

/// SQLite database service for local data storage
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  final _logger = Logger();

  /// Current user ID for data isolation
  String? _currentUserId;

  /// Set current user ID
  void setCurrentUserId(String? userId) {
    _currentUserId = userId;
  }

  /// Get current user ID
  String? getCurrentUserId() {
    return _currentUserId;
  }

  /// Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database with all required tables
  Future<Database> _initDatabase() async {
    try {
      String path = join(
        await getDatabasesPath(),
        'invoice.db',
      ); // Database with user isolation
      _logger.i('Initializing database at: $path');

      final db = await openDatabase(
        path,
        version:
            3, // Updated version for new fields (master_awb, house_awb, flight_date, gross_weight)
        onCreate: _createTables,
        onUpgrade: _upgradeDatabase,
      );

      // Enable foreign key constraints
      await db.execute('PRAGMA foreign_keys = ON;');
      _logger.i('Foreign key constraints enabled');

      return db;
    } catch (e, s) {
      _logger.e('Failed to initialize database', e, s);
      rethrow;
    }
  }

  /// Create all database tables
  Future<void> _createTables(Database db, int version) async {
    try {
      _logger.i('Creating database tables...');

      // 1. Shipments table (main table)
      await db.execute('''
        CREATE TABLE shipments (
          invoice_number TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          shipper TEXT NOT NULL,
          shipper_address TEXT,
          consignee TEXT NOT NULL,
          consignee_address TEXT,
          client_ref TEXT,
          awb TEXT NOT NULL,
          master_awb TEXT,      -- New field: Master AWB (optional)
          house_awb TEXT,       -- New field: House AWB (optional)
          flight_no TEXT,
          flight_date INTEGER,  -- New field: FLIGHT Date (mandatory)
          discharge_airport TEXT,
          origin TEXT,
          destination TEXT,
          eta INTEGER,
          invoice_date INTEGER,
          date_of_issue INTEGER,
          place_of_receipt TEXT,
          sgst_no TEXT,
          iec_code TEXT,
          freight_terms TEXT,
          gross_weight REAL DEFAULT 0.0,  -- Changed from total_amount
          total_amount REAL DEFAULT 0.0,  -- Keep for legacy support
          invoice_title TEXT,
          status TEXT DEFAULT 'pending',
          created_at INTEGER NOT NULL,
          updated_at INTEGER
        )
      ''');

      // 2. Boxes table (related to shipments)
      await db.execute('''
        CREATE TABLE boxes (
          id TEXT PRIMARY KEY,
          shipment_invoice_number TEXT NOT NULL,
          box_number TEXT NOT NULL,
          length REAL DEFAULT 0.0,
          width REAL DEFAULT 0.0,
          height REAL DEFAULT 0.0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER,
          FOREIGN KEY (shipment_invoice_number) REFERENCES shipments (invoice_number) ON DELETE CASCADE
        )
      ''');

      // 3. Products table (related to boxes)
      await db.execute('''
        CREATE TABLE products (
          id TEXT PRIMARY KEY,
          box_id TEXT NOT NULL,
          type TEXT NOT NULL,
          description TEXT,
          weight REAL DEFAULT 0.0,
          rate REAL DEFAULT 0.0,
          quantity INTEGER DEFAULT 1,
          flower_type TEXT DEFAULT 'LOOSE FLOWERS',
          has_stems INTEGER DEFAULT 0,
          approx_quantity INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER,
          FOREIGN KEY (box_id) REFERENCES boxes (id) ON DELETE CASCADE
        )
      ''');

      // 4. Drafts table (for saving work in progress)
      await db.execute('''
        CREATE TABLE drafts (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          invoice_number TEXT,
          shipper_name TEXT,
          consignee_name TEXT,
          draft_data TEXT, -- JSON string of complete draft
          status TEXT DEFAULT 'draft',
          created_at INTEGER NOT NULL,
          updated_at INTEGER
        )
      ''');

      // 5. Flower Types table
      await db.execute('''
        CREATE TABLE flower_types (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          flower_name TEXT NOT NULL,
          description TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER
        )
      ''');

      // 6. Items table (for invoice items)
      await db.execute('''
        CREATE TABLE items (
          id TEXT PRIMARY KEY,
          shipment_invoice_number TEXT,
          flower_type_id TEXT,
          weight_kg REAL,
          form TEXT,
          quantity INTEGER,
          notes TEXT,
          created_at INTEGER NOT NULL,
          FOREIGN KEY (shipment_invoice_number) REFERENCES shipments (invoice_number) ON DELETE CASCADE
        )
      ''');

      // 7. Resources table (for app configuration)
      await db.execute('''
        CREATE TABLE resources (
          key TEXT PRIMARY KEY,
          value TEXT,
          updated_at INTEGER
        )
      ''');

      // 8. Master Data Tables for Dropdowns

      // Shippers master data
      await db.execute('''
        CREATE TABLE master_shippers (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          name TEXT NOT NULL,
          address TEXT NOT NULL,
          phone TEXT,
          address_line1 TEXT,
          address_line2 TEXT,
          city TEXT,
          state TEXT,
          pincode TEXT,
          landmark TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER
        )
      ''');

      // Consignees master data
      await db.execute('''
        CREATE TABLE master_consignees (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          name TEXT NOT NULL,
          address TEXT NOT NULL,
          phone TEXT,
          address_line1 TEXT,
          address_line2 TEXT,
          city TEXT,
          state TEXT,
          pincode TEXT,
          landmark TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER
        )
      ''');

      // Product types master data
      await db.execute('''
        CREATE TABLE master_product_types (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          name TEXT NOT NULL,
          approx_quantity INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER
        )
      ''');

      // Create indexes for better performance
      await db.execute('CREATE INDEX idx_shipments_awb ON shipments (awb)');
      await db.execute(
        'CREATE INDEX idx_shipments_status ON shipments (status)',
      );
      await db
          .execute('CREATE INDEX idx_shipments_user_id ON shipments (user_id)');
      await db.execute(
        'CREATE INDEX idx_boxes_shipment ON boxes (shipment_invoice_number)',
      );
      await db.execute('CREATE INDEX idx_products_box ON products (box_id)');
      await db.execute(
        'CREATE INDEX idx_items_shipment ON items (shipment_invoice_number)',
      );
      await db.execute('CREATE INDEX idx_drafts_user_id ON drafts (user_id)');
      await db.execute(
          'CREATE INDEX idx_master_shippers_user_id ON master_shippers (user_id)');
      await db.execute(
          'CREATE INDEX idx_master_consignees_user_id ON master_consignees (user_id)');
      await db.execute(
          'CREATE INDEX idx_master_product_types_user_id ON master_product_types (user_id)');
      await db.execute(
          'CREATE INDEX idx_flower_types_user_id ON flower_types (user_id)');

      _logger.i('Database tables created successfully');
    } catch (e, s) {
      _logger.e('Failed to create database tables', e, s);
      rethrow;
    }
  }

  /// Handle database upgrades
  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    _logger.i('Upgrading database from version $oldVersion to $newVersion');

    try {
      if (oldVersion == 2 && newVersion == 3) {
        // Add new columns to existing shipments table
        _logger.i('Adding new fields to shipments table');
        await db.execute(
            'ALTER TABLE shipments ADD COLUMN master_awb TEXT DEFAULT ""');
        await db.execute(
            'ALTER TABLE shipments ADD COLUMN house_awb TEXT DEFAULT ""');
        await db
            .execute('ALTER TABLE shipments ADD COLUMN flight_date INTEGER');
        await db.execute(
            'ALTER TABLE shipments ADD COLUMN gross_weight REAL DEFAULT 0.0');

        _logger.i('Database upgrade from v2 to v3 completed successfully');
      } else {
        // For other version upgrades, use the drop and recreate approach
        _logger.i('Recreating database with current schema');

        // Drop all existing tables
        await db.execute('DROP TABLE IF EXISTS shipments');
        await db.execute('DROP TABLE IF EXISTS boxes');
        await db.execute('DROP TABLE IF EXISTS products');
        await db.execute('DROP TABLE IF EXISTS drafts');
        await db.execute('DROP TABLE IF EXISTS flower_types');
        await db.execute('DROP TABLE IF EXISTS items');
        await db.execute('DROP TABLE IF EXISTS resources');
        await db.execute('DROP TABLE IF EXISTS master_shippers');
        await db.execute('DROP TABLE IF EXISTS master_consignees');
        await db.execute('DROP TABLE IF EXISTS master_product_types');

        // Recreate all tables with current schema
        await _createTables(db, newVersion);
      }

      _logger.i('Database upgrade completed successfully');
    } catch (e, s) {
      _logger.e('Failed to upgrade database', e, s);
      rethrow;
    }
  }

  String _generateInvoiceNumber() {
    final now = DateTime.now();
    final year = now.year.toString().substring(2); // Last 2 digits of year
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final timestamp = now.millisecondsSinceEpoch.toString().substring(
          8,
        ); // Last 5 digits

    return 'INV$year$month$day$timestamp';
  }

  // ========== SHIPMENT OPERATIONS ==========

  /// Save a shipment to database
  Future<String> saveShipment(Map<String, dynamic> shipmentData) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final userId = getCurrentUserId();

      if (userId == null) {
        throw Exception('User not authenticated. Cannot save shipment.');
      }

      // Validate and NORMALIZE AWB to UPPERCASE
      var awb = shipmentData['awb']?.toString().trim() ?? '';
      if (awb.isEmpty) {
        throw Exception('AWB is required and cannot be empty');
      }
      awb = awb.toUpperCase(); // Convert to uppercase

      // Generate invoice number if not provided or empty, then NORMALIZE to UPPERCASE
      final invoiceNumberValue = shipmentData['invoice_number'];
      var invoiceNumber = (invoiceNumberValue == null ||
              invoiceNumberValue.toString().trim().isEmpty)
          ? _generateInvoiceNumber()
          : invoiceNumberValue.toString().trim();
      invoiceNumber = invoiceNumber.toUpperCase(); // Convert to uppercase

      final data = {
        ...shipmentData,
        'invoice_number': invoiceNumber,
        'awb': awb,
        'user_id': userId, // Add user ID
        'created_at': now,
        'updated_at': now,
      };

      // Normalize common camelCase keys to snake_case DB columns so callers may pass either form
      // (e.g., callers may pass 'flightNo' or 'flight_no')
      final Map<String, String> normalizeMap = {
        'invoiceTitle': 'invoice_title',
        'flightNo': 'flight_no',
        'dischargeAirport': 'discharge_airport',
        'invoiceDate': 'invoice_date',
        'dateOfIssue': 'date_of_issue',
        'shipperAddress': 'shipper_address',
        'consigneeAddress': 'consignee_address',
        'totalAmount': 'total_amount',
        'placeOfReceipt': 'place_of_receipt',
      };

      for (final entry in normalizeMap.entries) {
        final camel = entry.key;
        final snake = entry.value;
        if (data.containsKey(camel) && !data.containsKey(snake)) {
          data[snake] = data[camel];
        }
      }

      // Remove id from data since invoice_number is now the primary key
      data.remove('id');

      print(
          '💾 DEBUG: DatabaseService.saveShipment - Saving with invoiceNumber: $invoiceNumber (uppercase), awb: $awb (uppercase)');

      await db.insert(
        'shipments',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _logger.i(
        'Shipment saved successfully with invoice number: $invoiceNumber',
      );
      return invoiceNumber;
    } catch (e, s) {
      _logger.e('Failed to save shipment', e, s);
      throw Exception('Failed to save shipment: ${e.toString()}');
    }
  }

  /// Get all shipments
  Future<List<Map<String, dynamic>>> getShipments({String? status}) async {
    try {
      final db = await database;
      final userId = getCurrentUserId();

      if (userId == null) {
        _logger.w('User not authenticated. Returning empty shipments list.');
        return [];
      }

      String query = 'SELECT * FROM shipments WHERE user_id = ?';
      List<dynamic> args = [userId];

      if (status != null) {
        query += ' AND status = ?';
        args.add(status);
      }

      query += ' ORDER BY created_at DESC';

      final results = await db.rawQuery(query, args);
      _logger.i('Retrieved ${results.length} shipments for user: $userId');
      return results;
    } catch (e, s) {
      _logger.e('Failed to get shipments', e, s);
      throw Exception('Failed to get shipments: ${e.toString()}');
    }
  }

  /// Get shipment by ID
  Future<Map<String, dynamic>?> getShipment(String invoiceNumber) async {
    try {
      final db = await database;
      final userId = getCurrentUserId();

      if (userId == null) {
        _logger.w('User not authenticated. Cannot get shipment.');
        return null;
      }

      final results = await db.query(
        'shipments',
        where: 'invoice_number = ? AND user_id = ?',
        whereArgs: [invoiceNumber, userId],
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e, s) {
      _logger.e('Failed to get shipment $invoiceNumber', e, s);
      return null;
    }
  }

  /// Update shipment
  Future<void> updateShipment(
    String invoiceNumber,
    Map<String, dynamic> updates,
  ) async {
    try {
      final db = await database;

      // Map camelCase field names to snake_case database column names
      final Map<String, String> fieldMapping = {
        'invoiceTitle': 'invoice_title',
        'shipper': 'shipper',
        'consignee': 'consignee',
        'awb': 'awb',
        'flightNo': 'flight_no',
        'dischargeAirport': 'discharge_airport',
        'origin': 'origin',
        'destination': 'destination',
        'eta': 'eta',
        'totalAmount': 'total_amount',
        'shipperAddress': 'shipper_address',
        'consigneeAddress': 'consignee_address',
        'clientRef': 'client_ref',
        'invoiceDate': 'invoice_date',
        'dateOfIssue': 'date_of_issue',
        'placeOfReceipt': 'place_of_receipt',
        'sgstNo': 'sgst_no',
        'iecCode': 'iec_code',
        'freightTerms': 'freight_terms',
        'status': 'status',
      };

      // Convert camelCase keys to snake_case column names
      final data = <String, dynamic>{};
      updates.forEach((key, value) {
        final dbColumn = fieldMapping[key] ?? key;
        // UPPERCASE normalize invoice_number and awb
        if (dbColumn == 'invoice_number' || dbColumn == 'awb') {
          data[dbColumn] = value?.toString().toUpperCase().trim() ?? value;
        } else {
          data[dbColumn] = value;
        }
      });

      // Also normalize keys that might come in snake_case but need to be preserved
      // (handles cases where both camelCase and snake_case variants exist)
      final normalizeMap = {
        'invoiceTitle': 'invoice_title',
        'flightNo': 'flight_no',
        'dischargeAirport': 'discharge_airport',
        'invoiceDate': 'invoice_date',
        'dateOfIssue': 'date_of_issue',
        'shipperAddress': 'shipper_address',
        'consigneeAddress': 'consignee_address',
        'totalAmount': 'total_amount',
        'placeOfReceipt': 'place_of_receipt',
      };

      for (final entry in normalizeMap.entries) {
        final camel = entry.key;
        final snake = entry.value;
        if (data.containsKey(camel) && !data.containsKey(snake)) {
          data[snake] = data[camel];
          data.remove(camel);
        }
      }

      // Add updated_at timestamp
      data['updated_at'] = DateTime.now().millisecondsSinceEpoch;

      print(
          '💾 DEBUG: DatabaseService.updateShipment - invoiceNumber: $invoiceNumber (will be stored as uppercase)');
      print('💾 DEBUG: data to update - keys: ${data.keys.toList()}');
      print('💾 DEBUG: awb value: ${data['awb']} (uppercased if present)');

      // Normalize the invoiceNumber for the WHERE clause too
      final normalizedInvoiceNumber = invoiceNumber.toUpperCase();

      final rowsAffected = await db.update(
        'shipments',
        data,
        where: 'invoice_number = ?',
        whereArgs: [normalizedInvoiceNumber],
      );

      if (rowsAffected == 0) {
        print(
            '⚠️ DEBUG: No rows updated for shipment $normalizedInvoiceNumber');
        _logger.w('No rows updated for shipment $normalizedInvoiceNumber');
      } else {
        print(
            '✅ DEBUG: Updated $rowsAffected row(s) for shipment $normalizedInvoiceNumber');
      }

      if (rowsAffected == 0) {
        throw Exception('Shipment not found: $normalizedInvoiceNumber');
      }
      _logger.i('Shipment $normalizedInvoiceNumber updated successfully');
    } catch (e, s) {
      _logger.e('Failed to update shipment $invoiceNumber', e, s);
      throw Exception('Failed to update shipment: ${e.toString()}');
    }
  }

  /// Delete shipment (cascade deletes boxes and products)
  Future<void> deleteShipment(String invoiceNumber) async {
    try {
      final db = await database;
      await db.delete(
        'shipments',
        where: 'invoice_number = ?',
        whereArgs: [invoiceNumber],
      );
      _logger.i('Shipment $invoiceNumber deleted successfully');
    } catch (e, s) {
      _logger.e('Failed to delete shipment $invoiceNumber', e, s);
      throw Exception('Failed to delete shipment: ${e.toString()}');
    }
  }

  /// Clean up orphaned boxes and products (for database maintenance)
  Future<void> cleanupOrphanedBoxes() async {
    try {
      final db = await database;
      // Delete boxes that don't have a corresponding shipment
      await db.rawDelete('''
        DELETE FROM boxes
        WHERE shipment_invoice_number NOT IN (
          SELECT invoice_number FROM shipments
        )
      ''');
      _logger.i('Cleaned up orphaned boxes');
    } catch (e, s) {
      _logger.e('Failed to cleanup orphaned boxes', e, s);
    }
  }

  // ========== BOX OPERATIONS ==========

  /// Save a box
  Future<String> saveBox(
      String shipmentId, Map<String, dynamic> boxData) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final data = {
        ...boxData,
        'shipment_invoice_number': shipmentId,
        'created_at': now,
        'updated_at': now
      };

      await db.insert(
        'boxes',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _logger.i('Box ${data['id']} saved successfully');
      return data['id'];
    } catch (e, s) {
      _logger.e('Failed to save box', e, s);
      throw Exception('Failed to save box: ${e.toString()}');
    }
  }

  /// Get boxes for a shipment
  Future<List<Map<String, dynamic>>> getBoxesForShipment(
    String shipmentInvoiceNumber,
  ) async {
    try {
      final db = await database;
      final results = await db.query(
        'boxes',
        where: 'shipment_invoice_number = ?',
        whereArgs: [shipmentInvoiceNumber],
        orderBy: 'created_at ASC',
      );
      return results;
    } catch (e, s) {
      _logger.e(
        'Failed to get boxes for shipment $shipmentInvoiceNumber',
        e,
        s,
      );
      return [];
    }
  }

  // ========== PRODUCT OPERATIONS ==========

  /// Save a product
  Future<String> saveProduct(
      String boxId, Map<String, dynamic> productData) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Ensure product ID is non-empty to avoid database issues
      String productId = productData['id'] ?? '';
      if (productId.isEmpty || productId.trim().isEmpty) {
        productId = '${now}_$boxId';
        _logger.w('Product ID was empty, generated: $productId');
      }

      final data = {
        ...productData,
        'id': productId,
        'box_id': boxId,
        'created_at': now,
        'updated_at': now
      };

      await db.insert(
        'products',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _logger.i('Product $productId saved successfully');
      return productId;
    } catch (e, s) {
      _logger.e('Failed to save product', e, s);
      throw Exception('Failed to save product: ${e.toString()}');
    }
  }

  /// Get products for a box
  Future<List<Map<String, dynamic>>> getProductsForBox(String boxId) async {
    try {
      final db = await database;
      final results = await db.query(
        'products',
        where: 'box_id = ?',
        whereArgs: [boxId],
        orderBy: 'created_at ASC',
      );
      return results;
    } catch (e, s) {
      _logger.e('Failed to get products for box $boxId', e, s);
      return [];
    }
  }

  // ========== DRAFT OPERATIONS ==========

  /// Save draft
  Future<String> saveDraft(Map<String, dynamic> draftData) async {
    try {
      print('DEBUG: DatabaseService.saveDraft called with: $draftData');
      final db = await database;
      final userId = getCurrentUserId();

      if (userId == null) {
        throw Exception('User not authenticated. Cannot save draft.');
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      final data = {
        'id': id,
        'user_id': userId, // Add user ID
        ...draftData,
        'created_at': now,
        'updated_at': now,
      };

      print('DEBUG: Inserting into drafts table: $data');
      await db.insert(
        'drafts',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _logger.i('Draft $id saved successfully for user: $userId');
      print('DEBUG: Draft inserted successfully with ID: $id');
      return id;
    } catch (e, s) {
      _logger.e('Failed to save draft', e, s);
      throw Exception('Failed to save draft: ${e.toString()}');
    }
  }

  /// Update existing draft
  Future<void> updateDraft(
      String draftId, Map<String, dynamic> draftData) async {
    try {
      final db = await database;
      final userId = getCurrentUserId();

      if (userId == null) {
        throw Exception('User not authenticated. Cannot update draft.');
      }

      final data = {
        ...draftData,
        'user_id': userId, // Ensure user ID is set
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

      final rowsUpdated = await db.update(
        'drafts',
        data,
        where: 'id = ? AND user_id = ?',
        whereArgs: [draftId, userId],
      );

      if (rowsUpdated == 0) {
        throw Exception('Draft not found or access denied: $draftId');
      }

      _logger.i('Draft $draftId updated successfully for user: $userId');
    } catch (e, s) {
      _logger.e('Failed to update draft $draftId', e, s);
      throw Exception('Failed to update draft: ${e.toString()}');
    }
  }

  /// Get all drafts
  Future<List<Map<String, dynamic>>> getDrafts() async {
    try {
      final db = await database;
      final userId = getCurrentUserId();

      if (userId == null) {
        _logger.w('User not authenticated. Returning empty drafts list.');
        return [];
      }

      final results = await db.query(
        'drafts',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'updated_at DESC',
      );
      _logger.i('Retrieved ${results.length} drafts for user: $userId');
      return results;
    } catch (e, s) {
      _logger.e('Failed to get drafts', e, s);
      return [];
    }
  }

  // ========== UTILITY OPERATIONS ==========

  /// Initialize default data
  Future<void> initializeDefaultData() async {
    try {
      final db = await database;
      final userId = getCurrentUserId();

      // Skip initialization if user not authenticated
      if (userId == null) {
        _logger
            .w('User not authenticated. Skipping default data initialization.');
        return;
      }

      // Insert default sign URL if not exists
      final existing = await db.query(
        'resources',
        where: 'key = ?',
        whereArgs: ['signURL'],
      );
      if (existing.isEmpty) {
        await db.insert('resources', {
          'key': 'signURL',
          'value': 'assets/images/sign.png',
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        });
      }

      _logger.i('Default data initialized successfully for user: $userId');
    } catch (e, s) {
      _logger.e('Failed to initialize default data', e, s);
    }
  }

  /// Get database statistics
  Future<Map<String, dynamic>> getDatabaseStats() async {
    try {
      final db = await database;

      final shipmentCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM shipments'),
          ) ??
          0;

      final boxCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM boxes'),
          ) ??
          0;

      final productCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM products'),
          ) ??
          0;

      final draftCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM drafts'),
          ) ??
          0;

      return {
        'shipments': shipmentCount,
        'boxes': boxCount,
        'products': productCount,
        'drafts': draftCount,
      };
    } catch (e, s) {
      _logger.e('Failed to get database stats', e, s);
      return {};
    }
  }

  /// Get database statistics for current user only
  Future<Map<String, dynamic>> getUserDatabaseStats() async {
    try {
      final db = await database;
      final userId = getCurrentUserId();

      if (userId == null) {
        _logger.w('User not authenticated. Returning empty stats.');
        return {
          'shipments': 0,
          'master_shippers': 0,
          'master_consignees': 0,
          'master_product_types': 0,
        };
      }

      final shipmentCount = Sqflite.firstIntValue(
            await db.rawQuery(
                'SELECT COUNT(*) FROM shipments WHERE user_id = ?', [userId]),
          ) ??
          0;

      final shipperCount = Sqflite.firstIntValue(
            await db.rawQuery(
                'SELECT COUNT(*) FROM master_shippers WHERE user_id = ?',
                [userId]),
          ) ??
          0;

      final consigneeCount = Sqflite.firstIntValue(
            await db.rawQuery(
                'SELECT COUNT(*) FROM master_consignees WHERE user_id = ?',
                [userId]),
          ) ??
          0;

      final productTypeCount = Sqflite.firstIntValue(
            await db.rawQuery(
                'SELECT COUNT(*) FROM master_product_types WHERE user_id = ?',
                [userId]),
          ) ??
          0;

      return {
        'shipments': shipmentCount,
        'master_shippers': shipperCount,
        'master_consignees': consigneeCount,
        'master_product_types': productTypeCount,
      };
    } catch (e, s) {
      final userId = getCurrentUserId();
      _logger.e('Failed to get user database stats for user $userId', e, s);
      return {};
    }
  }

  /// Close database connection
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      _logger.i('Database connection closed');
    }
  }

  // ========== MASTER DATA OPERATIONS ==========

  // ---------- MASTER SHIPPERS ----------

  /// Get all master shippers
  Future<List<Map<String, dynamic>>> getMasterShippers() async {
    try {
      final db = await database;
      final userId = getCurrentUserId();

      if (userId == null) {
        _logger.w('User not authenticated. Returning empty shippers list.');
        return [];
      }

      final result = await db.query(
        'master_shippers',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'name ASC',
      );
      return result;
    } catch (e, s) {
      _logger.e('Failed to get master shippers', e, s);
      return [];
    }
  }

  /// Save a master shipper
  Future<String> saveMasterShipper(Map<String, dynamic> shipperData) async {
    try {
      final db = await database;
      final userId = getCurrentUserId();

      if (userId == null) {
        throw Exception('User not authenticated. Cannot save shipper.');
      }

      final now = DateTime.now().millisecondsSinceEpoch;

      final id =
          shipperData['id'] ?? 'shipper_${now}_${DateTime.now().microsecond}';

      final data = {
        'id': id,
        'user_id': userId, // Add user ID
        'name': shipperData['name'],
        'address': shipperData['address'],
        'created_at': shipperData['created_at'] ?? now,
        'updated_at': now,
      };

      await db.insert(
        'master_shippers',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _logger.i('Master shipper saved: $id');
      return id;
    } catch (e, s) {
      _logger.e('Failed to save master shipper', e, s);
      rethrow;
    }
  }

  /// Update a master shipper
  Future<void> updateMasterShipper(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      final db = await database;
      final data = {
        ...updates,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

      final rowsUpdated = await db.update(
        'master_shippers',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsUpdated == 0) {
        throw Exception('Master shipper not found: $id');
      }

      _logger.i('Master shipper updated: $id');
    } catch (e, s) {
      _logger.e('Failed to update master shipper', e, s);
      rethrow;
    }
  }

  /// Delete a master shipper
  Future<void> deleteMasterShipper(String id) async {
    try {
      final db = await database;
      final rowsDeleted = await db.delete(
        'master_shippers',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsDeleted == 0) {
        throw Exception('Master shipper not found: $id');
      }

      _logger.i('Master shipper deleted: $id');
    } catch (e, s) {
      _logger.e('Failed to delete master shipper', e, s);
      rethrow;
    }
  }

  // ---------- MASTER CONSIGNEES ----------

  /// Get all master consignees
  Future<List<Map<String, dynamic>>> getMasterConsignees() async {
    try {
      final db = await database;
      final userId = getCurrentUserId();

      if (userId == null) {
        _logger.w('User not authenticated. Returning empty consignees list.');
        return [];
      }

      final result = await db.query(
        'master_consignees',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'name ASC',
      );
      return result;
    } catch (e, s) {
      _logger.e('Failed to get master consignees', e, s);
      return [];
    }
  }

  /// Save a master consignee
  Future<String> saveMasterConsignee(Map<String, dynamic> consigneeData) async {
    try {
      final db = await database;
      final userId = getCurrentUserId();

      if (userId == null) {
        throw Exception('User not authenticated. Cannot save consignee.');
      }

      final now = DateTime.now().millisecondsSinceEpoch;

      final id = consigneeData['id'] ??
          'consignee_${now}_${DateTime.now().microsecond}';

      final data = {
        'id': id,
        'user_id': userId, // Add user ID
        'name': consigneeData['name'],
        'address': consigneeData['address'],
        'created_at': consigneeData['created_at'] ?? now,
        'updated_at': now,
      };

      await db.insert(
        'master_consignees',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _logger.i('Master consignee saved: $id');
      return id;
    } catch (e, s) {
      _logger.e('Failed to save master consignee', e, s);
      rethrow;
    }
  }

  /// Update a master consignee
  Future<void> updateMasterConsignee(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      final db = await database;
      final data = {
        ...updates,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

      final rowsUpdated = await db.update(
        'master_consignees',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsUpdated == 0) {
        throw Exception('Master consignee not found: $id');
      }

      _logger.i('Master consignee updated: $id');
    } catch (e, s) {
      _logger.e('Failed to update master consignee', e, s);
      rethrow;
    }
  }

  /// Delete a master consignee
  Future<void> deleteMasterConsignee(String id) async {
    try {
      final db = await database;
      final rowsDeleted = await db.delete(
        'master_consignees',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsDeleted == 0) {
        throw Exception('Master consignee not found: $id');
      }

      _logger.i('Master consignee deleted: $id');
    } catch (e, s) {
      _logger.e('Failed to delete master consignee', e, s);
      rethrow;
    }
  }

  // ---------- MASTER PRODUCT TYPES ----------

  /// Get all master product types
  Future<List<Map<String, dynamic>>> getMasterProductTypes() async {
    try {
      final db = await database;
      final userId = getCurrentUserId();

      if (userId == null) {
        _logger
            .w('User not authenticated. Returning empty product types list.');
        return [];
      }

      final result = await db.query(
        'master_product_types',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'name ASC',
      );
      return result;
    } catch (e, s) {
      _logger.e('Failed to get master product types', e, s);
      return [];
    }
  }

  /// Save a master product type
  Future<String> saveMasterProductType(
    Map<String, dynamic> productTypeData,
  ) async {
    try {
      final db = await database;
      final userId = getCurrentUserId();

      if (userId == null) {
        throw Exception('User not authenticated. Cannot save product type.');
      }

      final now = DateTime.now().millisecondsSinceEpoch;

      final id = productTypeData['id'] ??
          'product_type_${now}_${DateTime.now().microsecond}';

      final data = {
        'id': id,
        'user_id': userId, // Add user ID
        'name': productTypeData['name'],
        'approx_quantity': productTypeData['approx_quantity'] ?? 1,
        'created_at': productTypeData['created_at'] ?? now,
        'updated_at': now,
      };

      await db.insert(
        'master_product_types',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _logger.i('Master product type saved: $id');
      return id;
    } catch (e, s) {
      _logger.e('Failed to save master product type', e, s);
      rethrow;
    }
  }

  /// Update a master product type
  Future<void> updateMasterProductType(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      final db = await database;
      final data = {
        ...updates,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };

      final rowsUpdated = await db.update(
        'master_product_types',
        data,
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsUpdated == 0) {
        throw Exception('Master product type not found: $id');
      }

      _logger.i('Master product type updated: $id');
    } catch (e, s) {
      _logger.e('Failed to update master product type', e, s);
      rethrow;
    }
  }

  /// Delete a master product type
  Future<void> deleteMasterProductType(String id) async {
    try {
      final db = await database;
      final rowsDeleted = await db.delete(
        'master_product_types',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (rowsDeleted == 0) {
        throw Exception('Master product type not found: $id');
      }

      _logger.i('Master product type deleted: $id');
    } catch (e, s) {
      _logger.e('Failed to delete master product type', e, s);
      rethrow;
    }
  }

  /// Search master data by name
  Future<List<Map<String, dynamic>>> searchMasterData(
    String table,
    String searchTerm,
  ) async {
    try {
      final db = await database;
      final result = await db.query(
        table,
        where: 'name LIKE ?',
        whereArgs: ['%$searchTerm%'],
        orderBy: 'name ASC',
      );
      return result;
    } catch (e, s) {
      _logger.e('Failed to search master data in $table', e, s);
      return [];
    }
  }

  // ========== USER MANAGEMENT METHODS ==========

  /// Clear all data for a specific user (when user logs out)
  Future<void> clearUserData(String userId) async {
    try {
      final db = await database;

      _logger.i('Clearing data for user: $userId');

      // Delete user-specific data from all tables
      await db.delete('shipments', where: 'user_id = ?', whereArgs: [userId]);
      await db.delete('drafts', where: 'user_id = ?', whereArgs: [userId]);
      await db
          .delete('master_shippers', where: 'user_id = ?', whereArgs: [userId]);
      await db.delete('master_consignees',
          where: 'user_id = ?', whereArgs: [userId]);
      await db.delete('master_product_types',
          where: 'user_id = ?', whereArgs: [userId]);
      await db
          .delete('flower_types', where: 'user_id = ?', whereArgs: [userId]);

      _logger.i('User data cleared successfully for: $userId');
    } catch (e, s) {
      _logger.e('Failed to clear user data', e, s);
      rethrow;
    }
  }

  /// Clear all data for all users (complete cleanup when switching users)
  Future<void> clearAllData() async {
    try {
      final db = await database;

      _logger.i('Clearing all local data');

      // Delete all data from user-specific tables
      await db.delete('shipments');
      await db.delete('boxes');
      await db.delete('products');
      await db.delete('drafts');
      await db.delete('master_shippers');
      await db.delete('master_consignees');
      await db.delete('master_product_types');
      await db.delete('flower_types');
      await db.delete('items');
      await db.delete('resources');

      _logger.i('All local data cleared successfully');
    } catch (e, s) {
      _logger.e('Failed to clear all data', e, s);
      rethrow;
    }
  }

  // ========== BOX OPERATIONS ==========

  /// Update a box
  Future<void> updateBox(String boxId, Map<String, dynamic> boxData) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final data = {
        ...boxData,
        'updated_at': now,
      };

      await db.update(
        'boxes',
        data,
        where: 'id = ?',
        whereArgs: [boxId],
      );
      _logger.i('Box updated: $boxId');
    } catch (e, s) {
      _logger.e('Failed to update box', e, s);
      rethrow;
    }
  }

  /// Delete a box
  Future<void> deleteBox(String boxId) async {
    try {
      final db = await database;
      await db.delete(
        'boxes',
        where: 'id = ?',
        whereArgs: [boxId],
      );
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
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;

      final data = {
        ...productData,
        'updated_at': now,
      };

      await db.update(
        'products',
        data,
        where: 'id = ?',
        whereArgs: [productId],
      );
      _logger.i('Product updated: $productId');
    } catch (e, s) {
      _logger.e('Failed to update product', e, s);
      rethrow;
    }
  }

  /// Delete a product
  Future<void> deleteProduct(String productId) async {
    try {
      final db = await database;
      await db.delete(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      );
      _logger.i('Product deleted: $productId');
    } catch (e, s) {
      _logger.e('Failed to delete product', e, s);
      rethrow;
    }
  }
}
