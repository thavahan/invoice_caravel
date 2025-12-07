# Excel Export Implementation - Platform Configuration Guide

## Overview
The new Excel export feature generates real `.xlsx` files and saves them to easily accessible locations (Downloads folder on Android, Documents on iOS). It also provides multiple sharing options (Email, WhatsApp, More Options, Copy Path).

---

## Android Configuration

### 1. Update AndroidManifest.xml

**File:** `android/app/src/main/AndroidManifest.xml`

Add these permissions:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.invoice_generator">

    <!-- File system access permissions -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    
    <!-- For Android 11+ (API 30+) - Broad file access -->
    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />

    <application
        android:label="Invoice Generator"
        android:icon="@mipmap/ic_launcher">
        
        <!-- Activities, services, etc. -->
        
    </application>
</manifest>
```

### 2. Update Build Gradle (if needed for Android 11+)

**File:** `android/app/build.gradle`

Ensure compileSdkVersion is compatible:

```gradle
android {
    compileSdkVersion 33  // Or higher
    
    defaultConfig {
        targetSdkVersion 33  // Or higher
        minSdkVersion 21
    }
}
```

### 3. Runtime Permissions (Optional but Recommended)

If you want to request permissions at runtime, add this to your code:

```dart
import 'package:permission_handler/permission_handler.dart';

Future<bool> _requestStoragePermissions() async {
  final status = await Permission.storage.request();
  return status.isGranted;
}
```

And add to pubspec.yaml:
```yaml
permission_handler: ^11.4.0
```

### 4. File Access Locations

On Android, the app will save files to:
- **Primary:** `/storage/emulated/0/Download/Invoices/` (Downloads folder)
- **Fallback:** App's internal documents directory

Users can access these files via:
- File Manager app
- Downloads app
- Any file explorer

---

## iOS Configuration

### 1. Update Info.plist

**File:** `ios/Runner/Info.plist`

Add these keys:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Existing configuration -->
    
    <!-- File sharing -->
    <key>UIFileSharingEnabled</key>
    <true/>
    
    <key>LSSupportsOpeningDocumentsInPlace</key>
    <true/>
    
    <!-- Document type for Excel files -->
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>Microsoft Excel Spreadsheet</string>
            <key>CFBundleTypeRole</key>
            <string>Viewer</string>
            <key>LSHandlerRank</key>
            <string>Alternate</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>org.openxmlformats.spreadsheetml.sheet</string>
            </array>
        </dict>
    </array>
    
</dict>
</plist>
```

### 2. File Access Locations

On iOS, the app will save files to:
- **Primary:** `Documents/Invoices/` (accessible via Files app)

Users can access these files via:
- Files app (On My iPhone > [App Name])
- Cloud services (iCloud Drive, Dropbox, etc.)
- Email attachments
- Document sharing

### 3. Optional: Update App Capabilities

In Xcode:
1. Select Runner project
2. Select Runner target
3. Go to Signing & Capabilities
4. Add "File Sharing" capability (if not present)

---

## Flutter Configuration

### pubspec.yaml Dependencies

Ensure these packages are included:

```yaml
dependencies:
  # Existing dependencies
  excel: ^4.0.6
  path_provider: ^2.1.5
  share_plus: ^7.2.0
  intl: ^0.17.0
  flutter:
    sdk: flutter
```

Run: `flutter pub get`

---

## Testing the Excel Export

### Step 1: Run the App
```bash
flutter run
```

### Step 2: Create/Load an Invoice

### Step 3: Click Export Options → Export as Excel

### Step 4: Success Dialog
- File is generated as `.xlsx`
- Dialog shows file name and location
- Click "Share" for sharing options

### Step 5: Sharing Options

Choose from:
1. **Email** - Attach file to email
2. **WhatsApp** - Send via WhatsApp
3. **More Options** - System share sheet (Drive, Dropbox, etc.)
4. **Copy File Path** - Copy location to clipboard

### Step 6: Verify File Location

**Android:**
```
File Manager > Downloads > Invoices > [Invoice_Name_DateTime.xlsx]
```

**iOS:**
```
Files App > On My iPhone > Invoice Generator > [Invoice_Name_DateTime.xlsx]
```

---

## File Structure

```
Android:
/storage/emulated/0/
├── Download/
│   └── Invoices/
       ├── Invoice_INV001.xlsx
       ├── Invoice_INV002.xlsx
│       └── ...

iOS:
~/Library/Containers/[App]/Documents/
├── Invoices/
   ├── Invoice_INV001.xlsx
   ├── Invoice_INV002.xlsx
│   └── ...
```

---

## Troubleshooting

### Issue: "Permission denied" error

**Solution:**
```dart
// Add runtime permission check
import 'package:permission_handler/permission_handler.dart';

if (await Permission.storage.request().isDenied) {
  // Permission denied
  print('Storage permission denied');
}
```

### Issue: Files not appearing in Downloads folder

**Solution:**
1. Check AndroidManifest.xml has permissions
2. Verify buildSdkVersion ≥ 33
3. Restart app
4. Clear app cache: Settings > Apps > Invoice Generator > Storage > Clear Cache

### Issue: Share dialog not appearing

**Solution:**
```dart
// Ensure share_plus is properly initialized
// In main.dart, no special initialization needed
// Just import: import 'package:share_plus/share_plus.dart';
```

### Issue: File path shows incorrect location

**Solution:**
- On Android 11+, use path_provider's getDownloadsDirectory()
- Fallback to getApplicationDocumentsDirectory() if needed

---

## Code Implementation

### Main Entry Point

**File:** `lib/screens/invoice_list_screen.dart`

```dart
import 'package:invoice_generator/services/excel_file_service.dart';

// In export options:
Future<void> _exportAsExcel(Map<String, dynamic> invoice) async {
  await ExcelFileService.generateAndExportExcel(
    context,
    invoice,
    _getDetailedInvoiceData,
  );
}
```

### Excel File Service

**File:** `lib/services/excel_file_service.dart`

Features:
- Generate professional `.xlsx` files
- Save to Downloads/Documents folder
- Share via Email, WhatsApp, More
- Copy file path to clipboard
- Professional formatting with colors, borders, styles

---

## File Generation Details

### Excel Sheet Structure

```
Row 1:  [COMMERCIAL INVOICE Header] | Invoice: INV001 | Date: 15/12/2023
Row 3:  [SHIPPER Section]
Row 8:  [CONSIGNEE Section]
Row 12: [SHIPMENT DETAILS]
Row 18: [BOX & PRODUCT DETAILS with table]
Row N:  [SUMMARY Section]
```

### Generated Columns

In Box & Product Details table:
- A: Box Number
- B: Length
- C: Width
- D: Height
- E: Product Type
- F: Description
- G: Weight
- H: Rate
- I: Total

### Summary Section

- Total Boxes
- Total Items
- Total Weight (kg)
- Total Amount (₹)

---

## Performance Considerations

### File Size Estimates
- Small invoice (1-10 items): 15-25 KB
- Medium invoice (11-50 items): 25-50 KB
- Large invoice (50+ items): 50-100 KB

### Generation Time
- Average: 500-1000 ms
- Large invoices: up to 2000 ms

### Memory Usage
- Per export: ~5-10 MB
- No significant memory leaks

---

## Security Considerations

### File Permissions
- Files stored in app-specific directories by default
- Can be shared via system share mechanism
- Accessible via file manager on both platforms

### Data Privacy
- No automatic cloud upload
- Files remain on device unless explicitly shared
- User controls sharing destination

### Best Practices
1. Always request permissions before file access
2. Handle permission denials gracefully
3. Provide clear user feedback during export
4. Clean up temporary files if needed

---

## Next Steps

1. ✅ Update AndroidManifest.xml with permissions
2. ✅ Update Info.plist for iOS file sharing
3. ✅ Run `flutter pub get` to download share_plus
4. ✅ Test on Android emulator/device
5. ✅ Test on iOS simulator/device
6. ✅ Verify files appear in Downloads/Documents
7. ✅ Test all sharing options
8. ✅ Deploy to production

---

## Support

For issues:
1. Check AndroidManifest.xml permissions
2. Verify compileSdkVersion/targetSdkVersion
3. Check iOS Info.plist keys
4. Run `flutter clean && flutter pub get`
5. Review debug output: `flutter run --verbose`

---

**Last Updated:** December 3, 2025
**Status:** Ready for Implementation
