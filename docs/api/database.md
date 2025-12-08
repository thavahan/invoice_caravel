# Database & Firestore Services - Complete Documentation & Implementation Guide

**Project:** Invoice Generator Mobile App  
**Component:** Database Services & Firebase Firestore Integration  
**Status:** ✅ Production Ready - Dual Storage Architecture  
**Last Updated:** December 9, 2025  

---

## 📋 Table of Contents

1. [Implementation Overview](#implementation-overview)
2. [Architecture & Design](#architecture--design)
3. [Database Services Layer](#database-services-layer)
4. [Firebase Firestore Integration](#firebase-firestore-integration)
5. [Data Synchronization System](#data-synchronization-system)
6. [Authentication & User Management](#authentication--user-management)
7. [Offline Capabilities](#offline-capabilities)
8. [API Reference](#api-reference)
9. [Usage Examples](#usage-examples)
10. [Troubleshooting](#troubleshooting)
11. [Performance & Security](#performance--security)
12. [Best Practices](#best-practices)

---

## 🎯 Implementation Overview

### Current Status
- **✅ Three-Layer Architecture:** DatabaseService, LocalDatabaseService, DataService
- **✅ Dual Storage System:** Local SQLite + Firebase Firestore
- **✅ Offline-First Design:** Works without internet connection
- **✅ Auto-Sync System:** Automatic synchronization on login
- **✅ Multi-User Support:** Data isolation between users
- **✅ Real-Time Sync:** Manual and automatic synchronization

### Key Capabilities
```
🗄️ Local Storage (SQLite)
├─ Primary data storage for offline access
├─ User-isolated data with authentication
├─ Complete invoice, shipment, and master data
└─ Instant access and performance

☁️ Cloud Storage (Firebase Firestore)
├─ Automatic backup and synchronization
├─ Cross-device data access
├─ Real-time collaborative features
└─ Data recovery and redundancy

🔄 Synchronization Engine
├─ Auto-sync on login (Firestore → Local)
├─ Manual sync operations (Local → Firestore)
├─ Bi-directional data flow
└─ Conflict resolution and duplicate prevention
```

---

## 🏗️ Architecture & Design

### Three-Layer Database Architecture

```
┌─────────────────────────────────────────┐
│             UI SCREENS                  │
│    (InvoiceForm, MasterData, etc.)      │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│           DataService                   │ ← Layer 3: Coordinator
│    (Hybrid Firebase + Local)            │
│    - saveShipment()                     │
│    - syncFromFirebase()                 │
│    - syncToFirebase()                   │
└─────────────┬───────────┬───────────────┘
              │           │
    ┌─────────▼──────┐   ┌▼────────────────┐
    │ FirebaseService │   │LocalDatabaseService│ ← Layer 2
    │    (Cloud)      │   │    (SQLite)     │
    │ - addShipment() │   │ - saveShipment()│
    │ - getShipments()│   │ - getShipments()│
    └─────────────────┘   └─────────────────┘
                          │
                     ┌────▼─────────────────┐
                     │   DatabaseService    │ ← Layer 1
                     │  (Core SQLite)       │
                     │ - createTables()     │
                     │ - executeQuery()     │
                     └──────────────────────┘
```

### Data Flow Architecture

```
┌─────────────────────────────────────────┐
│            USER ACTIONS                 │
│  Create Invoice | Update Data | Login   │
└─────────────────┬───────────────────────┘
                  │
┌─────────────────▼───────────────────────┐
│           DATASERVICE                   │
│  ┌─────────────────────────────────────┐│
│  │ Operation Decision Engine           ││
│  │ • Check connectivity               ││
│  │ • Determine storage target         ││
│  │ • Execute dual storage             ││
│  └─────────────────────────────────────┘│
└─────┬─────────────────────────────┬─────┘
      │                             │
┌─────▼──────┐              ┌───────▼─────┐
│ FIREBASE   │              │ LOCAL DB    │
│ FIRESTORE  │◄────────────►│ SQLITE      │
│ (Cloud)    │  Sync Ops    │ (Offline)   │
└────────────┘              └─────────────┘
      │                             │
      ▼                             ▼
┌──────────────────────────────────────────┐
│         SYNCHRONIZED DATA                │
│  • Invoices/Shipments                   │
│  • Master Data (Products, Clients)      │
│  • User Preferences                     │
│  • Box & Product Details                │
└──────────────────────────────────────────┘
```

---

## 🗄️ Database Services Layer

### Layer 1: DatabaseService (Core SQLite)
**File:** `lib/services/database_service.dart`

```dart
class DatabaseService {
  static Database? _database;
  
  // Database initialization and connection
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }
  
  // Core database operations
  Future<Database> _initDatabase() async;
  Future<void> createTables() async;
  Future<List<Map<String, dynamic>>> executeQuery(String query, List<dynamic> params) async;
  Future<int> executeInsert(String query, List<dynamic> params) async;
  Future<void> executeUpdate(String query, List<dynamic> params) async;
  Future<void> executeDelete(String query, List<dynamic> params) async;
}
```

**Key Features:**
- SQLite database initialization and management
- Core CRUD operations
- Table creation and schema management
- Query execution with parameter binding
- Transaction support

### Layer 2: LocalDatabaseService (Business Logic)
**File:** `lib/services/local_database_service.dart`

```dart
class LocalDatabaseService {
  final DatabaseService _db = DatabaseService();
  
  // Shipment operations
  Future<void> saveShipment(Shipment shipment, String userId) async;
  Future<List<Shipment>> getAllShipments(String userId) async;
  Future<void> updateShipment(Shipment shipment, String userId) async;
  Future<void> deleteShipment(String shipmentId, String userId) async;
  
  // Box and Product operations
  Future<void> saveBox(String shipmentId, Map<String, dynamic> boxData) async;
  Future<void> saveProduct(String boxId, Map<String, dynamic> productData) async;
  Future<List<Map<String, dynamic>>> getBoxesForShipment(String shipmentId) async;
  
  // Master data operations
  Future<void> saveMasterData(String type, Map<String, dynamic> data, String userId) async;
  Future<List<Map<String, dynamic>>> getMasterData(String type, String userId) async;
}
```

**Key Features:**
- Business logic for data operations
- User-specific data isolation
- Shipment and invoice management
- Box and product handling
- Master data management (products, clients, etc.)

### Layer 3: DataService (Hybrid Coordinator)
**File:** `lib/services/data_service.dart`

```dart
class DataService {
  final LocalDatabaseService _localDb = LocalDatabaseService();
  final FirebaseService _firebaseService = FirebaseService();
  
  // Hybrid operations (Local + Cloud)
  Future<void> saveShipment(Shipment shipment, String userId) async {
    // Save to local database first (offline capability)
    await _localDb.saveShipment(shipment, userId);
    
    // Attempt cloud backup
    try {
      await _firebaseService.addShipment(shipment, userId);
    } catch (e) {
      print('Cloud backup failed, data saved locally: $e');
    }
  }
  
  // Synchronization operations
  Future<void> syncFromFirebase(String userId) async;
  Future<void> syncToFirebase(String userId) async;
  Future<void> performFullSync(String userId) async;
}
```

**Key Features:**
- Coordinates local and cloud operations
- Automatic fallback to local storage
- Bi-directional synchronization
- Error handling and recovery
- Offline-first approach

---

## ☁️ Firebase Firestore Integration

### FirebaseService Architecture
**File:** `lib/services/firebase_service.dart`

```dart
class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ConnectivityPlus _connectivity = ConnectivityPlus();
  
  bool _isNetworkAvailable = false;
  bool _forceOffline = false;
  
  // Network connectivity protection
  Future<bool> _checkConnectivity() async {
    if (_forceOffline) return false;
    
    final results = await _connectivity.checkConnectivity();
    _isNetworkAvailable = results.isNotEmpty &&
        results.any((result) => result != ConnectivityResult.none);
    return _isNetworkAvailable;
  }
  
  // Protected Firebase operations
  Future<T> _executeFirebaseOperation<T>(Future<T> Function() operation) async {
    if (!(await _checkConnectivity())) {
      throw Exception('Firebase operation blocked: no network connectivity');
    }
    
    return await operation().timeout(Duration(seconds: 30));
  }
}
```

### Firestore Data Structure

```
users/
├── {userId}/
    ├── shipments/
    │   ├── {shipmentId}/
    │   │   ├── awb: string
    │   │   ├── shipper: string
    │   │   ├── consignee: string
    │   │   ├── dateOfIssue: timestamp
    │   │   ├── boxes: array
    │   │   │   ├── [0]/
    │   │   │   │   ├── id: string
    │   │   │   │   ├── boxNumber: number
    │   │   │   │   ├── dimensions: object
    │   │   │   │   └── products: array
    │   │   │   │       ├── [0]/
    │   │   │   │       │   ├── type: string
    │   │   │   │       │   ├── weight: number
    │   │   │   │       │   ├── rate: number
    │   │   │   │       │   └── flowerType: string
    │   │   │   │       └── ...
    │   │   │   └── ...
    │   │   └── metadata: object
    │   └── ...
    ├── masterData/
    │   ├── products/
    │   │   ├── {productId}/
    │   │   │   ├── type: string
    │   │   │   ├── rate: number
    │   │   │   └── description: string
    │   │   └── ...
    │   ├── clients/
    │   │   ├── {clientId}/
    │   │   │   ├── name: string
    │   │   │   ├── address: string
    │   │   │   └── contactInfo: object
    │   │   └── ...
    │   └── settings/
    │       └── userPreferences: object
    └── sync/
        ├── lastSyncTimestamp: timestamp
        ├── syncStatus: string
        └── conflictResolution: object
```

### Network Protection System

#### Multi-Layer Protection
```dart
// 1. Service Level Protection
class FirebaseService {
  bool _forceOffline = false;
  
  void enableForceOfflineMode() {
    _forceOffline = true;
  }
  
  void disableForceOfflineMode() {
    _forceOffline = false;
  }
}

// 2. DataService Level Protection
class DataService {
  Future<void> _handleFirebaseOperation(Future<void> Function() operation) async {
    try {
      if (await _connectivity.checkConnectivity()) {
        await operation();
      }
    } catch (e) {
      print('Firebase operation failed, continuing with local data: $e');
    }
  }
}
```

#### Connection Prevention Features
- **Connectivity Checking:** Every Firebase operation checks network first
- **Timeout Protection:** All operations have 30-second timeouts
- **Force Offline Mode:** Can disable all Firebase operations
- **Operation Wrapper:** `_executeFirebaseOperation()` wraps all Firebase calls
- **Graceful Fallback:** Automatic fallback to local storage when cloud fails

---

## 🔄 Data Synchronization System

### Auto-Sync System (Firestore → Local)

```dart
// Triggered automatically on login
Future<void> performAutoSyncOnLogin(String userId) async {
  try {
    print('🔄 Starting auto-sync for user: $userId');
    
    // 1. Sync shipments
    await _syncShipmentsFromFirebase(userId);
    
    // 2. Sync master data
    await _syncMasterDataFromFirebase(userId);
    
    // 3. Update last sync timestamp
    await _updateLastSyncTimestamp(userId);
    
    print('✅ Auto-sync completed successfully');
  } catch (e) {
    print('❌ Auto-sync failed: $e');
    // Continue with local data
  }
}
```

### Manual Sync Operations (Local → Firestore)

```dart
// User-triggered sync operations
Future<void> performManualSync(String userId, {
  bool syncShipments = true,
  bool syncMasterData = true,
  Function(String)? onProgress,
}) async {
  try {
    if (syncShipments) {
      onProgress?.call('Syncing shipments...');
      await _syncShipmentsToFirebase(userId);
    }
    
    if (syncMasterData) {
      onProgress?.call('Syncing master data...');
      await _syncMasterDataToFirebase(userId);
    }
    
    onProgress?.call('Sync completed successfully!');
  } catch (e) {
    onProgress?.call('Sync failed: $e');
    rethrow;
  }
}
```

### Bi-Directional Synchronization

```
┌─────────────────────────────────────────┐
│         SYNC OPERATIONS                 │
└─────────────────────────────────────────┘

AUTO-SYNC (Login Triggered)
Firebase → Local Database
├─ Download latest shipments
├─ Download master data updates
├─ Merge with local data (no duplicates)
└─ Update local timestamps

MANUAL-SYNC (User Triggered)
Local Database → Firebase
├─ Upload new/modified shipments
├─ Upload master data changes
├─ Handle conflict resolution
└─ Update cloud timestamps

FULL-SYNC (Comprehensive)
Bi-directional synchronization
├─ Compare timestamps
├─ Identify conflicts
├─ Resolve data discrepancies
└─ Ensure data consistency
```

### Conflict Resolution Strategy

```dart
Future<void> _resolveConflicts(
  Map<String, dynamic> localData,
  Map<String, dynamic> cloudData,
  String dataType,
) async {
  // Strategy: Most recent timestamp wins
  final localTimestamp = localData['lastModified'] as DateTime?;
  final cloudTimestamp = cloudData['lastModified'] as DateTime?;
  
  if (localTimestamp != null && cloudTimestamp != null) {
    if (localTimestamp.isAfter(cloudTimestamp)) {
      // Local is newer - upload to cloud
      await _uploadToFirebase(localData, dataType);
    } else {
      // Cloud is newer - update local
      await _updateLocalData(cloudData, dataType);
    }
  }
}
```

---

## 🔐 Authentication & User Management

### Authentication System
**File:** `lib/providers/auth_provider.dart`

```dart
class AuthProvider with ChangeNotifier {
  FirebaseAuth? _auth;
  User? _user;
  bool _isFirebaseAvailable = false;
  
  // Login with auto-sync
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    if (!_isFirebaseAvailable) {
      throw Exception('Authentication not available offline');
    }

    try {
      await _auth!.signInWithEmailAndPassword(email: email, password: password);
      // Auto-sync will be triggered in _onAuthStateChanged
    } on FirebaseAuthException catch (e) {
      throw Exception(_getErrorMessage(e));
    }
  }
  
  // Auto-sync trigger on authentication state change
  void _onAuthStateChanged(User? user) async {
    _user = user;
    
    if (user != null) {
      // Trigger auto-sync for authenticated user
      final dataService = DataService();
      await dataService.performAutoSyncOnLogin(user.uid);
    }
    
    notifyListeners();
  }
}
```

### Multi-User Data Isolation

```sql
-- SQLite schema with user isolation
CREATE TABLE shipments (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,          -- User isolation
  awb TEXT NOT NULL,
  shipper TEXT,
  consignee TEXT,
  date_of_issue INTEGER,
  created_at INTEGER DEFAULT (strftime('%s', 'now')),
  updated_at INTEGER DEFAULT (strftime('%s', 'now')),
  FOREIGN KEY (user_id) REFERENCES users (id)
);

-- All queries include user_id filter
SELECT * FROM shipments WHERE user_id = ? AND id = ?;
```

### User Session Management

```dart
// User session handling
class SessionManager {
  static String? _currentUserId;
  
  static String? get currentUserId => _currentUserId;
  
  static void setUser(String userId) {
    _currentUserId = userId;
  }
  
  static void clearUser() {
    _currentUserId = null;
  }
  
  static bool get isLoggedIn => _currentUserId != null;
}
```

---

## 📱 Offline Capabilities

### Offline-First Architecture

```
OFFLINE OPERATION MODES:

🔌 FULLY OFFLINE
├─ All operations use local SQLite
├─ No network connectivity attempts
├─ Complete functionality available
└─ Data saved for later sync

🌐 ONLINE WITH POOR CONNECTION
├─ Primary operations use local SQLite
├─ Background sync attempts (with timeouts)
├─ Graceful handling of connection failures
└─ Automatic retry mechanisms

☁️ FULLY ONLINE
├─ Dual storage operations (Local + Cloud)
├─ Real-time sync capabilities
├─ Cross-device data consistency
└─ Automatic conflict resolution
```

### Offline Data Management

```dart
class OfflineManager {
  // Queue operations for later sync
  static final List<Map<String, dynamic>> _pendingOperations = [];
  
  static void queueOperation(String operation, Map<String, dynamic> data) {
    _pendingOperations.add({
      'operation': operation,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  static Future<void> processPendingOperations() async {
    for (final operation in _pendingOperations) {
      try {
        await _executeOperation(operation);
        _pendingOperations.remove(operation);
      } catch (e) {
        print('Failed to process pending operation: $e');
      }
    }
  }
}
```

### Connection Recovery

```dart
// Network connectivity monitoring
class ConnectivityMonitor {
  static late StreamSubscription<List<ConnectivityResult>> _subscription;
  
  static void startMonitoring() {
    _subscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) async {
        if (results.any((result) => result != ConnectivityResult.none)) {
          // Connection restored - process pending operations
          await OfflineManager.processPendingOperations();
        }
      },
    );
  }
}
```

---

## 📚 API Reference

### DataService Methods

#### Shipment Operations
```dart
// Create shipment with dual storage
Future<void> saveShipment(Shipment shipment, String userId) async

// Create shipment with boxes and products
Future<void> createShipmentWithBoxes(
  Shipment shipment, 
  List<Map<String, dynamic>> boxesData
) async

// Retrieve shipments (local-first)
Future<List<Shipment>> getAllShipments(String userId) async

// Update shipment in both storages
Future<void> updateShipment(Shipment shipment, String userId) async

// Delete shipment from both storages
Future<void> deleteShipment(String shipmentId, String userId) async
```

#### Synchronization Operations
```dart
// Auto-sync on login (Firebase → Local)
Future<void> performAutoSyncOnLogin(String userId) async

// Manual sync (Local → Firebase)
Future<void> performManualSync(String userId) async

// Bi-directional sync
Future<void> performFullSync(String userId) async

// Sync specific data types
Future<void> syncShipments(String userId, {bool toFirebase = false}) async
Future<void> syncMasterData(String userId, {bool toFirebase = false}) async
```

#### Master Data Operations
```dart
// Save master data (products, clients, etc.)
Future<void> saveMasterData(String type, Map<String, dynamic> data, String userId) async

// Retrieve master data
Future<List<Map<String, dynamic>>> getMasterData(String type, String userId) async

// Update master data
Future<void> updateMasterData(String type, String id, Map<String, dynamic> data, String userId) async

// Delete master data
Future<void> deleteMasterData(String type, String id, String userId) async
```

### FirebaseService Methods

#### Core Operations
```dart
// Add data to Firestore
Future<void> addShipment(Shipment shipment, String userId) async
Future<void> addMasterData(String type, Map<String, dynamic> data, String userId) async

// Retrieve data from Firestore
Future<List<Map<String, dynamic>>> getShipments(String userId) async
Future<List<Map<String, dynamic>>> getMasterData(String type, String userId) async

// Update data in Firestore
Future<void> updateShipment(String shipmentId, Map<String, dynamic> updates, String userId) async

// Delete data from Firestore
Future<void> deleteShipment(String shipmentId, String userId) async
```

#### Network Protection
```dart
// Enable/disable offline mode
void enableForceOfflineMode()
void disableForceOfflineMode()

// Check connectivity
Future<bool> checkConnectivity() async

// Protected operation wrapper
Future<T> executeFirebaseOperation<T>(Future<T> Function() operation) async
```

### LocalDatabaseService Methods

#### Core CRUD Operations
```dart
// Shipment operations
Future<void> saveShipment(Shipment shipment, String userId) async
Future<List<Shipment>> getAllShipments(String userId) async
Future<Shipment?> getShipmentById(String id, String userId) async
Future<void> updateShipment(Shipment shipment, String userId) async
Future<void> deleteShipment(String shipmentId, String userId) async

// Box and product operations
Future<void> saveBox(String shipmentId, Map<String, dynamic> boxData) async
Future<void> saveProduct(String boxId, Map<String, dynamic> productData) async
Future<List<Map<String, dynamic>>> getBoxesForShipment(String shipmentId) async
Future<List<Map<String, dynamic>>> getProductsForBox(String boxId) async
```

---

## 🚀 Usage Examples

### Basic Shipment Creation
```dart
import 'package:invoice_caravel/services/data_service.dart';

// Create service instance
final dataService = DataService();

// Create shipment with dual storage
final shipment = Shipment(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  awb: 'AWB123456',
  shipper: 'Caravel Logistics',
  consignee: 'ABC Company',
  dateOfIssue: DateTime.now(),
);

// Save to both local and cloud storage
await dataService.saveShipment(shipment, userId);
```

### Shipment with Boxes and Products
```dart
// Prepare boxes data
final boxesData = [
  {
    'id': 'box1',
    'boxNumber': 1,
    'length': 50.0,
    'width': 40.0,
    'height': 30.0,
    'products': [
      {
        'id': 'prod1',
        'type': 'LOTUS',
        'weight': 52.0,
        'rate': 1.0,
        'flowerType': 'LOOSE FLOWERS',
        'hasStems': false,
        'approxQuantity': 100,
      },
    ],
  },
];

// Create shipment with boxes
await dataService.createShipmentWithBoxes(shipment, boxesData);
```

### Manual Synchronization
```dart
// Perform manual sync with progress tracking
await dataService.performManualSync(
  userId,
  onProgress: (status) {
    print('Sync progress: $status');
    // Update UI with progress
  },
);
```

### Offline Operation Handling
```dart
try {
  await dataService.saveShipment(shipment, userId);
  print('✅ Shipment saved successfully');
} catch (e) {
  if (e.toString().contains('network')) {
    print('💾 Saved locally, will sync when online');
  } else {
    print('❌ Save failed: $e');
  }
}
```

### Authentication with Auto-Sync
```dart
// Login with automatic sync
final authProvider = Provider.of<AuthProvider>(context, listen: false);

try {
  await authProvider.signInWithEmailAndPassword(email, password);
  
  // Auto-sync is triggered automatically
  // UI will be updated when sync completes
  
} catch (e) {
  print('Login failed: $e');
}
```

---

## 🔧 Troubleshooting

### Common Issues & Solutions

#### Sync Failures
**Issue:** Data not synchronizing between local and cloud  
**Solutions:**
```dart
// Check connectivity
final connectivity = await Connectivity().checkConnectivity();
if (connectivity == ConnectivityResult.none) {
  print('No internet connection - data saved locally');
}

// Force manual sync
await dataService.performFullSync(userId);

// Check Firebase service status
final firebaseService = FirebaseService();
if (await firebaseService.checkConnectivity()) {
  await firebaseService.testConnection();
}
```

#### Duplicate Data
**Issue:** Duplicate entries appearing after sync  
**Solutions:**
```dart
// Implement proper conflict resolution
Future<void> _handleDuplicates(String userId) async {
  final localShipments = await localDb.getAllShipments(userId);
  final cloudShipments = await firebaseService.getShipments(userId);
  
  // Remove duplicates based on ID and timestamp
  await _mergeDuplicates(localShipments, cloudShipments);
}
```

#### Authentication Errors
**Issue:** Firebase authentication failures  
**Solutions:**
```dart
// Check Firebase availability
if (!await FirebaseAuthService.isFirebaseAvailable()) {
  throw Exception('Firebase not available - check network connection');
}

// Handle specific auth errors
catch (FirebaseAuthException e) {
  switch (e.code) {
    case 'user-not-found':
      return 'No user found with this email address';
    case 'wrong-password':
      return 'Incorrect password';
    case 'network-request-failed':
      return 'Network error - check internet connection';
    default:
      return 'Authentication failed: ${e.message}';
  }
}
```

#### Database Migration Issues
**Issue:** Schema changes causing app crashes  
**Solutions:**
```dart
// Implement proper database migration
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    // Add new columns
    await db.execute('ALTER TABLE shipments ADD COLUMN new_field TEXT');
  }
  
  if (oldVersion < 3) {
    // Create new tables
    await db.execute('''
      CREATE TABLE boxes (
        id TEXT PRIMARY KEY,
        shipment_id TEXT,
        box_number INTEGER,
        FOREIGN KEY (shipment_id) REFERENCES shipments (id)
      )
    ''');
  }
}
```

#### Performance Issues
**Issue:** Slow database operations with large datasets  
**Solutions:**
```dart
// Implement pagination
Future<List<Shipment>> getShipmentsPaginated(
  String userId, 
  int limit, 
  int offset
) async {
  final query = '''
    SELECT * FROM shipments 
    WHERE user_id = ? 
    ORDER BY created_at DESC 
    LIMIT ? OFFSET ?
  ''';
  
  final results = await db.executeQuery(query, [userId, limit, offset]);
  return results.map((row) => Shipment.fromMap(row)).toList();
}

// Use indexes for better performance
await db.execute('CREATE INDEX idx_shipments_user_date ON shipments(user_id, date_of_issue)');
```

---

## ⚡ Performance & Security

### Performance Optimizations

#### Database Performance
```dart
// Connection pooling
class DatabaseConnectionPool {
  static final Map<String, Database> _connections = {};
  
  static Future<Database> getConnection(String userId) async {
    if (!_connections.containsKey(userId)) {
      _connections[userId] = await openDatabase('invoice_$userId.db');
    }
    return _connections[userId]!;
  }
}

// Batch operations
Future<void> saveBatchShipments(List<Shipment> shipments, String userId) async {
  final db = await database;
  final batch = db.batch();
  
  for (final shipment in shipments) {
    batch.insert('shipments', shipment.toMap());
  }
  
  await batch.commit();
}

// Background sync
Timer.periodic(Duration(minutes: 15), (timer) {
  if (await Connectivity().checkConnectivity() != ConnectivityResult.none) {
    _performBackgroundSync();
  }
});
```

#### Memory Management
```dart
// Stream-based data loading for large datasets
Stream<List<Shipment>> getShipmentsStream(String userId) async* {
  const int batchSize = 50;
  int offset = 0;
  
  while (true) {
    final batch = await getShipmentsPaginated(userId, batchSize, offset);
    if (batch.isEmpty) break;
    
    yield batch;
    offset += batchSize;
  }
}

// Memory cleanup
Future<void> cleanup() async {
  await _database?.close();
  _database = null;
}
```

### Security Measures

#### Data Encryption
```dart
// Local database encryption
Future<Database> openEncryptedDatabase(String path, String password) async {
  return await openDatabase(
    path,
    version: 1,
    onConfigure: (db) async {
      await db.execute('PRAGMA key = "$password"');
    },
  );
}

// Sensitive data handling
class SecureStorage {
  static const _storage = FlutterSecureStorage();
  
  static Future<void> storeEncryptedData(String key, String value) async {
    await _storage.write(key: key, value: value);
  }
  
  static Future<String?> getEncryptedData(String key) async {
    return await _storage.read(key: key);
  }
}
```

#### Firebase Security Rules
```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Prevent unauthorized access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

#### Data Validation
```dart
// Input validation
class DataValidator {
  static bool isValidShipment(Map<String, dynamic> data) {
    return data.containsKey('awb') &&
           data.containsKey('shipper') &&
           data.containsKey('consignee') &&
           data['awb'].toString().isNotEmpty;
  }
  
  static Map<String, dynamic> sanitizeInput(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value is String) {
        return MapEntry(key, value.trim().replaceAll(RegExp(r'[<>]'), ''));
      }
      return MapEntry(key, value);
    });
  }
}
```

---

## 📖 Best Practices

### Development Guidelines

#### Service Usage
```dart
// ✅ Good: Use DataService for coordinated operations
final dataService = DataService();
await dataService.saveShipment(shipment, userId);

// ❌ Bad: Direct database access bypassing coordination
final localDb = LocalDatabaseService();
await localDb.saveShipment(shipment, userId); // Missing cloud sync
```

#### Error Handling
```dart
// ✅ Good: Comprehensive error handling
try {
  await dataService.saveShipment(shipment, userId);
} on NetworkException catch (e) {
  // Handle network-specific errors
  await _handleNetworkError(e);
} on DatabaseException catch (e) {
  // Handle database-specific errors
  await _handleDatabaseError(e);
} catch (e) {
  // Handle unexpected errors
  await _handleGenericError(e);
}

// ❌ Bad: Generic error handling
try {
  await dataService.saveShipment(shipment, userId);
} catch (e) {
  print('Error: $e'); // Too generic
}
```

#### Resource Management
```dart
// ✅ Good: Proper resource cleanup
class DatabaseResource {
  Database? _db;
  
  Future<void> dispose() async {
    await _db?.close();
    _db = null;
  }
}

// ✅ Good: Use try-finally for cleanup
Database? connection;
try {
  connection = await openDatabase('path');
  // Use connection
} finally {
  await connection?.close();
}
```

### Data Management

#### Sync Strategy
```dart
// ✅ Good: Smart sync strategy
if (await _isLowBandwidth()) {
  // Sync only essential data
  await _syncCriticalData(userId);
} else {
  // Full sync when bandwidth allows
  await _performFullSync(userId);
}

// ✅ Good: Incremental sync
final lastSyncTime = await _getLastSyncTimestamp(userId);
await _syncDataSince(userId, lastSyncTime);
```

#### Data Modeling
```dart
// ✅ Good: Consistent data models
class Shipment {
  final String id;
  final String userId;  // Always include user context
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Include sync metadata
  final DateTime? lastSyncedAt;
  final bool isLocalOnly;
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'last_synced_at': lastSyncedAt?.millisecondsSinceEpoch,
      'is_local_only': isLocalOnly ? 1 : 0,
    };
  }
}
```

### Testing Strategies

#### Unit Testing
```dart
// Test database operations
group('LocalDatabaseService Tests', () {
  late LocalDatabaseService dbService;
  
  setUp(() {
    dbService = LocalDatabaseService();
  });
  
  test('should save and retrieve shipment', () async {
    final shipment = Shipment(id: 'test', /* ... */);
    
    await dbService.saveShipment(shipment, 'testUser');
    final retrieved = await dbService.getShipmentById('test', 'testUser');
    
    expect(retrieved?.id, equals('test'));
  });
});

// Test sync operations
group('DataService Sync Tests', () {
  test('should handle offline sync gracefully', () async {
    // Mock offline condition
    when(mockConnectivity.checkConnectivity())
        .thenAnswer((_) async => [ConnectivityResult.none]);
    
    await dataService.saveShipment(shipment, userId);
    
    // Verify local save occurred
    verify(mockLocalDb.saveShipment(shipment, userId)).called(1);
    // Verify Firebase was not called
    verifyNever(mockFirebaseService.addShipment(any, any));
  });
});
```

#### Integration Testing
```dart
// Test end-to-end workflows
testWidgets('should create and sync shipment', (WidgetTester tester) async {
  // Login
  await tester.pumpWidget(app);
  await tester.enterText(find.byKey(Key('email')), 'test@example.com');
  await tester.enterText(find.byKey(Key('password')), 'password');
  await tester.tap(find.byKey(Key('login')));
  await tester.pumpAndSettle();
  
  // Create shipment
  await tester.tap(find.byKey(Key('addShipment')));
  await tester.pumpAndSettle();
  
  // Fill form and save
  await tester.enterText(find.byKey(Key('awb')), 'AWB123');
  await tester.tap(find.byKey(Key('save')));
  await tester.pumpAndSettle();
  
  // Verify shipment was created and synced
  expect(find.text('Shipment created successfully'), findsOneWidget);
});
```

---

## 🔮 Future Enhancements

### Planned Features

#### Real-Time Sync
- [ ] WebSocket integration for real-time updates
- [ ] Live collaboration features
- [ ] Push notifications for data changes
- [ ] Conflict resolution UI

#### Advanced Caching
- [ ] Intelligent cache management
- [ ] Predictive data loading
- [ ] Background data prefetching
- [ ] Cache invalidation strategies

#### Enhanced Security
- [ ] End-to-end encryption
- [ ] Biometric authentication
- [ ] Data anonymization
- [ ] Audit logging

#### Performance Improvements
- [ ] Database sharding for large datasets
- [ ] Compression for sync operations
- [ ] CDN integration for asset delivery
- [ ] Query optimization and indexing

---

**Document Version:** 1.0  
**Last Updated:** December 9, 2025  
**Status:** ✅ Production Ready - Dual Storage Architecture Operational