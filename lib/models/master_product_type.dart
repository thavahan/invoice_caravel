/// Master Product Type model for dropdown data
import 'package:cloud_firestore/cloud_firestore.dart';

class MasterProductType {
  final String id;
  final String name;
  final int approxQuantity;
  final bool hasStems;
  final double rate;
  final String category;
  final String genusSpeciesName;
  final String plantFamilyName;
  final String? specials;
  final String countryOfOrigin;
  final DateTime createdAt;
  final DateTime? updatedAt;

  MasterProductType({
    required this.id,
    required this.name,
    required this.approxQuantity,
    required this.hasStems,
    required this.rate,
    required this.category,
    required this.genusSpeciesName,
    required this.plantFamilyName,
    this.specials,
    required this.countryOfOrigin,
    required this.createdAt,
    this.updatedAt,
  });

  /// Create from database row
  factory MasterProductType.fromMap(Map<String, dynamic> map) {
    return MasterProductType(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      approxQuantity: (map['approx_quantity'] ?? 1).toInt(),
      hasStems: (map['has_stems'] ?? 0) == 1,
      rate: (map['rate'] ?? 0.0).toDouble(),
      category: map['category'] ?? '',
      genusSpeciesName: map['genus_species_name'] ?? '',
      plantFamilyName: map['plant_family_name'] ?? '',
      specials: map['specials'],
      countryOfOrigin: map['country_of_origin'] ?? '',
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
      'approx_quantity': approxQuantity,
      'has_stems': hasStems ? 1 : 0,
      'rate': rate,
      'category': category,
      'genus_species_name': genusSpeciesName,
      'plant_family_name': plantFamilyName,
      'specials': specials,
      'country_of_origin': countryOfOrigin,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
    };
  }

  /// Convert to Firebase format
  Map<String, dynamic> toFirebase() {
    return {
      ...toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Create copy with updated fields
  MasterProductType copyWith({
    String? id,
    String? name,
    int? approxQuantity,
    bool? hasStems,
    double? rate,
    String? category,
    String? genusSpeciesName,
    String? plantFamilyName,
    String? specials,
    String? countryOfOrigin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MasterProductType(
      id: id ?? this.id,
      name: name ?? this.name,
      approxQuantity: approxQuantity ?? this.approxQuantity,
      hasStems: hasStems ?? this.hasStems,
      rate: rate ?? this.rate,
      category: category ?? this.category,
      genusSpeciesName: genusSpeciesName ?? this.genusSpeciesName,
      plantFamilyName: plantFamilyName ?? this.plantFamilyName,
      specials: specials ?? this.specials,
      countryOfOrigin: countryOfOrigin ?? this.countryOfOrigin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'MasterProductType(id: $id, name: $name)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MasterProductType && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
