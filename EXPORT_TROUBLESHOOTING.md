# Excel & PDF Export - Troubleshooting & FAQ

Quick reference for common issues and solutions.

---

## Common Issues & Solutions

### PDF Export

#### ❌ "PDF generation failed" or shows blank document

**Possible Causes:**
- No items/products in invoice
- Missing shipment data
- Font files not found

**Solutions:**
```dart
// 1. Verify items are loaded
print('Items count: ${items.length}');
if (items.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('No items to export'))
  );
  return;
}

// 2. Check font files exist at:
// fonts/Cambria.ttf
// fonts/cambriab.ttf

// 3. Verify shipment data is complete
print('Shipment: ${shipment.invoiceNumber}');
print('Items: ${items.length}');
```

#### ❌ "Failed to load image" when generating PDF

**Solution:**
Check logo file path:
```dart
// File must exist at:
asset/images/Caravel_logo.png

// Verify in pubspec.yaml:
flutter:
  uses-material-design: true
  assets:
    - asset/images/
```

#### ⚠️ PDF takes too long to generate

**Performance Tips:**
```dart
// 1. Reduce items per page
ITEMS_PER_TABLE_PAGE = 6; // Instead of 8

// 2. Simplify PDF content
includeFlowerTypeSummary: false,
includeBoxDetails: false,

// 3. Use background generation
// Show loading indicator and generate in background
```

#### ❌ "Package 'printing' not found"

**Solution:**
```bash
flutter pub get
flutter pub cache repair

# Or manually:
flutter pub add printing:^5.14.2
flutter pub add pdf:^3.11.3
```

---

### Excel Export

#### ❌ "Excel export failed" error

**Solutions:**
```dart
// 1. Verify detailed data loaded
final data = await _getDetailedInvoiceData(invoiceId);
if (data.isEmpty) {
  print('ERROR: No detailed data retrieved');
  return;
}

// 2. Check required fields
print('Shipper: ${data['shipper']}');
print('Boxes: ${data['boxes']}');

// 3. Verify file permissions
// AndroidManifest.xml:
// <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

#### ❌ "File write failed" when saving

**Solutions:**
```dart
// 1. Check storage permissions
if (await Permission.storage.isDenied) {
  await Permission.storage.request();
}

// 2. Verify directory exists
final dir = await getApplicationDocumentsDirectory();
print('Directory: ${dir.path}');

// 3. Check available space
// Android: Settings → Storage → Available space
```

#### ⚠️ Logo not showing in Excel

**Current Status:**
- Logo insertion is incomplete in `ExcelExportService`
- Following the Implementation Guide to complete it

**Temporary Workaround:**
```dart
// Add company name instead of logo
sheet.cell(excel.CellIndex.indexByString('A1')).value = 
  excel.TextCellValue('CARAVEL LOGISTICS');
```

#### ❌ "Package 'excel' not found"

**Solution:**
```bash
flutter pub get
flutter pub add excel:^4.0.6
```

---

### File Saving

#### ❌ "Permission denied" on Android

**Solution - AndroidManifest.xml:**
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  
  <!-- Add permissions -->
  <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
  <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
  
  <!-- If targeting Android 12+, add: -->
  <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
  
  <application>
    <!-- ... rest of config ... -->
  </application>
</manifest>
```

**Runtime Permission Check:**
```dart
import 'package:permission_handler/permission_handler.dart';

Future<bool> _requestStoragePermission() async {
  final status = await Permission.storage.request();
  return status.isGranted;
}
```

#### ⚠️ File not visible in file manager

**Reason:** Files saved to `getApplicationDocumentsDirectory()` are in app-private directory

**Solutions:**
```dart
// Option 1: Use Downloads directory (visible)
final dir = await getDownloadsDirectory();

// Option 2: Use external storage
final dir = await getExternalStorageDirectory();

// Option 3: Use new permission model for Android 11+
import 'package:path_provider/path_provider.dart';

final dir = Directory('/storage/emulated/0/Download');
// Requires android.permission.MANAGE_EXTERNAL_STORAGE
```

---

### Sharing Issues

#### ❌ Share dialog doesn't appear

**Solution:**
```dart
// Ensure share_plus is imported and initialized
import 'package:share_plus/share_plus.dart';

// Proper share implementation
await Share.shareFiles(
  [filePath],
  text: 'Invoice ${invoiceNumber}',
  subject: 'Invoice Export',
);
```

#### ❌ PDF can't be opened from share

**Solution:**
```dart
// When sharing, ensure file is saved first
final bytes = await pdf.save();
final dir = await getApplicationDocumentsDirectory();
final file = File('${dir.path}/invoice.pdf');
await file.writeAsBytes(bytes);

// Then share
await Share.shareFiles([file.path]);
```

---

## Performance Issues

### PDF Generation Slow

**Optimization Steps:**

1. **Reduce content per page:**
   ```dart
   ITEMS_PER_TABLE_PAGE = 5; // Smaller = faster
   ```

2. **Disable unnecessary tables:**
   ```dart
   showSummary: true,
   showTable1: true,
   showTable2: false, // Skip flower type summary
   ```

3. **Profile memory usage:**
   ```dart
   // Use DevTools Memory profiler
   // In VS Code: Debug → Open DevTools
   ```

### Large File Sizes

**Solutions:**

1. **Compress PDF:**
   ```dart
   // pdf package supports compression
   pdf.settings.compress = true;
   ```

2. **Limit item count:**
   ```dart
   // Only include necessary items
   final filteredItems = items.take(50).toList();
   ```

3. **Archive exported files:**
   ```dart
   // Implement ZIP compression for storage
   import 'package:archive/archive.dart';
   ```

---

## Debug Prints

Enable debug output for troubleshooting:

### In PdfService
```dart
// Already included - look for these prints
📄 Starting intelligent N-page PDF generation
📦 Processing XX items for shipment
📄 Building page N: XXXX
📄 Successfully generated X pages
✅ PDF Generation Completed
❌ PDF Generation Error: XXXX
```

### In ExcelExportService
```dart
print('Creating Excel export for "${invoice['invoiceTitle']}"');
print('Logo placeholder added to Excel export');
print('Excel file generation completed');
```

### To Enable All Debug Prints
```bash
# Run with verbose logging
flutter run --verbose

# Or in code:
debugPrintBeginFrame = true;
debugPrintEndFrame = true;
```

---

## FAQ

### Q: Can I customize the PDF layout?

**A:** Yes! Create a `PdfExportConfig`:
```dart
const config = PdfExportConfig(
  itemsPerPage: 10,
  includeFlowerTypeSummary: false,
  pageMargin: 25.0,
);

await pdfService.generateShipmentPDF(
  shipment,
  items,
  true,
  config: config,
);
```

### Q: How do I export multiple invoices at once?

**A:** Implement batch export:
```dart
Future<void> exportMultipleInvoices(List<String> invoiceIds) async {
  for (final id in invoiceIds) {
    final invoice = await _getInvoiceData(id);
    await _exportAsPDF(invoice);
  }
}
```

### Q: Can I send exports via email directly?

**A:** Partially - UI is ready, backend needs implementation:
```dart
// Current: Email composition UI only
// To implement: Use platform channels or mailto:
import 'package:mailer/mailer.dart'; // Add this package

// Send via SMTP (requires server config)
```

### Q: What file formats are supported?

**A:** Currently:
- ✅ PDF (fully featured)
- ✅ Excel (professional formatting)
- ✅ CSV (text export)
- 🔜 Email (UI ready, backend pending)

### Q: How do I access exported files?

**A:** Files saved to app directory:
```dart
// Android: /data/data/com.example.app/app_documents/invoices/
// iOS: /Library/Application Support/invoices/

// Access via:
final dir = await getApplicationDocumentsDirectory();
print('Files at: ${dir.path}');
```

### Q: Can I customize PDF header/footer?

**A:** Yes! Modify `PdfService`:
```dart
// Line ~250: _buildAdvancedHeader()
// Line ~300: _buildAdvancedFooter()
// Customize colors, text, logo size
```

---

## Performance Benchmarks

### Expected Generation Times

| Item Count | PDF Gen | Excel Gen | File Size |
|----------|---------|-----------|-----------|
| 10       | 0.5s    | 0.3s      | 80 KB     |
| 50       | 1.5s    | 0.8s      | 150 KB    |
| 100      | 2.5s    | 1.2s      | 250 KB    |
| 200      | 4.5s    | 2.0s      | 450 KB    |

*Times vary based on device and content complexity*

---

## Getting Help

1. **Check Compiler Errors:**
   ```bash
   flutter analyze
   ```

2. **Review Debug Prints:**
   ```bash
   flutter run --verbose
   ```

3. **Check Device Logs:**
   ```bash
   adb logcat | grep flutter
   ```

4. **Reference Documentation:**
   - PDF: https://pub.dev/packages/pdf
   - Excel: https://pub.dev/packages/excel
   - Printing: https://pub.dev/packages/printing

---

## Related Files

- `EXCEL_PDF_EXPORT_ANALYSIS.md` - Detailed analysis
- `EXPORT_IMPLEMENTATION_GUIDE.md` - Step-by-step guide
- `lib/services/pdf_service.dart` - PDF generation
- `lib/services/excel_export_service.dart` - Excel export
- `lib/screens/invoice_list_screen.dart` - UI integration

---

**Last Updated:** December 3, 2025
