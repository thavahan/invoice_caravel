# 🗄️ Database Services Architecture Documentation

## 📚 Table of Contents
- [Overview](#overview)
- [Service Architecture](#service-architecture)
- [DatabaseService (Layer 1)](#databaseservice-layer-1)
- [LocalDatabaseService (Layer 2)](#localdatabaseservice-layer-2)
- [DataService (Layer 3)](#dataservice-layer-3)
- [Data Flow Diagrams](#data-flow-diagrams)
- [Usage Guidelines](#usage-guidelines)
- [API Reference](#api-reference)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

---

## 🎯 Overview

The Invoice Generator app uses a **three-layer database architecture** that provides:

- ✅ **Offline-first functionality** - Works without internet connection
- ✅ **Cloud synchronization** - Automatic backup to Firebase Firestore
- ✅ **Multi-user support** - Data isolation between users on same device
- ✅ **Robust error handling** - Graceful fallback to local storage
- ✅ **Real-time sync** - Automatic data synchronization when online

### Key Benefits
```
🔄 Hybrid Storage    📱 Offline Support    👥 Multi-User    🔐 Data Security
Local + Cloud        SQLite Fallback      User Isolation   Firebase Auth
```

---

## 🏗️ Service Architecture

### Layer Structure
```
┌─────────────────────────────────────────┐
│             UI SCREENS                  │
│    (InvoiceForm, MasterData, etc.)      │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│           DataService                   │ ← Layer 3: Coordinator
│    (Hybrid Firebase + Local)            │
└─────────────┬───────────┬───────────────┘
              │           │
    ┌─────────▼──────┐   │
    │ FirebaseService │   │
    │   (Cloud)      │   │
    └────────────────┘   │
                         │
              ┌──────────▼──────────┐
              │ LocalDatabaseService │ ← Layer 2: Business Logic
              │   (Model Wrapper)   │
              └──────────┬──────────┘
                         │
              ┌──────────▼──────────┐
              │   DatabaseService   │ ← Layer 1: Raw SQLite
              │   (SQLite Engine)   │
              └─────────────────────┘
```

### Service Relationships
| Service | Layer | Purpose | Dependencies |
|---------|-------|---------|--------------|
| `DatabaseService` | 1 | Raw SQLite operations | SQLite database |
| `LocalDatabaseService` | 2 | Business logic & models | `DatabaseService` |
| `DataService` | 3 | Hybrid coordinator | `LocalDatabaseService` + `FirebaseService` |

---

## 🔧 DatabaseService (Layer 1)

**File:** `lib/services/database_service.dart`  
**Purpose:** Raw SQLite database operations and schema management

### Responsibilities
- 🗃️ **Database Schema** - Creates and manages all SQLite tables
- 🔍 **Raw SQL Operations** - Direct INSERT, UPDATE, DELETE, SELECT
- 👤 **User Isolation** - Filters all queries by `user_id`
- 🔄 **Database Upgrades** - Handles schema migrations
- 📊 **Core CRUD** - Basic create, read, update, delete operations

### Database Schema
```sql
-- Main Tables
shipments            -- Invoice/shipment data
boxes               -- Box information for shipments  
products            -- Product details in boxes
drafts              -- Draft invoices

-- Master Data Tables
master_shippers         -- Shipper master data
master_consignees       -- Consignee master data  
master_product_types    -- Product types master data
flower_types            -- Flower types data

-- Legacy/Support Tables
items               -- Legacy invoice items
resources           -- App configuration
```

### Key Methods
```dart
// Database Management
Future<Database> get database async
Future<void> _initDatabase()
Future<void> _createTables(Database db, int version)

// User Management  
void setCurrentUserId(String? userId)
String? getCurrentUserId()

// Shipment Operations
Future<String> saveShipment(Map<String, dynamic> shipmentData)
Future<List<Map<String, dynamic>>> getShipments({String? status})
Future<Map<String, dynamic>?> getShipment(String invoiceNumber)
Future<void> updateShipment(String invoiceNumber, Map<String, dynamic> updates)
Future<void> deleteShipment(String invoiceNumber)

// Box Operations
Future<String> saveBox(Map<String, dynamic> boxData)
Future<List<Map<String, dynamic>>> getBoxesForShipment(String shipmentInvoiceNumber)

// Product Operations  
Future<String> saveProduct(Map<String, dynamic> productData)
Future<List<Map<String, dynamic>>> getProductsForBox(String boxId)

// Master Data Operations
Future<List<Map<String, dynamic>>> getMasterShippers()
Future<String> saveMasterShipper(Map<String, dynamic> shipperData)
Future<void> updateMasterShipper(String id, Map<String, dynamic> updates)
Future<void> deleteMasterShipper(String id)
// Similar methods for consignees and product types...

// Draft Operations
Future<String> saveDraft(Map<String, dynamic> draftData)
Future<List<Map<String, dynamic>>> getDrafts()

// Utility Operations
Future<void> initializeDefaultData()
Future<Map<String, dynamic>> getDatabaseStats()
Future<Map<String, dynamic>> getUserDatabaseStats()
Future<void> clearUserData(String userId)
Future<void> clearAllData()
```

### User Isolation Pattern
All operations automatically filter by current user:
```dart
// Example: Getting shipments for current user only
Future<List<Map<String, dynamic>>> getShipments({String? status}) async {
  final userId = getCurrentUserId();
  if (userId == null) return [];
  
  String query = 'SELECT * FROM shipments WHERE user_id = ?';
  List<dynamic> args = [userId];
  
  if (status != null) {
    query += ' AND status = ?';
    args.add(status);
  }
  
  final results = await db.rawQuery(query, args);
  return results;
}
```

### Database Indexes
Optimized for performance:
```sql
CREATE INDEX idx_shipments_awb ON shipments (awb);
CREATE INDEX idx_shipments_status ON shipments (status);
CREATE INDEX idx_shipments_user_id ON shipments (user_id);
CREATE INDEX idx_boxes_shipment ON boxes (shipment_invoice_number);
CREATE INDEX idx_products_box ON products (box_id);
CREATE INDEX idx_master_shippers_user_id ON master_shippers (user_id);
-- ... additional indexes for all user-filtered tables
```

---

## 📦 LocalDatabaseService (Layer 2)

**File:** `lib/services/local_database_service.dart`  
**Purpose:** Business logic wrapper with model conversion

### Responsibilities
- 🔄 **Model Conversion** - Converts between Dart objects and SQLite maps
- 🏗️ **Business Operations** - High-level operations like publishDraft()
- 🔗 **Data Relationships** - Handles complex object relationships
- 🔌 **Legacy Support** - Maintains backward compatibility
- 📋 **Service Initialization** - Sets up database and default data

### Model Conversion Examples
```dart
// Shipment Model Conversion
Future<void> saveShipment(Shipment shipment) async {
  await _db.saveShipment(shipment.toSQLite()); // Model → SQL Map
}

Future<List<Shipment>> getShipments({String? status, int limit = 50}) async {
  final results = await _db.getShipments(status: status);
  return results
    .take(limit)
    .map((data) => Shipment.fromSQLite(data))  // SQL Map → Model
    .toList();
}
```

### Complex Business Operations
```dart
// Publishing Draft to Shipment (Complex Operation)
Future<String> publishDraft(String draftId) async {
  // 1. Load draft data
  final drafts = await getDrafts();
  final draft = drafts.firstWhere((d) => d['id'] == draftId);
  final draftData = draft['draftData'] as Map<String, dynamic>;
  
  // 2. Create shipment from draft
  final shipment = Shipment(
    invoiceNumber: draftData['invoiceNumber'] ?? generateInvoiceNumber(),
    shipper: draftData['shipper'] ?? '',
    consignee: draftData['consignee'] ?? '',
    // ... other fields
  );
  
  // 3. Save shipment
  await saveShipment(shipment);
  
  // 4. Save related boxes and products
  if (draftData['boxes'] != null) {
    final boxes = draftData['boxes'] as List<dynamic>;
    for (final boxData in boxes) {
      final boxId = await saveBox(shipment.invoiceNumber, boxData);
      
      if (boxData['products'] != null) {
        final products = boxData['products'] as List<dynamic>;
        for (final productData in products) {
          await saveProduct(boxId, productData);
        }
      }
    }
  }
  
  // 5. Delete the draft
  await deleteDraft(draftId);
  
  return shipment.invoiceNumber;
}
```

### Key Methods
```dart
// Service Management
Future<void> initialize()
Future<Map<String, dynamic>> loadData()

// Shipment Operations (with Models)
Future<void> saveShipment(Shipment shipment)
Future<List<Shipment>> getShipments({String? status, int limit = 50})
Future<Shipment?> getShipment(String invoiceNumber)
Future<void> updateShipment(String id, Map<String, dynamic> updates)
Future<void> deleteShipment(String id)
Future<void> updateShipmentStatus(String shipmentId, String status)

// Box Operations (with Models)
Future<String> saveBox(String shipmentId, Map<String, dynamic> boxData)
Future<List<ShipmentBox>> getBoxesForShipment(String shipmentId)

// Product Operations (with Models)
Future<String> saveProduct(String boxId, Map<String, dynamic> productData)
Future<List<ShipmentProduct>> getProductsForBox(String boxId)

// Draft Operations
Future<String> saveDraft(Map<String, dynamic> draftData)
Future<List<Map<String, dynamic>>> getDrafts()
Future<void> deleteDraft(String draftId)
Future<String> publishDraft(String draftId)

// Master Data Operations (with Models)
Future<List<MasterShipper>> getMasterShippers()
Future<String> saveMasterShipper(MasterShipper shipper)
Future<void> updateMasterShipper(String id, Map<String, dynamic> updates)
Future<void> deleteMasterShipper(String id)
// Similar methods for MasterConsignee and MasterProductType...

// Legacy Support
Future<void> saveInvoice(Invoice invoice)
Future<List<FlowerType>> getFlowerTypes()

// Statistics and Search
Future<Map<String, dynamic>> getStats()
Future<Map<String, dynamic>> getShipmentStats()
Future<List<Shipment>> searchShipments(String query)
```

### Relationship Handling
```dart
// Loading Boxes with their Products
Future<List<ShipmentBox>> getBoxesForShipment(String shipmentId) async {
  final results = await _db.getBoxesForShipment(shipmentId);
  final boxes = <ShipmentBox>[];

  for (final boxData in results) {
    final box = ShipmentBox.fromSQLite(boxData);
    
    // Load products for this box
    final products = await getProductsForBox(box.id);
    final boxWithProducts = box.copyWith(products: products);
    
    boxes.add(boxWithProducts);
  }

  return boxes;
}
```

---

## 🌐 DataService (Layer 3)

**File:** `lib/services/data_service.dart`  
**Purpose:** Hybrid coordinator between Firebase and Local storage

### Responsibilities
- 🔄 **Hybrid Storage** - Coordinates between Firebase and SQLite
- 📡 **Connectivity Awareness** - Switches storage based on internet
- 🔄 **Automatic Sync** - Syncs data between cloud and local
- 🎯 **Unified API** - Single interface for UI components
- ⚡ **Performance Optimization** - Smart caching and fallbacks

### Storage Decision Logic
```dart
Future<bool> _shouldUseFirebase() async {
  if (_forceOffline) return false;
  
  // Check Firebase initialization
  if (!_firebaseService.isInitialized) return false;
  
  // Check internet connectivity
  final results = await _connectivity.checkConnectivity();
  final isOnline = results.isNotEmpty && 
    results.any((result) => result != ConnectivityResult.none);
    
  return isOnline && _preferFirebase;
}
```

### Hybrid Save Operations
```dart
Future<void> saveShipment(Shipment shipment) async {
  try {
    // Always save to local database first (reliable)
    await _localService.saveShipment(shipment);
    _logger.i('Shipment saved to local database');
    
    // Try to save to Firebase if available
    if (await _shouldUseFirebase()) {
      try {
        await _firebaseService.saveShipment(shipment);
        _logger.i('Shipment synced to Firebase');
      } catch (e) {
        _logger.w('Failed to sync shipment to Firebase: $e');
        // Don't throw - local save succeeded
      }
    }
  } catch (e) {
    _logger.e('Failed to save shipment', e);
    rethrow;
  }
}
```

### Automatic Synchronization
```dart
Future<void> syncFromFirebaseToLocal({Function(String)? onProgress}) async {
  try {
    if (!(await _isFirebaseAvailable())) {
      _logger.w('Firebase not available for sync');
      return;
    }

    _logger.i('Starting sync from Firebase to local database...');
    
    // Sync master data first
    onProgress?.call('Syncing master data...');
    await _syncMasterDataFromFirebase(onProgress);

    // Sync shipments
    onProgress?.call('Syncing shipments...');
    await _syncShipmentsFromFirebase(onProgress);

    // Sync drafts
    onProgress?.call('Syncing drafts...');
    await _syncDraftsFromFirebase(onProgress);

    onProgress?.call('Sync completed!');
    _logger.i('Sync from Firebase to local database completed successfully');
  } catch (e, s) {
    _logger.e('Failed to sync from Firebase to local database', e, s);
    onProgress?.call('Sync failed: ${e.toString()}');
    throw Exception('Failed to sync data from cloud: ${e.toString()}');
  }
}
```

### Key Methods
```dart
// Service Management
Future<void> initialize()
Future<void> initializeUserCollections()
void setConnectivityChangeCallback(Function() callback)

// Hybrid Shipment Operations
Future<void> saveShipment(Shipment shipment)
Future<List<Shipment>> getShipments({String? status})
Future<Shipment?> getShipment(String invoiceNumber)
Future<void> updateShipment(String id, Map<String, dynamic> updates)
Future<void> deleteShipment(String id)

// Shipment with Boxes Creation
Future<void> createShipmentWithBoxes(Shipment shipment, List<Map<String, dynamic>> boxes)

// Hybrid Master Data Operations
Future<List<MasterShipper>> getMasterShippers()
Future<void> saveMasterShipper(Map<String, dynamic> shipperData)
Future<void> updateMasterShipper(String id, Map<String, dynamic> updates)
Future<void> deleteMasterShipper(String id)
// Similar methods for consignees and product types...

// Synchronization Operations
Future<void> syncFromFirebaseToLocal({Function(String)? onProgress})
Future<void> syncFromLocalToFirebase({Function(String)? onProgress})
Future<void> _syncMasterDataFromFirebase(Function(String)? onProgress)
Future<void> _syncShipmentsFromFirebase(Function(String)? onProgress)
Future<void> _syncDraftsFromFirebase(Function(String)? onProgress)

// Configuration
void setPreferFirebase(bool prefer)
void setForceOffline(bool offline)
```

### Sync Progress Tracking
```dart
Future<void> _syncMasterDataFromFirebase(Function(String)? onProgress) async {
  // Sync shippers
  onProgress?.call('Syncing shippers...');
  final firebaseShippers = await _firebaseService.getMasterShippers();
  for (final shipper in firebaseShippers) {
    try {
      await _localService.saveMasterShipper(shipper);
    } catch (e) {
      _logger.w('Failed to sync shipper ${shipper.id}: $e');
    }
  }

  // Sync consignees  
  onProgress?.call('Syncing consignees...');
  final firebaseConsignees = await _firebaseService.getMasterConsignees();
  for (final consignee in firebaseConsignees) {
    try {
      await _localService.saveMasterConsignee(consignee);
    } catch (e) {
      _logger.w('Failed to sync consignee ${consignee.id}: $e');
    }
  }

  // Sync product types
  onProgress?.call('Syncing product types...');
  final firebaseProductTypes = await _firebaseService.getMasterProductTypes();
  for (final productType in firebaseProductTypes) {
    try {
      await _localService.saveMasterProductType(productType);
    } catch (e) {
      _logger.w('Failed to sync product type ${productType.id}: $e');
    }
  }
}
```

---

## 🔄 Data Flow Diagrams

### Save Operation Flow
```
UI Screen
    ↓ saveShipment(shipment)
DataService
    ↓ Always save local first
LocalDatabaseService
    ↓ Convert model to SQL
DatabaseService
    ↓ INSERT into SQLite
✅ Local Save Complete
    ↓ Then try Firebase (if online)
FirebaseService
    ↓ Save to Firestore
✅ Cloud Sync Complete
```

### Load Operation Flow
```
UI Screen
    ↓ getShipments()
DataService
    ↓ Check preference & connectivity
    ├─ Online + Prefer Firebase
    │   ↓
    │ FirebaseService
    │   ↓ Load from Firestore
    │ ✅ Return Firebase data
    │
    └─ Offline OR Prefer Local
        ↓
    LocalDatabaseService
        ↓ Load from SQLite
        ↓ Convert SQL to models
    ✅ Return Local data
```

### Sync Operation Flow
```
User Login / Manual Sync
    ↓
AuthProvider / UI
    ↓ syncFromFirebaseToLocal()
DataService
    ↓ Check Firebase availability
    ├─ Firebase Available
    │   ↓
    │ Load from Firebase
    │   ↓ getMasterShippers()
    │   ↓ getShipments()
    │   ↓ getDrafts()
    │ Save to Local
    │   ↓ saveMasterShipper()
    │   ↓ saveShipment()
    │   ↓ saveDraft()
    │ ✅ Sync Complete
    │
    └─ Firebase Unavailable
        ↓
    ✅ Skip sync, use local data
```

---

## 📋 Usage Guidelines

### For UI Developers

#### ✅ DO: Use DataService for all operations
```dart
class InvoiceFormScreen extends StatefulWidget {
  final DataService _dataService = DataService();
  
  Future<void> _saveInvoice() async {
    await _dataService.saveShipment(shipment);  // ✅ Hybrid storage
    await _dataService.saveMasterShipper(shipper);  // ✅ Auto-sync
  }
}
```

#### ❌ DON'T: Use lower-level services directly
```dart
class InvoiceFormScreen extends StatefulWidget {
  final LocalDatabaseService _localService = LocalDatabaseService();  // ❌ No Firebase
  final DatabaseService _dbService = DatabaseService();  // ❌ No models
  
  Future<void> _saveInvoice() async {
    await _localService.saveShipment(shipment);  // ❌ Local only
    await _dbService.saveShipment(rawData);  // ❌ Raw SQL maps
  }
}
```

### For Service Developers

#### Service Layer Responsibilities
| Layer | Use When | Don't Use When |
|-------|----------|----------------|
| `DatabaseService` | Adding new tables, raw SQL optimization | UI operations, model conversion |
| `LocalDatabaseService` | Complex business logic, model handling | Direct UI calls, Firebase operations |
| `DataService` | All UI operations, sync management | Raw database operations |

#### Adding New Features

1. **New Database Table**
   ```dart
   // 1. Add to DatabaseService._createTables()
   await db.execute('''CREATE TABLE new_table (...)''');
   
   // 2. Add CRUD methods to DatabaseService
   Future<String> saveNewEntity(Map<String, dynamic> data) async { ... }
   
   // 3. Add model conversion to LocalDatabaseService
   Future<void> saveNewEntity(NewEntity entity) async {
     await _db.saveNewEntity(entity.toSQLite());
   }
   
   // 4. Add hybrid operations to DataService
   Future<void> saveNewEntity(NewEntity entity) async {
     await _localService.saveNewEntity(entity);
     if (await _shouldUseFirebase()) {
       await _firebaseService.saveNewEntity(entity);
     }
   }
   ```

2. **New Business Operation**
   ```dart
   // Add to LocalDatabaseService
   Future<String> complexBusinessOperation() async {
     // Multi-step operation with transactions
     final db = await _db.database;
     return await db.transaction((txn) async {
       // Step 1: Save main entity
       final id = await _saveMainEntity(txn);
       
       // Step 2: Save related entities  
       await _saveRelatedEntities(txn, id);
       
       // Step 3: Update references
       await _updateReferences(txn, id);
       
       return id;
     });
   }
   ```

---

## 📖 API Reference

### DatabaseService API

#### Database Management
```dart
Future<Database> get database async
void setCurrentUserId(String? userId)
String? getCurrentUserId()
```

#### Shipment Operations
```dart
Future<String> saveShipment(Map<String, dynamic> shipmentData)
Future<List<Map<String, dynamic>>> getShipments({String? status})
Future<Map<String, dynamic>?> getShipment(String invoiceNumber)
Future<void> updateShipment(String invoiceNumber, Map<String, dynamic> updates)
Future<void> deleteShipment(String invoiceNumber)
```

#### Master Data Operations
```dart
// Shippers
Future<List<Map<String, dynamic>>> getMasterShippers()
Future<String> saveMasterShipper(Map<String, dynamic> shipperData)
Future<void> updateMasterShipper(String id, Map<String, dynamic> updates)
Future<void> deleteMasterShipper(String id)

// Consignees (similar pattern)
Future<List<Map<String, dynamic>>> getMasterConsignees()
Future<String> saveMasterConsignee(Map<String, dynamic> consigneeData)
Future<void> updateMasterConsignee(String id, Map<String, dynamic> updates)
Future<void> deleteMasterConsignee(String id)

// Product Types (similar pattern)
Future<List<Map<String, dynamic>>> getMasterProductTypes()
Future<String> saveMasterProductType(Map<String, dynamic> productTypeData)
Future<void> updateMasterProductType(String id, Map<String, dynamic> updates)
Future<void> deleteMasterProductType(String id)
```

### LocalDatabaseService API

#### Service Management
```dart
Future<void> initialize()
Future<Map<String, dynamic>> loadData()
```

#### Shipment Operations (Model-based)
```dart
Future<void> saveShipment(Shipment shipment)
Future<List<Shipment>> getShipments({String? status, int limit = 50})
Future<Shipment?> getShipment(String invoiceNumber)
Future<void> updateShipment(String id, Map<String, dynamic> updates)
Future<void> deleteShipment(String id)
Future<void> updateShipmentStatus(String shipmentId, String status)
```

#### Box and Product Operations
```dart
Future<String> saveBox(String shipmentId, Map<String, dynamic> boxData)
Future<List<ShipmentBox>> getBoxesForShipment(String shipmentId)
Future<String> saveProduct(String boxId, Map<String, dynamic> productData)  
Future<List<ShipmentProduct>> getProductsForBox(String boxId)
```

#### Master Data Operations (Model-based)
```dart
// Shippers
Future<List<MasterShipper>> getMasterShippers()
Future<String> saveMasterShipper(MasterShipper shipper)
Future<void> updateMasterShipper(String id, Map<String, dynamic> updates)
Future<void> deleteMasterShipper(String id)

// Consignees
Future<List<MasterConsignee>> getMasterConsignees()
Future<String> saveMasterConsignee(MasterConsignee consignee)
Future<void> updateMasterConsignee(String id, Map<String, dynamic> updates)
Future<void> deleteMasterConsignee(String id)

// Product Types
Future<List<MasterProductType>> getMasterProductTypes()
Future<String> saveMasterProductType(MasterProductType productType)
Future<void> updateMasterProductType(String id, Map<String, dynamic> updates)
Future<void> deleteMasterProductType(String id)
```

### DataService API

#### Service Management
```dart
Future<void> initialize()
Future<void> initializeUserCollections()
void setConnectivityChangeCallback(Function() callback)
void setPreferFirebase(bool prefer)
void setForceOffline(bool offline)
```

#### Hybrid Operations
```dart
// Shipment Operations
Future<void> saveShipment(Shipment shipment)
Future<List<Shipment>> getShipments({String? status})
Future<Shipment?> getShipment(String invoiceNumber)
Future<void> updateShipment(String id, Map<String, dynamic> updates)
Future<void> deleteShipment(String id)

// Complex Operations
Future<void> createShipmentWithBoxes(Shipment shipment, List<Map<String, dynamic>> boxes)

// Master Data Operations  
Future<List<MasterShipper>> getMasterShippers()
Future<void> saveMasterShipper(Map<String, dynamic> shipperData)
Future<void> updateMasterShipper(String id, Map<String, dynamic> updates)
Future<void> deleteMasterShipper(String id)

// Synchronization
Future<void> syncFromFirebaseToLocal({Function(String)? onProgress})
Future<void> syncFromLocalToFirebase({Function(String)? onProgress})
```

---

## 🔧 Troubleshooting

### Common Issues

#### 1. Data Not Syncing to Firebase
**Symptoms:** Data saves locally but doesn't appear in Firebase Console  
**Causes & Solutions:**
```dart
// Check DataService initialization
final dataService = DataService();
await dataService.initialize();  // Must call this first

// Check connectivity
final results = await Connectivity().checkConnectivity();
print('Connected: ${results}');

// Check Firebase availability  
print('Firebase available: ${await dataService._isFirebaseAvailable()}');

// Force Firebase sync
dataService.setPreferFirebase(true);
await dataService.syncFromLocalToFirebase();
```

#### 2. User Data Isolation Issues
**Symptoms:** Users seeing each other's data  
**Causes & Solutions:**
```dart
// Verify user ID is set
final userId = DatabaseService().getCurrentUserId();
print('Current user ID: $userId');

// Check AuthProvider sets user ID
void _onAuthStateChanged(User? user) async {
  DatabaseService().setCurrentUserId(user?.uid);  // ✅ Must do this
}
```

#### 3. Database Migration Errors
**Symptoms:** App crashes on database operations  
**Causes & Solutions:**
```dart
// Clear app data if schema changed
await DatabaseService().clearAllData();

// Or handle migration in _upgradeDatabase
Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    // Add new columns
    await db.execute('ALTER TABLE shipments ADD COLUMN new_field TEXT');
  }
}
```

### Debug Logging
Enable detailed logging to trace issues:
```dart
// Add to each service
final _logger = Logger();

// In operations
_logger.i('Starting operation...');
_logger.w('Warning: fallback used');
_logger.e('Error occurred', error, stackTrace);
```

### Performance Monitoring
```dart
// Monitor database operations
final stopwatch = Stopwatch()..start();
await databaseOperation();
stopwatch.stop();
_logger.i('Operation took: ${stopwatch.elapsedMilliseconds}ms');

// Monitor sync operations  
int syncedCount = 0;
await dataService.syncFromFirebaseToLocal(
  onProgress: (status) {
    print('Sync progress: $status');
    syncedCount++;
  },
);
print('Synced $syncedCount items');
```

---

## ✅ Best Practices

### Performance Optimization

#### 1. Use Batch Operations
```dart
// ✅ Good: Batch insert
final db = await database;
final batch = db.batch();
for (final item in items) {
  batch.insert('table_name', item);
}
await batch.commit();

// ❌ Bad: Individual inserts  
for (final item in items) {
  await db.insert('table_name', item);  // N database calls
}
```

#### 2. Use Transactions for Complex Operations
```dart
// ✅ Good: Atomic operation
await db.transaction((txn) async {
  final shipmentId = await saveShipment(txn, shipmentData);
  await saveBoxes(txn, shipmentId, boxes);
  await saveProducts(txn, boxes);
});

// ❌ Bad: Separate operations
await saveShipment(shipmentData);  // Could fail here
await saveBoxes(shipmentId, boxes);  // Leaving inconsistent state
await saveProducts(boxes);
```

#### 3. Implement Pagination
```dart
// ✅ Good: Paginated loading
Future<List<Shipment>> getShipments({int offset = 0, int limit = 20}) async {
  final results = await db.query(
    'shipments',
    limit: limit,
    offset: offset,
    orderBy: 'created_at DESC',
  );
  return results.map((data) => Shipment.fromSQLite(data)).toList();
}

// ❌ Bad: Load everything
Future<List<Shipment>> getAllShipments() async {
  final results = await db.query('shipments');  // Could be huge
  return results.map((data) => Shipment.fromSQLite(data)).toList();
}
```

### Error Handling

#### 1. Graceful Degradation
```dart
Future<void> saveShipment(Shipment shipment) async {
  try {
    // Always save locally first (reliable)
    await _localService.saveShipment(shipment);
    
    // Try Firebase sync (best effort)
    if (await _shouldUseFirebase()) {
      try {
        await _firebaseService.saveShipment(shipment);
      } catch (e) {
        _logger.w('Firebase sync failed, data saved locally: $e');
        // Don't rethrow - local save succeeded
      }
    }
  } catch (e) {
    _logger.e('Failed to save shipment locally', e);
    rethrow;  // This is critical failure
  }
}
```

#### 2. Connection Handling
```dart
Future<bool> _shouldUseFirebase() async {
  try {
    // Check multiple conditions
    if (_forceOffline) return false;
    if (!_firebaseService.isInitialized) return false;
    
    final results = await _connectivity.checkConnectivity()
        .timeout(Duration(seconds: 2));  // Don't wait forever
    
    return results.isNotEmpty && 
           results.any((result) => result != ConnectivityResult.none);
  } catch (e) {
    _logger.w('Connectivity check failed, assuming offline: $e');
    return false;  // Safe default
  }
}
```

### Security

#### 1. User Data Isolation
```dart
// ✅ Always filter by user_id
Future<List<Map<String, dynamic>>> getUserData() async {
  final userId = getCurrentUserId();
  if (userId == null) {
    throw Exception('User not authenticated');
  }
  
  return await db.query(
    'table_name',
    where: 'user_id = ?',
    whereArgs: [userId],
  );
}

// ❌ Never return unfiltered data
Future<List<Map<String, dynamic>>> getAllData() async {
  return await db.query('table_name');  // Exposes all users' data
}
```

#### 2. Input Validation
```dart
Future<void> saveShipment(Map<String, dynamic> data) async {
  // Validate required fields
  if (data['awb']?.toString().trim().isEmpty ?? true) {
    throw Exception('AWB is required');
  }
  
  // Sanitize input
  final sanitizedData = {
    ...data,
    'awb': data['awb'].toString().trim(),
    'user_id': getCurrentUserId(),  // Always set current user
  };
  
  await db.insert('shipments', sanitizedData);
}
```

### Maintenance

#### 1. Regular Cleanup
```dart
// Clean up old data periodically
Future<void> cleanupOldData() async {
  final cutoffDate = DateTime.now().subtract(Duration(days: 365));
  final cutoffTimestamp = cutoffDate.millisecondsSinceEpoch;
  
  await db.delete(
    'shipments',
    where: 'status = ? AND created_at < ?',
    whereArgs: ['cancelled', cutoffTimestamp],
  );
}
```

#### 2. Database Health Monitoring
```dart
Future<Map<String, dynamic>> getDatabaseHealth() async {
  final stats = await getDatabaseStats();
  
  return {
    'total_shipments': stats['shipments'] ?? 0,
    'database_size_mb': await _getDatabaseSizeMB(),
    'oldest_record_days': await _getOldestRecordDays(),
    'needs_cleanup': stats['shipments'] > 10000,
  };
}
```

---

## 📝 Migration Guide

### From Single Service to Three-Layer Architecture

#### Before (Old Pattern)
```dart
// Old way - direct database access
class InvoiceScreen extends StatefulWidget {
  final Database db;
  
  Future<void> saveData() async {
    await db.insert('shipments', data);  // Raw SQL
  }
}
```

#### After (New Pattern)  
```dart
// New way - layered architecture
class InvoiceScreen extends StatefulWidget {
  final DataService _dataService = DataService();
  
  Future<void> saveData() async {
    await _dataService.saveShipment(shipment);  // Model-based, hybrid storage
  }
}
```

### Adding Firebase Support to Existing Features

1. **Update LocalDatabaseService** (if needed)
2. **Add FirebaseService methods** for the feature
3. **Add DataService hybrid methods**
4. **Update UI to use DataService**

Example:
```dart
// 1. LocalDatabaseService already has the method
Future<void> saveMasterShipper(MasterShipper shipper) async { ... }

// 2. Add to FirebaseService
Future<void> saveMasterShipper(MasterShipper shipper) async {
  await firestore
    .collection('users/${currentUserId}/master_shippers')
    .doc(shipper.id)
    .set(shipper.toMap());
}

// 3. Add to DataService  
Future<void> saveMasterShipper(Map<String, dynamic> shipperData) async {
  final shipper = MasterShipper.fromMap(shipperData);
  
  // Save locally first
  await _localService.saveMasterShipper(shipper);
  
  // Sync to Firebase if available
  if (await _shouldUseFirebase()) {
    await _firebaseService.saveMasterShipper(shipper);
  }
}

// 4. Update UI
await _dataService.saveMasterShipper(shipperData);  // Was: _databaseService
```

---

*Last Updated: November 18, 2025*  
*Documentation Version: 1.0*  
*App Version: 3.0.0+1*