# 🏗️ Service Architecture - Invoice Generator Mobile App

**Comprehensive documentation of the service layer architecture**

## 📋 Overview

The Invoice Generator implements a **Service-Oriented Architecture (SOA)** with clear separation of concerns between data access, business logic, and presentation layers. This document details the service layer that forms the backbone of the application.

## 🎯 Architecture Principles

### 1. Single Responsibility Principle
Each service has one clearly defined purpose:
- **DataService**: Coordinate data operations
- **ExcelFileService**: Generate Excel documents  
- **PDFService**: Generate PDF documents
- **FirebaseService**: Cloud data operations
- **LocalDatabaseService**: Local storage operations

### 2. Dependency Inversion
Services depend on abstractions, not concrete implementations:

```dart
abstract class DatabaseServiceInterface {
  Future<List<Shipment>> getShipments();
  Future<String> saveShipment(Shipment shipment);
}

class DataService {
  final DatabaseServiceInterface _localDatabase;
  final DatabaseServiceInterface _cloudDatabase;
  
  DataService(this._localDatabase, this._cloudDatabase);
}
```

### 3. Offline-First Design
All read operations prioritize local storage for instant response:

```dart
// Always read from local for immediate response
Future<List<ProductType>> getProductTypes() async {
  return await _localService.getProductTypes();
}
```

## 🔧 Service Layer Components

### DataService - Central Coordinator
**Purpose**: Unified interface for all data operations

```dart
class DataService {
  final FirebaseService _firebaseService;
  final LocalDatabaseService _localService;
  final Logger _logger;
  
  /// Offline-first read operations
  Future<List<Shipment>> getShipments() async {
    _logger.d('LOCAL_FIRST: Loading shipments');
    return await _localService.getShipments();
  }
  
  /// Dual-persistence write operations
  Future<String> saveShipment(Shipment shipment) async {
    // 1. Save to local (required)
    final id = await _localService.saveShipment(shipment);
    
    // 2. Save to cloud (best effort)
    _firebaseService.saveShipment(shipment).catchError((e) {
      _logger.w('Cloud save failed but continuing', e);
    });
    
    return id;
  }
  
  /// Background synchronization
  Future<void> syncFromFirebaseToLocal() async {
    final cloudData = await _firebaseService.getAllData();
    await _localService.bulkUpdate(cloudData);
  }
}
```

**Key Features**:
- **Read Operations**: Always use local database
- **Write Operations**: Dual persistence (local + cloud)
- **Sync Operations**: Background data synchronization
- **Error Isolation**: Cloud failures don't block local operations

### ExcelFileService - Professional Spreadsheet Generation
**Purpose**: Generate professional Excel invoices with advanced formatting

```dart
class ExcelFileService {
  /// Generate complete Excel invoice
  Future<Uint8List> generateInvoice(Shipment shipment) async {
    final excel = Excel.createExcel();
    final sheet = excel['Invoice'];
    
    // Professional invoice layout
    await _createInvoiceHeader(sheet, shipment);
    await _createShipperConsigneeSection(sheet, shipment);
    await _createProductTable(sheet, shipment);
    await _createChargesSection(sheet, shipment);
    await _createTotalsSection(sheet, shipment);
    
    return excel.encode()!;
  }
  
  /// Professional formatting
  void _applyProfessionalStyling(Workbook workbook) {
    // Header styling
    final headerStyle = CellStyle(
      fontFamily: getFontFamily(FontFamily.Calibri),
      fontSize: 14,
      bold: true,
      backgroundColorHex: ExcelColor.blue50,
    );
    
    // Border styling  
    final borderStyle = CellStyle(
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
    );
  }
}
```

**Features**:
- Professional invoice layout (7 sections)
- Advanced formatting and styling
- Automatic calculations and totals
- Multi-currency support
- Export optimization

### PDFService - Enhanced Multi-Page Document Generation
**Purpose**: Generate professional PDF invoices with intelligent pagination (Updated Dec 23, 2025)

```dart
class PdfService {
  // Performance optimization - load resources once
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;
  static pw.MemoryImage? _logoImage;
  
  // Enhanced layout constants (Updated Dec 23, 2025)
  static const double _itemRowHeight = 12.0;     // Optimized row height
  static const double _summaryHeight = 150.0;    // Fixed summary section
  static const int MAX_ITEMS_FIRST_PAGE = 30;    // Items on page 1 with summary
  static const int MAX_ITEMS_CONTINUATION_PAGE = 40; // Items per continuation page
  
  /// Generate PDF with automatic pagination
  Future<Uint8List> generateInvoice(Shipment shipment) async {
    await _loadResources();
    
    final pdf = pw.Document();
    final paginationPlan = _calculateOptimalPagination(items, masterProductTypes);
    final totalPages = paginationPlan['totalPages'] as int;
    
    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final layout = pageLayouts[pageIndex];
      pdf.addPage(_buildDynamicPage(shipment, items, masterProductTypes, 
                                   layout, pageIndex + 1, totalPages));
    }
    
    return await pdf.save();
  }
  
  /// Enhanced pagination calculation (Dec 23, 2025)
  Map<String, dynamic> _calculateOptimalPagination(List<dynamic> items) {
    // Calculate available space per page - A4 is ~842 points tall
    final double availablePerPage = PdfPageFormat.a4.height - 
        (_pageMargin * 2) - _headerHeight - _footerHeight; // ~652px
    
    // Page 1: Summary + up to 30 items
    final double firstPageSpace = availablePerPage - _summaryHeight - 
                                 _sectionSpacing - _tableHeaderHeight;
    int itemsOnFirstPage = math.min(
        (firstPageSpace / _itemRowHeight).floor(), 30);
    
    // Continuation pages: up to 40 items each
    // Dynamic layout generation for Table 1, Table 2, Table 3
    return _buildPageLayouts(items.length, itemsOnFirstPage);
  }
}
```

**Enhanced Features (Dec 23, 2025)**:
- **Increased capacity**: 30 items first page, 40 continuation pages
- **Cleaner design**: Removed continuation indicators  
- **Fixed calculations**: Corrected space constants for accuracy
- **Better debugging**: Enhanced console output for troubleshooting
- **Improved documentation**: Comprehensive inline comments

### FirebaseService - Cloud Integration
**Purpose**: Manage all Firebase Firestore operations

```dart
class FirebaseService {
  final FirebaseFirestore _firestore;
  final String _userId;
  
  /// User-isolated data access
  CollectionReference get _userShipments =>
      _firestore.collection('users').doc(_userId).collection('shipments');
  
  /// Save shipment to cloud
  Future<String> saveShipment(Shipment shipment) async {
    final docRef = await _userShipments.add(shipment.toMap());
    
    // Save related data
    await _saveBoxes(docRef.id, shipment.boxes);
    await _saveProducts(docRef.id, shipment.boxes);
    
    return docRef.id;
  }
  
  /// Batch operations for performance
  Future<void> _saveBoxes(String shipmentId, List<Box> boxes) async {
    final batch = _firestore.batch();
    
    for (final box in boxes) {
      final boxRef = _userShipments
          .doc(shipmentId)
          .collection('boxes')
          .doc(box.id);
      
      batch.set(boxRef, box.toMap());
    }
    
    await batch.commit();
  }
  
  /// Error handling and retry logic
  Future<List<Shipment>> getShipments() async {
    try {
      final snapshot = await _userShipments
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => Shipment.fromFirestore(doc))
          .toList();
          
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        throw NetworkException('Firebase service unavailable');
      }
      throw CloudException('Firebase error: ${e.message}');
    }
  }
}
```

**Features**:
- User data isolation
- Batch operations for performance  
- Comprehensive error handling
- Retry logic for network issues
- Structured data organization

### LocalDatabaseService - Offline Storage
**Purpose**: SQLite database operations for offline functionality

```dart
class LocalDatabaseService {
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  /// Database initialization with schema
  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'invoice_generator.db');
    
    return await openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }
  
  /// Create tables with proper relationships
  Future<void> _onCreate(Database db, int version) async {
    // Shipments table
    await db.execute('''
      CREATE TABLE shipments (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        invoice_number TEXT NOT NULL,
        invoice_title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        synced_at TEXT,
        data TEXT NOT NULL
      )
    ''');
    
    // Boxes table with foreign key
    await db.execute('''
      CREATE TABLE boxes (
        id TEXT PRIMARY KEY,
        shipment_id TEXT NOT NULL,
        box_number TEXT NOT NULL,
        dimensions TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (shipment_id) REFERENCES shipments (id)
      )
    ''');
    
    // Products table with foreign key
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        box_id TEXT NOT NULL,
        product_type TEXT NOT NULL,
        weight REAL NOT NULL,
        rate REAL NOT NULL,
        amount REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (box_id) REFERENCES boxes (id)
      )
    ''');
    
    // Indexes for performance
    await db.execute('CREATE INDEX idx_shipments_user ON shipments(user_id)');
    await db.execute('CREATE INDEX idx_boxes_shipment ON boxes(shipment_id)');
    await db.execute('CREATE INDEX idx_products_box ON products(box_id)');
  }
  
  /// Transaction-based operations
  Future<String> saveShipment(Shipment shipment) async {
    final db = await database;
    
    return await db.transaction((txn) async {
      // Save shipment
      await txn.insert('shipments', shipment.toMap());
      
      // Save boxes and products
      for (final box in shipment.boxes) {
        await txn.insert('boxes', box.toMap());
        
        for (final product in box.products) {
          await txn.insert('products', product.toMap());
        }
      }
      
      return shipment.id;
    });
  }
  
  /// Optimized queries with joins
  Future<List<Shipment>> getShipmentsWithDetails() async {
    final db = await database;
    
    final result = await db.rawQuery('''
      SELECT s.*, 
             GROUP_CONCAT(b.id) as box_ids,
             COUNT(p.id) as total_products,
             SUM(p.amount) as total_amount
      FROM shipments s
      LEFT JOIN boxes b ON s.id = b.shipment_id
      LEFT JOIN products p ON b.id = p.box_id
      WHERE s.user_id = ?
      GROUP BY s.id
      ORDER BY s.created_at DESC
    ''', [_currentUserId]);
    
    return result.map((row) => Shipment.fromMap(row)).toList();
  }
}
```

**Features**:
- Relational database design
- Transaction support
- Performance optimization with indexes
- Data integrity with foreign keys
- Efficient queries with joins

## 🔄 Service Integration Patterns

### Dependency Injection
```dart
// Service registration
class ServiceLocator {
  static final GetIt _locator = GetIt.instance;
  
  static void setupServices() {
    // Register singletons
    _locator.registerLazySingleton<FirebaseService>(
      () => FirebaseService(FirebaseFirestore.instance),
    );
    
    _locator.registerLazySingleton<LocalDatabaseService>(
      () => LocalDatabaseService(),
    );
    
    _locator.registerLazySingleton<DataService>(
      () => DataService(
        _locator<FirebaseService>(),
        _locator<LocalDatabaseService>(),
        Logger(),
      ),
    );
  }
  
  static T get<T extends Object>() => _locator<T>();
}

// Service usage in widgets
class InvoiceListScreen extends StatefulWidget {
  @override
  _InvoiceListScreenState createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  final DataService _dataService = ServiceLocator.get<DataService>();
  
  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }
  
  Future<void> _loadInvoices() async {
    final shipments = await _dataService.getShipments();
    setState(() {
      _shipments = shipments;
    });
  }
}
```

### Error Handling Chain
```dart
abstract class AppException implements Exception {
  final String message;
  final String code;
  
  AppException(this.message, this.code);
}

class NetworkException extends AppException {
  NetworkException(String message) : super(message, 'NETWORK_ERROR');
}

class DataException extends AppException {
  DataException(String message) : super(message, 'DATA_ERROR');
}

// Service layer error handling
class DataService {
  Future<List<Shipment>> getShipments() async {
    try {
      return await _localService.getShipments();
    } on DatabaseException catch (e) {
      _logger.e('Local database error', e);
      throw DataException('Failed to load invoices from local storage');
    } catch (e) {
      _logger.e('Unexpected error', e);
      throw AppException('Unexpected error occurred', 'UNKNOWN_ERROR');
    }
  }
}

// UI layer error handling
class InvoiceProvider extends ChangeNotifier {
  String? _errorMessage;
  
  String? get errorMessage => _errorMessage;
  
  Future<void> loadShipments() async {
    try {
      _errorMessage = null;
      _shipments = await _dataService.getShipments();
    } on AppException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred';
    } finally {
      notifyListeners();
    }
  }
}
```

### Background Services
```dart
class SyncService {
  static const Duration _syncInterval = Duration(minutes: 15);
  Timer? _syncTimer;
  
  void startBackgroundSync() {
    _syncTimer = Timer.periodic(_syncInterval, (_) async {
      await _performBackgroundSync();
    });
  }
  
  Future<void> _performBackgroundSync() async {
    try {
      if (await _isOnline() && await _isAuthenticated()) {
        await _dataService.syncFromFirebaseToLocal();
        _logger.i('Background sync completed');
      }
    } catch (e) {
      _logger.w('Background sync failed', e);
      // Continue silently - don't disturb user experience
    }
  }
  
  void stopBackgroundSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }
}
```

## 📊 Performance Considerations

### Caching Strategy
```dart
class CacheService {
  final Map<String, dynamic> _cache = {};
  final Duration _cacheTimeout = Duration(minutes: 10);
  final Map<String, DateTime> _cacheTimestamps = {};
  
  T? get<T>(String key) {
    if (!_isValid(key)) return null;
    return _cache[key] as T?;
  }
  
  void set<T>(String key, T value) {
    _cache[key] = value;
    _cacheTimestamps[key] = DateTime.now();
  }
  
  bool _isValid(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;
    
    return DateTime.now().difference(timestamp) < _cacheTimeout;
  }
  
  void clear() {
    _cache.clear();
    _cacheTimestamps.clear();
  }
}
```

### Connection Pooling
```dart
class DatabasePool {
  static const int _maxConnections = 5;
  final Queue<Database> _availableConnections = Queue();
  final Set<Database> _activeConnections = {};
  
  Future<Database> getConnection() async {
    if (_availableConnections.isNotEmpty) {
      final db = _availableConnections.removeFirst();
      _activeConnections.add(db);
      return db;
    }
    
    if (_activeConnections.length < _maxConnections) {
      final db = await _createConnection();
      _activeConnections.add(db);
      return db;
    }
    
    // Wait for available connection
    return await _waitForConnection();
  }
  
  void releaseConnection(Database db) {
    _activeConnections.remove(db);
    _availableConnections.add(db);
  }
}
```

### Batch Operations
```dart
class BatchProcessor {
  final Queue<Operation> _pendingOperations = Queue();
  Timer? _batchTimer;
  
  void addOperation(Operation operation) {
    _pendingOperations.add(operation);
    _scheduleBatch();
  }
  
  void _scheduleBatch() {
    _batchTimer?.cancel();
    _batchTimer = Timer(Duration(milliseconds: 100), _processBatch);
  }
  
  Future<void> _processBatch() async {
    if (_pendingOperations.isEmpty) return;
    
    final batch = <Operation>[];
    while (_pendingOperations.isNotEmpty && batch.length < 50) {
      batch.add(_pendingOperations.removeFirst());
    }
    
    await _executeBatch(batch);
    
    // Schedule next batch if more operations pending
    if (_pendingOperations.isNotEmpty) {
      _scheduleBatch();
    }
  }
}
```

## 🔍 Monitoring and Logging

### Service Monitoring
```dart
class ServiceMonitor {
  final Map<String, ServiceMetrics> _metrics = {};
  
  void recordOperation(String serviceName, String operation, Duration duration) {
    final metrics = _metrics.putIfAbsent(
      serviceName, 
      () => ServiceMetrics(),
    );
    
    metrics.recordOperation(operation, duration);
    
    // Alert on performance issues
    if (duration.inMilliseconds > 5000) {
      _logger.w('Slow operation detected: $serviceName.$operation (${duration.inMilliseconds}ms)');
    }
  }
  
  Map<String, dynamic> getMetrics() {
    return _metrics.map(
      (service, metrics) => MapEntry(service, metrics.toMap()),
    );
  }
}

class ServiceMetrics {
  final Map<String, List<Duration>> _operationTimes = {};
  
  void recordOperation(String operation, Duration duration) {
    _operationTimes.putIfAbsent(operation, () => []).add(duration);
    
    // Keep only last 100 measurements
    final times = _operationTimes[operation]!;
    if (times.length > 100) {
      times.removeAt(0);
    }
  }
  
  Map<String, dynamic> toMap() {
    return _operationTimes.map((operation, times) {
      final avgTime = times.fold<int>(
        0, (sum, time) => sum + time.inMilliseconds,
      ) / times.length;
      
      return MapEntry(operation, {
        'average_time_ms': avgTime.round(),
        'total_calls': times.length,
        'last_call': times.last.inMilliseconds,
      });
    });
  }
}
```

---

**🏗️ Architecture Status**: Production Ready  
**📊 Performance**: Optimized for mobile constraints  
**🔧 Maintainability**: Clean separation of concerns  
**📱 Platforms**: Android & iOS  
**📅 Last Updated**: December 2025