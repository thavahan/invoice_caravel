# Excel Invoice Layout Reference - Visual Guide

## Quick Reference: Excel Invoice Section Order

```
┌─────────────────────────────────────────────────────────────────┐
│                        ROW 1-2                                   │
│                      INVOICE HEADER                              │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  INVOICE                                  INV No  [001]    │ │
│  │                                           DATED   [15 DEC] │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        ROWS 3-11                                 │
│            SHIPPER & CONSIGNEE SECTION                          │
│  ┌──────────────────────┐      ┌──────────────────────────────┐ │
│  │ Shipper:             │      │ Client Ref: ABC123           │ │
│  │ [Company Name]       │      │                              │ │
│  │ [Address]            │      │ Issued At:                   │ │
│  │                      │      │ Date of Issue: [15 DEC]      │ │
│  │                      │      │                              │ │
│  │ Consignee:           │      │                              │ │
│  │ [Company Name]       │      │                              │ │
│  │ [Address]            │      │                              │ │
│  └──────────────────────┘      └──────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        ROWS 12-13                                │
│               BILL TO SECTION                                   │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │ Bill to                                                    │ │
│  │ [CONSIGNEE NAME IN UPPERCASE]                             │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        ROWS 14-21                                │
│           FLIGHT & AWB SECTION                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ AWB NO:                 Place of Receipt:                │  │
│  │ [AWB123]                [ORIGIN LOCATION]                │  │
│  │                         [SHIPPER]                        │  │
│  │                                                           │  │
│  │ FLIGHT NO              AIRPORT OF DEPARTURE              │  │
│  │ FL001 / 15 DEC 2025    [ORIGIN]                 GST: ... │  │
│  │                                                IEC: ...   │  │
│  │ AirPort of Discharge  Place of Delivery                 │  │
│  │ [DESTINATION]         [DESTINATION]                      │  │
│  │                                                           │  │
│  │ ETA into [DESTINATION]  Freight Terms                   │  │
│  │ 17 DEC 2025             PRE PAID                         │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        ROWS 25-30+                               │
│            PRODUCT TABLE                                        │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Marks &    No. & Kind                    Gross  Net      │  │
│  │ Nos.       of Pkgs    Description        Weight Weight    │  │
│  │                       Said to Contain    KGS    KGS       │  │
│  │────────────────────────────────────────────────────────── │  │
│  │            20                                             │  │
│  │            BOX 1      [PRODUCT TYPE]     50     45        │  │
│  │            BOX 2      [PRODUCT TYPE]     75     70        │  │
│  │            BOX 3      Empty Box          0      0         │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        ROWS 35-45                                │
│            CHARGES SECTION                                      │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ CHARGES                RATE    UNIT      AMOUNT          │  │
│  │────────────────────────────────────────────────────────── │  │
│  │ PRODUCT TYPE A         100     50        5000            │  │
│  │ PRODUCT TYPE B         150     75        11250           │  │
│  │────────────────────────────────────────────────────────── │  │
│  │ Gross Total                    125       16250           │  │
│  │ (Bold)                                                    │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        ROWS 48+                                  │
│            TOTAL IN WORDS                                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Gross Total (in words): SIXTEEN THOUSAND TWO HUNDRED     │  │
│  │                         FIFTY DOLLARS ONLY               │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Column Assignments

```
Column A: Marks & Nos, Shipper labels, Charges names
Column B: Packages info, AWB/Flight details, Rates
Column C: [Empty/Spacing]
Column D: Description, Consignee details, Charge descriptions
Column E: [Continuation], RATE header
Column F: Gross Weight, UNIT header
Column G: Net Weight, AMOUNT header
```

## Data Field Mapping

### Required in Invoice Map
```dart
invoice {
  'invoiceNumber': 'INV001',
  'invoiceTitle': 'My Invoice',
  'clientRef': 'ABC123'
}
```

### Required in DetailedInvoiceData
```dart
detailedData {
  // Shipper Details
  'shipper': 'Shipper Company Name',
  'shipperAddress': 'Shipper Address',
  'origin': 'DEL',  // 3-letter airport code
  
  // Consignee Details
  'consignee': 'Consignee Company Name',
  'consigneeAddress': 'Consignee Address',
  'destination': 'NYC',
  'dischargeAirport': 'New York',
  
  // Flight & AWB
  'awb': 'AWB123456789',
  'flightNo': 'FL001',
  
  // Taxes & Codes
  'sgstNo': 'GSTIN123',
  'iecCode': 'IEC123',
  
  // Boxes and Products
  'boxes': [
    {
      'boxNumber': 'BOX 1',
      'length': 10,
      'width': 20,
      'height': 15,
      'products': [
        {
          'type': 'FABRIC',
          'description': '100% Cotton',
          'weight': 50,
          'rate': 100
        }
      ]
    }
  ]
}
```

## Date/Time Formatting

```dart
// All dates use this format:
DateFormat('dd MMM yyyy').format(DateTime.now()).toUpperCase()

Examples:
15 DEC 2025
01 JAN 2026
28 FEB 2025
31 MAR 2024
```

## Number-to-Words Conversion Examples

```
Amount → Converted Text
0.00   → ZERO DOLLARS ONLY
1.00   → ONE DOLLAR ONLY
10.00  → TEN DOLLARS ONLY
100.00 → ONE HUNDRED DOLLARS ONLY
1,234.50 → ONE THOUSAND TWO HUNDRED THIRTY FOUR DOLLARS AND FIFTY CENTS ONLY
5,200.00 → FIVE THOUSAND TWO HUNDRED DOLLARS ONLY
```

## File Storage Locations

```
Platform: Android
├─ Storage Path: /storage/emulated/0/Download/Invoices/
├─ Accessible from: Files app → Downloads → Invoices
└─ Files appear as: Invoice_INV001.xlsx

Platform: iOS
├─ Storage Path: ~/Library/Containers/[AppName]/Documents/Invoices/
├─ Accessible from: Files app → [App Name] → Invoices
└─ Files appear as: Invoice_INV001.xlsx
```

## Sharing Flow Diagram

```
User clicks "Share" button
        ↓
Shares Excel file
        ↓
   ┌────┴──────────┬──────────────┬─────────────┐
   ↓               ↓              ↓             ↓
Email          WhatsApp      More Options   Copy Path
   ↓               ↓              ↓             ↓
Opens mail    Opens WhatsApp   Share sheet   Clipboard
client        with file        (GDrive,      (Path
with          attached         Dropbox,      copied)
attachment                      etc.)
```

## Import/Export Workflow

```
Invoice List Screen
        ↓
   User taps "Export"
        ↓
ExcelFileService.generateAndExportExcel()
        ↓
   Get detailed data
        ↓
   Create workbook
        ↓
   Add all 7 sections ← [Your exact template structure]
        ↓
   Auto-size columns
        ↓
   Save to platform path
        ↓
   Show success dialog
        ↓
   User chooses:
   - Share (4 options)
   - Close
```

## Font & Style Reference

```
Main Invoice Title "INVOICE"
├─ Font Size: 14pt
├─ Bold: Yes
└─ Case: Standard

Section Headers ("Shipper:", "Consignee:", etc.)
├─ Font Size: 11pt (default)
├─ Bold: Yes
└─ Case: Sentence case

Table Headers (Column names)
├─ Font Size: 10pt
├─ Bold: Yes
└─ Case: UPPERCASE

Data Content
├─ Font Size: 10pt (default)
├─ Bold: No (unless specified)
└─ Case: Varies (see data)

Totals & Summary
├─ Font Size: 11pt
├─ Bold: Yes
└─ Case: Title Case
```

## Common Test Data

```dart
// Minimal test invoice
Map<String, dynamic> testInvoice = {
  'invoiceNumber': 'TEST001',
  'invoiceTitle': 'Test Invoice',
  'clientRef': 'TEST-REF'
};

Map<String, dynamic> testDetailedData = {
  'shipper': 'Test Shipper Co.',
  'shipperAddress': '123 Test St, Test City',
  'consignee': 'Test Consignee Co.',
  'consigneeAddress': '456 Test Ave, Test City',
  'origin': 'DEL',
  'destination': 'BOM',
  'dischargeAirport': 'Mumbai',
  'awb': 'TEST123456789',
  'flightNo': 'FL123',
  'sgstNo': 'TEST123',
  'iecCode': 'TEST456',
  'boxes': [
    {
      'boxNumber': 'BOX 1',
      'products': [
        {
          'type': 'TEST_PRODUCT',
          'description': 'Test item',
          'weight': 50,
          'rate': 100
        }
      ]
    }
  ]
};
```

---

**Visual Reference Guide**  
Last Updated: December 3, 2025  
Status: Complete & Ready for Testing
