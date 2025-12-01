/// Master Shipper model for dropdown data
import 'package:cloud_firestore/cloud_firestore.dart';

class MasterShipper {
  final String id;
  final String name;
  final String
      address; // Single-line formatted address (for DB/Firestore storage)
  // Detailed address components (for parsing/display)
  final String? phone;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? pincode;
  final String? landmark;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MasterShipper({
    required this.id,
    required this.name,
    required this.address,
    this.phone,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.pincode,
    this.landmark,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create from database row
  factory MasterShipper.fromMap(Map<String, dynamic> map) {
    return MasterShipper(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      phone: map['phone'],
      addressLine1: map['addressLine1'] ?? map['address_line1'],
      addressLine2: map['addressLine2'] ?? map['address_line2'],
      city: map['city'],
      state: map['state'],
      pincode: map['pincode'],
      landmark: map['landmark'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] ?? 0),
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'])
          : null,
    );
  }

  /// Convert to database format
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'city': city,
      'state': state,
      'pincode': pincode,
      'landmark': landmark,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
    };
  }

  /// Convert to Firebase format
  Map<String, dynamic> toFirebase() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'state': state,
      'pincode': pincode,
      'landmark': landmark,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Create copy with updated fields
  MasterShipper copyWith({
    String? id,
    String? name,
    String? address,
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? pincode,
    String? landmark,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MasterShipper(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      landmark: landmark ?? this.landmark,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Build formatted single-line address for storage
  static String formatAddress({
    String? phone,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? pincode,
    String? landmark,
  }) {
    final parts = <String>[];
    if ((phone ?? '').isNotEmpty) parts.add('Ph: $phone');
    if ((addressLine1 ?? '').isNotEmpty) parts.add(addressLine1!);
    if ((addressLine2 ?? '').isNotEmpty) parts.add(addressLine2!);
    if ((city ?? '').isNotEmpty) parts.add(city!);
    if ((state ?? '').isNotEmpty) parts.add(state!);
    if ((pincode ?? '').isNotEmpty) parts.add(pincode!);
    if ((landmark ?? '').isNotEmpty) parts.add('($landmark)');
    return parts.join(', ');
  }

  /// Display format for dropdown
  String get displayName => '$name - $address';

  @override
  String toString() => 'MasterShipper(id: $id, name: $name, address: $address)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MasterShipper && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
