# 👩‍💻 Developer Guide - Invoice Generator Mobile App

**Complete development guide for contributing to the Invoice Generator project**

## 🎯 Overview

This guide covers everything developers need to know to work on the Invoice Generator codebase, from environment setup to deployment guidelines.

## 🛠️ Development Environment Setup

### Prerequisites
- **Flutter SDK 3.0+** with stable channel
- **Dart SDK** (included with Flutter)
- **Android Studio** or **VS Code** with Flutter extensions
- **Git** for version control
- **Firebase CLI** for backend management

### IDE Configuration

#### VS Code Extensions
```json
{
  "recommendations": [
    "dart-code.dart-code",
    "dart-code.flutter",
    "ms-vscode.vscode-json",
    "bradlc.vscode-tailwindcss",
    "gruntfuggly.todo-tree"
  ]
}
```

#### Android Studio Plugins
- Flutter plugin
- Dart plugin
- Firebase plugin
- GitToolBox

### Project Setup
```bash
# Clone repository
git clone https://github.com/thavahan/invoice_caravel.git
cd invoice_caravel

# Install dependencies
flutter pub get

# Verify setup
flutter doctor
flutter analyze
```

## 🏗️ Project Architecture

### Directory Structure
```
lib/
├── main.dart                 # Application entry point
├── firebase_options.dart     # Firebase configuration
├── models/                   # Data models and entities
│   ├── shipment.dart        # Core shipment model
│   ├── product.dart         # Product model
│   ├── box.dart            # Box model
│   └── master_data.dart    # Master data models
├── providers/               # State management
│   ├── invoice_provider.dart
│   ├── auth_provider.dart
│   └── master_data_provider.dart
├── screens/                 # UI screens and pages
│   ├── auth/               # Authentication screens
│   ├── invoice/            # Invoice management
│   ├── master_data/        # Master data management
│   └── settings/           # App settings
├── services/               # Business logic layer
│   ├── data_service.dart   # Unified data coordination
│   ├── excel_file_service.dart # Excel generation
│   ├── pdf_service.dart    # PDF generation
│   ├── firebase_service.dart # Firebase integration
│   └── local_database_service.dart # Local storage
└── widgets/                # Reusable UI components
    ├── common/            # Generic widgets
    ├── invoice/           # Invoice-specific widgets
    └── forms/             # Form components
```

### Architectural Patterns

#### 1. Service Layer Pattern
**Purpose**: Separate business logic from UI and data access

```dart
// Service interface
abstract class DataServiceInterface {
  Future<List<Shipment>> getShipments();
  Future<String> saveShipment(Shipment shipment);
  Future<void> deleteShipment(String id);
}

// Implementation with offline-first pattern
class DataService implements DataServiceInterface {
  final FirebaseService _firebaseService;
  final LocalDatabaseService _localService;
  
  // Always read from local for instant response
  Future<List<Shipment>> getShipments() async {
    return await _localService.getShipments();
  }
  
  // Write to both local and cloud
  Future<String> saveShipment(Shipment shipment) async {
    final id = await _localService.saveShipment(shipment);
    _firebaseService.saveShipment(shipment); // Best effort
    return id;
  }
}
```

#### 2. Provider Pattern (State Management)
**Purpose**: Reactive state management with clean separation

```dart
class InvoiceProvider extends ChangeNotifier {
  final DataService _dataService;
  List<Shipment> _shipments = [];
  bool _isLoading = false;
  
  List<Shipment> get shipments => _shipments;
  bool get isLoading => _isLoading;
  
  Future<void> loadShipments() async {
    _isLoading = true;
    notifyListeners();
    
    _shipments = await _dataService.getShipments();
    
    _isLoading = false;
    notifyListeners();
  }
  
  Future<void> addShipment(Shipment shipment) async {
    await _dataService.saveShipment(shipment);
    await loadShipments(); // Refresh list
  }
}
```

#### 3. Repository Pattern
**Purpose**: Abstract data source details

```dart
abstract class ShipmentRepository {
  Future<List<Shipment>> getShipments();
  Future<String> saveShipment(Shipment shipment);
}

class FirebaseShipmentRepository implements ShipmentRepository {
  // Firebase implementation
}

class LocalShipmentRepository implements ShipmentRepository {
  // SQLite implementation
}
```

### Key Design Decisions

#### Offline-First Architecture
**Principle**: All read operations use local database for instant response

```dart
// GOOD: Instant response from local storage
Future<List<ProductType>> getProductTypes() async {
  return await _localService.getProductTypes();
}

// AVOID: Network-dependent reads
Future<List<ProductType>> getProductTypes() async {
  if (await isOnline()) {
    return await _firebaseService.getProductTypes();
  } else {
    return await _localService.getProductTypes();
  }
}
```

#### Dual-Persistence Strategy
**Principle**: Write operations save to both local and cloud storage

```dart
Future<String> saveProductType(ProductType productType) async {
  // 1. Save to local first (required for success)
  final id = await _localService.saveProductType(productType);
  
  // 2. Save to Firebase (best effort, non-blocking)
  _firebaseService.saveProductType(productType).catchError((error) {
    _logger.w('Firebase save failed but continuing', error);
  });
  
  return id;
}
```

## 💻 Development Workflow

### Git Workflow
```bash
# Feature development
git checkout main
git pull origin main
git checkout -b feature/new-feature-name

# Development
# ... make changes ...
git add .
git commit -m "feat: add new feature description"

# Push and create PR
git push origin feature/new-feature-name
# Create pull request on GitHub
```

### Commit Message Format
```
type(scope): description

feat(invoice): add multi-page PDF generation
fix(sync): resolve duplicate data issue  
docs(api): update service documentation
refactor(ui): improve invoice list performance
test(unit): add shipment model tests
```

### Code Style Guidelines

#### Dart/Flutter Conventions
```dart
// Class naming: PascalCase
class InvoiceService {
  
  // Method naming: camelCase
  Future<String> generateInvoice() async { }
  
  // Private members: underscore prefix
  final DatabaseService _databaseService;
  
  // Constants: SCREAMING_SNAKE_CASE
  static const int MAX_ITEMS_PER_PAGE = 50;
}
```

#### Documentation Standards
```dart
/// Service for generating professional Excel invoices
/// 
/// This service handles the complete Excel generation workflow including:
/// - Professional formatting and styling
/// - Multi-section invoice layout  
/// - Automatic calculations and totals
/// 
/// Example usage:
/// ```dart
/// final service = ExcelFileService();
/// final file = await service.generateInvoice(shipment);
/// ```
class ExcelFileService {
  
  /// Generates a professional Excel invoice for the given shipment
  ///
  /// [shipment] - The shipment data to include in the invoice
  /// [options] - Optional formatting and export options
  /// 
  /// Returns the generated Excel file as bytes
  /// 
  /// Throws [InvoiceGenerationException] if generation fails
  Future<Uint8List> generateInvoice(
    Shipment shipment, {
    ExcelOptions? options,
  }) async {
    // Implementation
  }
}
```

### Testing Strategy

#### Unit Tests
```dart
// test/services/data_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

void main() {
  group('DataService', () {
    late DataService dataService;
    late MockFirebaseService mockFirebase;
    late MockLocalService mockLocal;
    
    setUp(() {
      mockFirebase = MockFirebaseService();
      mockLocal = MockLocalService();
      dataService = DataService(mockFirebase, mockLocal);
    });
    
    test('should save shipment to local and firebase', () async {
      // Arrange
      final shipment = Shipment(id: '1', title: 'Test');
      when(mockLocal.saveShipment(any)).thenAnswer((_) async => '1');
      
      // Act
      final result = await dataService.saveShipment(shipment);
      
      // Assert
      expect(result, '1');
      verify(mockLocal.saveShipment(shipment)).called(1);
      verify(mockFirebase.saveShipment(shipment)).called(1);
    });
  });
}
```

#### Widget Tests
```dart
// test/widgets/invoice_form_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('InvoiceForm should validate required fields', (tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InvoiceForm(),
        ),
      ),
    );
    
    // Act
    await tester.tap(find.text('Save'));
    await tester.pump();
    
    // Assert
    expect(find.text('Invoice title is required'), findsOneWidget);
  });
}
```

#### Integration Tests
```dart
// integration_test/app_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  group('Invoice Creation Flow', () {
    testWidgets('should create and export invoice', (tester) async {
      // Test complete user workflow
      await tester.pumpWidget(MyApp());
      
      // Navigate to create invoice
      await tester.tap(find.text('Create Invoice'));
      await tester.pumpAndSettle();
      
      // Fill in form
      await tester.enterText(find.byKey(Key('invoice_title')), 'Test Invoice');
      
      // Save invoice
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      
      // Verify creation
      expect(find.text('Test Invoice'), findsOneWidget);
    });
  });
}
```

## 🔧 Key Services Implementation

### DataService - Unified Data Coordination
**Purpose**: Central coordinator for all data operations

```dart
class DataService {
  final FirebaseService _firebaseService;
  final LocalDatabaseService _localService;
  final Logger _logger;
  
  DataService(this._firebaseService, this._localService, this._logger);
  
  /// Read operations - Always local for instant response
  Future<List<Shipment>> getShipments() async {
    _logger.d('LOCAL_FIRST: Loading shipments from local database');
    final result = await _localService.getShipments();
    _logger.d('LOCAL_FIRST: Loaded ${result.length} shipments');
    return result;
  }
  
  /// Write operations - Dual persistence
  Future<String> saveShipment(Shipment shipment) async {
    // 1. Save locally (required)
    final id = await _localService.saveShipment(shipment);
    
    // 2. Save to Firebase (best effort)
    _firebaseService.saveShipment(shipment).catchError((error) {
      _logger.w('Firebase save failed', error);
    });
    
    return id;
  }
  
  /// Sync operations - Background data synchronization
  Future<void> syncFromFirebaseToLocal() async {
    try {
      final firebaseData = await _firebaseService.getAllData();
      await _localService.bulkSync(firebaseData);
      _logger.i('Sync completed successfully');
    } catch (error) {
      _logger.e('Sync failed', error);
      rethrow;
    }
  }
}
```

### Error Handling Patterns
```dart
// Custom exception hierarchy
abstract class AppException implements Exception {
  final String message;
  final String? code;
  
  AppException(this.message, {this.code});
}

class NetworkException extends AppException {
  NetworkException(String message) : super(message, code: 'NETWORK_ERROR');
}

class ValidationException extends AppException {
  final Map<String, String> fieldErrors;
  
  ValidationException(String message, this.fieldErrors) 
    : super(message, code: 'VALIDATION_ERROR');
}

// Service error handling
Future<List<Shipment>> getShipments() async {
  try {
    return await _localService.getShipments();
  } on DatabaseException catch (e) {
    _logger.e('Database error loading shipments', e);
    throw DataException('Failed to load shipments: ${e.message}');
  } catch (e) {
    _logger.e('Unexpected error loading shipments', e);
    throw AppException('Unexpected error occurred');
  }
}
```

### Performance Optimization Patterns

#### Lazy Loading
```dart
class MasterDataProvider extends ChangeNotifier {
  List<ProductType>? _productTypes;
  
  Future<List<ProductType>> get productTypes async {
    if (_productTypes == null) {
      _productTypes = await _dataService.getProductTypes();
    }
    return _productTypes!;
  }
}
```

#### Pagination
```dart
class InvoiceListProvider extends ChangeNotifier {
  final List<Shipment> _shipments = [];
  int _currentPage = 0;
  static const int _pageSize = 20;
  
  Future<void> loadMore() async {
    final newShipments = await _dataService.getShipments(
      offset: _currentPage * _pageSize,
      limit: _pageSize,
    );
    
    _shipments.addAll(newShipments);
    _currentPage++;
    notifyListeners();
  }
}
```

#### Memory Management
```dart
class InvoiceFormScreen extends StatefulWidget {
  @override
  _InvoiceFormScreenState createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final List<TextEditingController> _controllers = [];
  
  @override
  void dispose() {
    // Clean up controllers to prevent memory leaks
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
```

## 🚀 Build and Deployment

### Build Variants
```bash
# Debug build
flutter build apk --debug

# Release build  
flutter build apk --release

# iOS build
flutter build ios --release

# Web build
flutter build web
```

### Environment Configuration
```dart
// lib/config/environment.dart
enum Environment {
  development,
  staging, 
  production,
}

class Config {
  static Environment get environment {
    const env = String.fromEnvironment('ENV', defaultValue: 'development');
    switch (env) {
      case 'production':
        return Environment.production;
      case 'staging':
        return Environment.staging;
      default:
        return Environment.development;
    }
  }
  
  static String get firebaseProjectId {
    switch (environment) {
      case Environment.production:
        return 'invoice-generator-prod';
      case Environment.staging:
        return 'invoice-generator-staging';
      default:
        return 'invoice-generator-dev';
    }
  }
}
```

### CI/CD Pipeline
```yaml
# .github/workflows/flutter.yml
name: Flutter CI/CD

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.0.0'
    - run: flutter pub get
    - run: flutter analyze
    - run: flutter test
    - run: flutter build apk --debug
```

## 🐛 Debugging Guidelines

### Logging Strategy
```dart
// Use different log levels appropriately
_logger.d('Debug info for development');    // Debug
_logger.i('General information');           // Info  
_logger.w('Warning about potential issue'); // Warning
_logger.e('Error that needs attention');    // Error

// Include context in error logs
_logger.e('Failed to save shipment', {
  'shipment_id': shipment.id,
  'error': error.toString(),
  'stack_trace': stackTrace.toString(),
});
```

### Performance Monitoring
```dart
// Use Stopwatch for performance measurement
Future<List<Shipment>> getShipments() async {
  final stopwatch = Stopwatch()..start();
  
  try {
    final result = await _localService.getShipments();
    _logger.d('getShipments completed in ${stopwatch.elapsedMilliseconds}ms');
    return result;
  } finally {
    stopwatch.stop();
  }
}
```

### Flutter Inspector
```bash
# Enable performance overlay
flutter run --dart-define=PERFORMANCE_OVERLAY=true

# Enable debug painting
flutter run --dart-define=DEBUG_PAINTING=true
```

## 📚 Additional Resources

### Documentation Standards
- **README**: Clear project overview and setup
- **API Docs**: Service interfaces and examples
- **Architecture**: System design and patterns
- **Troubleshooting**: Common issues and solutions

### Code Review Checklist
- [ ] Code follows style guidelines
- [ ] Tests are included and passing
- [ ] Documentation is updated
- [ ] Performance impact considered
- [ ] Error handling implemented
- [ ] Security implications reviewed

### Development Tools
- **Flutter DevTools**: Performance and debugging
- **Firebase Console**: Backend management
- **VS Code Extensions**: Enhanced development experience
- **Git Hooks**: Automated quality checks

---

**📱 Target Platforms**: Android, iOS  
**🏗️ Architecture**: Clean Architecture with Service Layer  
**📊 State Management**: Provider Pattern  
**💾 Storage**: SQLite + Firebase Firestore  
**📅 Last Updated**: December 2025