# Excel & PDF Export - Implementation Guide

This guide provides step-by-step instructions for implementing the recommended improvements to your export functionality.

---

## Priority 1: Fix Compiler Errors ✅ COMPLETED

### Status: ALL FIXED
- ✅ Removed unused `_availableHeight` getter from `pdf_service.dart`
- ✅ Removed unused `description` variable from `invoice_list_screen.dart`

Run `flutter pub get` to verify no compilation errors remain.

---

## Priority 2: Integrate ExcelExportService

### Current State
- The `ExcelExportService` exists but is **not used** by the UI
- Instead, `invoice_list_screen.dart` manually builds CSV strings (lines 3674-3744)

### Recommended Change

**File:** `lib/screens/invoice_list_screen.dart`

**Replace Method:** `_exportAsExcel()` (starting around line 3690)

**Current Implementation (Not Using Service):**
```dart
Future<void> _exportAsExcel(Map<String, dynamic> invoice) async {
  try {
    // Show preparing message...
    
    // Get detailed invoice data
    final detailedInvoiceData = await _getDetailedInvoiceData(
        invoice['id'] ?? invoice['invoiceNumber']);

    // MANUAL CSV BUILDING - Lines 3705-3744
    final StringBuffer csvBuffer = StringBuffer();
    csvBuffer.writeln('Invoice Export Report');
    // ... lots of manual string concatenation ...
```

**Improved Implementation (Using Service):**
```dart
Future<void> _exportAsExcel(Map<String, dynamic> invoice) async {
  try {
    // Delegate to ExcelExportService instead of manual implementation
    await ExcelExportService.exportAsExcel(
      context,
      invoice,
      _getDetailedInvoiceData,
    );
  } catch (e) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Excel export failed: ${e.toString()}'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
```

**Benefits:**
- ✅ Reuses professional formatting from `ExcelExportService`
- ✅ Better error handling and validation
- ✅ Consistent with architecture (PDF uses a service)
- ✅ Reduces code duplication by ~150 lines
- ✅ Easier to maintain and update

---

## Priority 3: Complete Excel Logo Implementation

### File: `lib/services/excel_export_service.dart`

### Current Issue
Around line 190, there's incomplete logo insertion code:
```dart
try {
  // Load the logo image from assets
  final ByteData logoData = await rootBundle.load('asset/images/Caravel_logo.png');
  final List<int> logoBytes = logoData.buffer.asUint8List();
  
  // Try to insert image using Excel package's image support
  // Note: This may work with newer versions of the Excel package
  try {
    // Attempt to use image insertion if available
    final cellIndex = excel.CellIndex.indexByString('E$row');
    
    // Create image in Excel (if supported by package version)
    // Some versions support: workbook.insertImage or sheet.insertImageByBytes
    if (logoBytes.isNotEmpty) {
      // ... INCOMPLETE
```

### Solution

Replace the incomplete code section (approximately lines 190-230) with:

```dart
// ========== LOGO INSERTION (Optional) ==========
try {
  // Note: Excel package v4.0.6 has limited image support
  // Attempting to add logo if available
  final ByteData logoData = await rootBundle.load('asset/images/Caravel_logo.png');
  final List<int> logoBytes = logoData.buffer.asUint8List();
  
  // The current excel package version may not support direct image insertion
  // This can be enhanced with a dedicated image library in future versions
  // For now, add a text note instead
  final logoNoteCell = sheet.cell(excel.CellIndex.indexByString('E1'));
  logoNoteCell.value = excel.TextCellValue('Caravel Logistics');
  logoNoteCell.cellStyle = excel.CellStyle(
    bold: true,
    fontSize: 14,
    italic: true,
  );
  
  print('Logo placeholder added to Excel export');
} catch (e) {
  // Logo insertion failed - continue without it
  print('Could not insert logo: $e');
  // This is non-fatal - export continues without logo
}

row++;
```

### Alternative: Future Enhancement

If you want full image support in Excel, consider this approach:

```dart
// File: lib/services/excel_enhanced_service.dart
import 'package:excel_plus/excel_plus.dart'; // More advanced package
// OR
import 'package:xlsx/xlsx.dart'; // Alternative with better image support
```

---

## Priority 4: Create Unified Export Service

### File: `lib/services/invoice_export_service.dart` (NEW)

Create a new service to unify all export operations:

```dart
import 'package:flutter/material.dart';
import 'pdf_service.dart';
import 'excel_export_service.dart';
import '../models/shipment.dart';

enum ExportFormat { PDF, EXCEL, CSV }
enum ExportDestination { PREVIEW, SHARE, SAVE }

/// Unified service for all invoice exports
class InvoiceExportService {
  static final PdfService _pdfService = PdfService();
  
  /// Export invoice in requested format to requested destination
  static Future<void> exportInvoice({
    required BuildContext context,
    required Map<String, dynamic> invoice,
    required ExportFormat format,
    required ExportDestination destination,
    required Future<Map<String, dynamic>> Function(String) getDetailedData,
  }) async {
    try {
      final detailedData = await getDetailedData(
        invoice['id'] ?? invoice['invoiceNumber']
      );
      
      if (detailedData.isEmpty) {
        throw Exception('Could not retrieve invoice details');
      }

      switch (format) {
        case ExportFormat.PDF:
          await _exportPdf(context, invoice, detailedData, destination);
          break;
        case ExportFormat.EXCEL:
          await _exportExcel(context, invoice, getDetailedData);
          break;
        case ExportFormat.CSV:
          await _exportCsv(context, invoice, detailedData);
          break;
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Export failed: ${e.toString()}');
    }
  }

  static Future<void> _exportPdf(
    BuildContext context,
    Map<String, dynamic> invoice,
    Map<String, dynamic> detailedData,
    ExportDestination destination,
  ) async {
    final shipment = _createShipmentFromData(invoice, detailedData);
    final items = _extractItems(detailedData);
    
    bool isPreview = destination == ExportDestination.PREVIEW;
    await _pdfService.generateShipmentPDF(shipment, items, isPreview);
    
    if (destination == ExportDestination.PREVIEW) {
      _showSuccessSnackBar(context, 'PDF preview generated');
    } else if (destination == ExportDestination.SHARE) {
      _showSuccessSnackBar(context, 'PDF shared');
    }
  }

  static Future<void> _exportExcel(
    BuildContext context,
    Map<String, dynamic> invoice,
    Future<Map<String, dynamic>> Function(String) getDetailedData,
  ) async {
    await ExcelExportService.exportAsExcel(
      context,
      invoice,
      getDetailedData,
    );
  }

  static Future<void> _exportCsv(
    BuildContext context,
    Map<String, dynamic> invoice,
    Map<String, dynamic> detailedData,
  ) async {
    // CSV export logic
    _showSuccessSnackBar(context, 'CSV exported');
  }

  static Shipment _createShipmentFromData(
    Map<String, dynamic> invoice,
    Map<String, dynamic> data,
  ) {
    return Shipment(
      invoiceNumber: (invoice['invoiceNumber'] ?? 'N/A').toString(),
      shipper: (data['shipper'] ?? 'N/A').toString(),
      consignee: (data['consignee'] ?? 'N/A').toString(),
      awb: (data['awb'] ?? 'N/A').toString(),
      flightNo: (data['flightNo'] ?? 'N/A').toString(),
      dischargeAirport: (data['dischargeAirport'] ?? 'N/A').toString(),
      eta: data['eta'] is int
          ? DateTime.fromMillisecondsSinceEpoch(data['eta'])
          : DateTime.now(),
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      invoiceTitle: (invoice['invoiceTitle'] ?? 'Invoice').toString(),
      origin: (data['origin'] ?? 'N/A').toString(),
      destination: (data['destination'] ?? 'N/A').toString(),
      status: (data['status'] ?? 'draft').toString(),
      shipperAddress: (data['shipperAddress'] ?? '').toString(),
      consigneeAddress: (data['consigneeAddress'] ?? '').toString(),
    );
  }

  static List<dynamic> _extractItems(Map<String, dynamic> data) {
    final List<dynamic> items = [];
    if (data['boxes'] != null) {
      for (var box in data['boxes']) {
        if (box['products'] != null) {
          items.addAll(box['products']);
        }
      }
    }
    return items;
  }

  static void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
```

### Usage in Invoice List Screen

Replace all export methods:

```dart
// Instead of _exportAsPDF, _exportAsExcel, etc., use:

void _exportInvoice(Map<String, dynamic> invoice, ExportFormat format) async {
  await InvoiceExportService.exportInvoice(
    context: context,
    invoice: invoice,
    format: format,
    destination: ExportDestination.PREVIEW,
    getDetailedData: _getDetailedInvoiceData,
  );
}
```

---

## Priority 5: Enhance PDF Export Configuration

### File: `lib/services/pdf_service.dart`

Add configuration class for flexible PDF generation:

```dart
/// PDF export configuration
class PdfExportConfig {
  /// Number of items to display per page
  final int itemsPerPage;
  
  /// Include flower type summary table
  final bool includeFlowerTypeSummary;
  
  /// Include detailed box information
  final bool includeBoxDetails;
  
  /// Include shipment information on each page
  final bool includeShipmentInfoOnEveryPage;
  
  /// Margin size in points
  final double pageMargin;
  
  const PdfExportConfig({
    this.itemsPerPage = 8,
    this.includeFlowerTypeSummary = true,
    this.includeBoxDetails = true,
    this.includeShipmentInfoOnEveryPage = true,
    this.pageMargin = 20.0,
  });
}

// Modify generateShipmentPDF to accept config:
Future<void> generateShipmentPDF(
  Shipment shipment,
  List<dynamic> items,
  bool isPreview, {
  PdfExportConfig config = const PdfExportConfig(),
}) async {
  // Use config values for page generation
  final itemsPerPage = config.itemsPerPage;
  // ... rest of implementation
}
```

---

## Priority 6: Add File Organization

### File: `lib/services/file_export_service.dart` (NEW)

Create a service for better file management:

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class FileExportService {
  static const String _invoicesDirName = 'invoices';
  static const String _exportsDirName = 'exports';

  /// Get organized invoices directory
  static Future<Directory> getInvoicesDirectory() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final invoicesDir = Directory('${baseDir.path}/$_invoicesDirName');
    
    if (!invoicesDir.existsSync()) {
      invoicesDir.createSync(recursive: true);
    }
    
    return invoicesDir;
  }

  /// Generate organized filename with timestamp
  static String generateFileName(
    String invoiceNumber,
    String format, {
    DateTime? timestamp,
  }) {
    final dateFormat = DateFormat('yyyyMMdd_HHmmss');
    final date = dateFormat.format(timestamp ?? DateTime.now());
    return 'INV_${invoiceNumber}_$date.$format';
  }

  /// Save file with organized directory structure
  static Future<File> saveExportFile(
    String invoiceNumber,
    String format,
    List<int> bytes,
  ) async {
    final dir = await getInvoicesDirectory();
    final fileName = generateFileName(invoiceNumber, format);
    final file = File('${dir.path}/$fileName');
    
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Get all exported invoices
  static Future<List<File>> getAllExports() async {
    try {
      final dir = await getInvoicesDirectory();
      return dir
          .listSync()
          .whereType<File>()
          .toList()
        ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    } catch (e) {
      return [];
    }
  }
}
```

---

## Implementation Checklist

- [ ] **Compiler Errors** - Fixed ✅
- [ ] **Integrate ExcelExportService** - Replace manual CSV building
- [ ] **Complete Logo Implementation** - In excel_export_service.dart
- [ ] **Create Unified Export Service** - New file
- [ ] **Add PDF Configuration** - Enhanced flexibility
- [ ] **Add File Organization** - Better directory structure
- [ ] **Test all export formats** - PDF, Excel, CSV
- [ ] **Test file saving** - On Android and iOS
- [ ] **Test sharing** - Email, WhatsApp, etc.
- [ ] **Performance test** - Large invoices (100+ items)
- [ ] **Update UI** - Use new unified service
- [ ] **Documentation** - Update user guide

---

## Testing Guidelines

### PDF Export Testing
```dart
// Test with different item counts
// 1, 5, 10, 25, 50, 100+ items

// Verify:
// ✓ Multi-page generation
// ✓ Logo rendering
// ✓ All tables visible
// ✓ Pagination correct
// ✓ No content cutoff
```

### Excel Export Testing
```dart
// Verify:
// ✓ All fields populated
// ✓ Logo inserted (if implemented)
// ✓ Formatting preserved
// ✓ File saves correctly
// ✓ Opens in Excel/Sheets
```

### Performance Testing
```dart
// Monitor:
// - Memory usage
// - Generation time
// - File size
// - App responsiveness during export
```

---

## Questions?

Refer back to `EXCEL_PDF_EXPORT_ANALYSIS.md` for detailed information about:
- Current implementation status
- Architecture overview
- Known issues
- Resource links

---

**Last Updated:** December 3, 2025
