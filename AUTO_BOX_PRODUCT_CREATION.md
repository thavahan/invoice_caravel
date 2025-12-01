# Auto Box & Product Creation for Firebase 🚀

## Overview
This system automatically creates boxes and products in Firebase collections nested under shipments, with a `box_ids` array in the shipment collection to reference all created boxes.

## Firebase Collection Structure

```
📁 users/{userId}/
  📁 shipments/
    📄 {invoiceNumber}/
      ├── shipper, consignee, awb, etc.
      ├── box_ids: ["box1_id", "box2_id", ...]  ← Array of box references
      ├── total_boxes: 2
      └── 📁 boxes/
          📄 {boxId}/
            ├── boxNumber, length, width, height
            ├── shipmentId: {invoiceNumber}
            └── 📁 products/
                📄 {productId}/
                  ├── type, description, weight, rate
                  ├── flowerType, hasStems, approxQuantity
                  ├── boxId: {boxId}
                  └── shipmentId: {invoiceNumber}
```

## Key Features

### ✅ Automatic Box ID Management
- Automatically generates unique box IDs
- Updates shipment's `box_ids` array with all created box IDs
- Maintains `total_boxes` count

### ✅ Nested Product Creation
- Creates products within each box's subcollection
- Maintains proper referencing (boxId, shipmentId)
- Supports all flower product fields

### ✅ Draft Publishing Integration
- Enhanced `publishDraft()` automatically creates boxes/products from draft data
- Falls back to creating default empty box if no box data exists

## Usage Examples

### 1. Basic Auto-Creation

```dart
final FirebaseService firebaseService = FirebaseService();

// Box and product data
final boxesData = [
  {
    'boxNumber': 'Box 1',
    'length': 50.0,
    'width': 30.0,
    'height': 25.0,
    'products': [
      {
        'type': 'ROSES',
        'description': 'Fresh Red Roses',
        'weight': 10.5,
        'rate': 25.0,
        'flowerType': 'LOOSE FLOWERS',
        'hasStems': true,
        'approxQuantity': 250,
      }
    ]
  }
];

// Auto-create boxes and products
await firebaseService.autoCreateBoxesAndProducts(
  'INV001', 
  boxesData
);
```

### 2. Using InvoiceProvider

```dart
final provider = Provider.of<InvoiceProvider>(context);

// Create shipment with automatic boxes
await provider.createShipmentWithBoxes(shipment, boxesData);
```

### 3. Using DataService

```dart
final dataService = DataService();

// Works with both Firebase and local database
await dataService.autoCreateBoxesAndProducts(
  shipmentId, 
  boxesData
);
```

### 4. Create Sample Shipment (Development)

```dart
// Creates a complete sample shipment with boxes and products
final sampleInvoiceNumber = await firebaseService.createSampleShipmentWithBoxes('TEST');
print('Sample created: $sampleInvoiceNumber');
```

## Box Data Structure

```dart
{
  'id': 'optional_custom_id',  // Auto-generated if not provided
  'boxNumber': 'Box 1',
  'length': 50.0,
  'width': 30.0,
  'height': 25.0,
  'products': [
    {
      'id': 'optional_custom_id',  // Auto-generated if not provided
      'type': 'ROSES',
      'description': 'Fresh Red Roses - Premium Quality',
      'weight': 10.5,
      'rate': 25.0,
      'flowerType': 'LOOSE FLOWERS',    // LOOSE FLOWERS, TIED GARLANS, etc.
      'hasStems': true,                 // true/false
      'approxQuantity': 250,            // Estimated quantity
    }
  ]
}
```

## Method Reference

### FirebaseService Methods

#### `autoCreateBoxesAndProducts(shipmentId, boxesData)`
- **Purpose**: Batch create boxes and products with automatic ID management
- **Parameters**: 
  - `shipmentId`: The shipment invoice number
  - `boxesData`: List of box data with nested products
- **Returns**: `Future<void>`
- **Updates**: Shipment's `box_ids` array and `total_boxes` count

#### `publishDraft(draftId)`
- **Enhanced**: Now automatically calls `autoCreateBoxesAndProducts`
- **Fallback**: Creates default empty box if no box data in draft

#### `createSampleShipmentWithBoxes(baseInvoiceNumber)`
- **Purpose**: Development helper to create complete sample data
- **Returns**: `Future<String>` (created invoice number)

### DataService Methods

#### `autoCreateBoxesAndProducts(shipmentId, boxesData)`
- **Cross-Platform**: Works with both Firebase and local database
- **Firebase**: Uses enhanced batch creation
- **Local**: Falls back to individual saves

### InvoiceProvider Methods

#### `createShipmentWithBoxes(shipment, boxesData)`
- **Purpose**: High-level shipment creation with auto box/product setup
- **UI Integration**: Updates loading states and notifications

## Error Handling

```dart
try {
  await firebaseService.autoCreateBoxesAndProducts(shipmentId, boxesData);
  print('✅ Boxes and products created successfully');
} catch (e) {
  print('❌ Error: $e');
  // Handle error (show user notification, retry, etc.)
}
```

## Benefits

1. **🎯 Consistency**: Automatic ID generation ensures unique identifiers
2. **🔗 Proper Referencing**: All entities properly reference their parents
3. **📊 Data Integrity**: `box_ids` array maintains shipment-box relationships
4. **🚀 Efficiency**: Batch operations reduce Firebase calls
5. **🛡️ Error Handling**: Comprehensive error handling and logging
6. **🔄 Backward Compatibility**: Works with existing draft system

## Development Testing

Use the sample creation method for testing:

```dart
final testInvoiceNumber = await FirebaseService().createSampleShipmentWithBoxes('DEV_TEST');
```

This creates a complete shipment with:
- 2 boxes with different dimensions
- 3 products across the boxes
- All proper references and IDs
- Realistic flower industry data

## Migration Notes

- Existing shipments without `box_ids` will continue to work
- New shipments automatically get `box_ids` array
- Draft publishing enhanced but maintains backward compatibility
- Local database falls back to individual saves for compatibility