class Box {
  final String id;
  final String boxNumber;
  final List<String> itemIds; // References to items in this box

  Box({
    this.id = '',
    required this.boxNumber,
    this.itemIds = const [],
  });

  factory Box.fromMap(String id, Map<String, dynamic> map) {
    return Box(
      id: id,
      boxNumber: map['box_number'] ?? '',
      itemIds: List<String>.from(map['item_ids'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'box_number': boxNumber,
      'item_ids': itemIds,
    };
  }

  @override
  String toString() => 'Box $boxNumber';
}
