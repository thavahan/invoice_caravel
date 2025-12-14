class Shipment {
  final String invoiceNumber;
  final String shipper;
  final String shipperAddress;
  final String consignee;
  final String consigneeAddress;
  final String clientRef;
  final String awb;
  final String flightNo;
  final String dischargeAirport;
  final String origin;
  final String destination;
  final DateTime eta;
  final DateTime? invoiceDate;
  final DateTime? dateOfIssue;
  final String placeOfReceipt;
  final String sgstNo;
  final String iecCode;
  final String freightTerms;
  final double totalAmount;
  final String invoiceTitle;
  final String status;
  final List<String> boxIds; // References to boxes in this shipment

  Shipment({
    required this.invoiceNumber,
    required this.shipper,
    this.shipperAddress = '',
    required this.consignee,
    this.consigneeAddress = '',
    this.clientRef = '',
    required this.awb,
    required this.flightNo,
    required this.dischargeAirport,
    this.origin = '',
    this.destination = '',
    required this.eta,
    this.invoiceDate,
    this.dateOfIssue,
    this.placeOfReceipt = '',
    this.sgstNo = '',
    this.iecCode = '',
    this.freightTerms = '',
    required this.totalAmount,
    required this.invoiceTitle,
    this.status = 'pending',
    this.boxIds = const [],
  });

  /// Create Shipment from SQLite database row
  factory Shipment.fromSQLite(Map<String, dynamic> map) {
    return Shipment(
      invoiceNumber: map['invoice_number'] ?? '',
      shipper: map['shipper'] ?? '',
      shipperAddress: map['shipper_address'] ?? '',
      consignee: map['consignee'] ?? '',
      consigneeAddress: map['consignee_address'] ?? '',
      clientRef: map['client_ref'] ?? '',
      awb: map['awb'] ?? '',
      flightNo: map['flight_no'] ?? '',
      dischargeAirport: map['discharge_airport'] ?? '',
      origin: map['origin'] ?? '',
      destination: map['destination'] ?? '',
      eta: DateTime.fromMillisecondsSinceEpoch(map['eta'] ?? 0),
      invoiceDate: map['invoice_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['invoice_date'])
          : null,
      dateOfIssue: map['date_of_issue'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['date_of_issue'])
          : null,
      placeOfReceipt: map['place_of_receipt'] ?? '',
      sgstNo: map['sgst_no'] ?? '',
      iecCode: map['iec_code'] ?? '',
      freightTerms: map['freight_terms'] ?? '',
      totalAmount: (map['total_amount'] ?? 0.0).toDouble(),
      invoiceTitle: map['invoice_title'] ?? '',
      status: (map['status'] ?? 'pending').toString(),
      boxIds: [], // Box IDs will be loaded separately via join queries
    );
  }

  /// Legacy method for Firebase compatibility
  factory Shipment.fromMap(String id, Map<String, dynamic> map) {
    return Shipment(
      invoiceNumber: map['invoice_number'] ?? map['invoiceNumber'] ?? id,
      shipper: map['shipper'] ?? '',
      shipperAddress: map['shipper_address'] ?? map['shipperAddress'] ?? '',
      consignee: map['consignee'] ?? '',
      consigneeAddress:
          map['consignee_address'] ?? map['consigneeAddress'] ?? '',
      clientRef: map['client_ref'] ?? map['clientRef'] ?? '',
      awb: map['AWB'] ?? '',
      flightNo: map['flight_no'] ?? '',
      dischargeAirport: map['discharge_airport'] ?? '',
      origin: map['origin'] ?? '',
      destination: map['destination'] ?? '',
      eta: DateTime.fromMillisecondsSinceEpoch(map['eta'] ?? 0),
      invoiceDate: map['invoice_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['invoice_date'])
          : null,
      dateOfIssue: map['date_of_issue'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['date_of_issue'])
          : null,
      placeOfReceipt: map['place_of_receipt'] ?? map['placeOfReceipt'] ?? '',
      sgstNo: map['sgst_no'] ?? map['sgstNo'] ?? '',
      iecCode: map['iec_code'] ?? map['iecCode'] ?? '',
      freightTerms: map['freight_terms'] ?? map['freightTerms'] ?? '',
      totalAmount: (map['total_amount'] ?? 0.0).toDouble(),
      invoiceTitle: map['invoice_title'] ?? '',
      status: (map['status'] ?? 'pending').toString(),
      boxIds: List<String>.from(map['box_ids'] ?? []),
    );
  }

  /// Convert to SQLite-compatible map
  Map<String, dynamic> toSQLite() {
    return {
      'invoice_number': invoiceNumber,
      'shipper': shipper,
      'shipper_address': shipperAddress,
      'consignee': consignee,
      'consignee_address': consigneeAddress,
      'client_ref': clientRef,
      'awb': awb,
      'flight_no': flightNo,
      'discharge_airport': dischargeAirport,
      'origin': origin,
      'destination': destination,
      'eta': eta.millisecondsSinceEpoch,
      'invoice_date': invoiceDate?.millisecondsSinceEpoch,
      'date_of_issue': dateOfIssue?.millisecondsSinceEpoch,
      'place_of_receipt': placeOfReceipt,
      'sgst_no': sgstNo,
      'iec_code': iecCode,
      'freight_terms': freightTerms,
      'total_amount': totalAmount,
      'invoice_title': invoiceTitle,
      'status': status,
    };
  }

  /// Convert to Firebase format
  Map<String, dynamic> toFirebase() {
    return {
      'invoiceNumber': invoiceNumber,
      'invoice_number': invoiceNumber, // Keep legacy field for compatibility
      'shipper': shipper,
      'shipper_address': shipperAddress,
      'shipperAddress': shipperAddress, // Keep legacy field for compatibility
      'consignee': consignee,
      'consignee_address': consigneeAddress,
      'consigneeAddress':
          consigneeAddress, // Keep legacy field for compatibility
      'client_ref': clientRef,
      'clientRef': clientRef, // Keep legacy field for compatibility
      'AWB': awb,
      'awb': awb, // Keep legacy field for compatibility
      'flight_no': flightNo,
      'flightNo': flightNo, // Keep legacy field for compatibility
      'discharge_airport': dischargeAirport,
      'dischargeAirport':
          dischargeAirport, // Keep legacy field for compatibility
      'origin': origin,
      'destination': destination,
      'eta': eta.millisecondsSinceEpoch,
      'invoice_date': invoiceDate?.millisecondsSinceEpoch,
      'invoiceDate': invoiceDate
          ?.millisecondsSinceEpoch, // Keep legacy field for compatibility
      'date_of_issue': dateOfIssue?.millisecondsSinceEpoch,
      'dateOfIssue': dateOfIssue
          ?.millisecondsSinceEpoch, // Keep legacy field for compatibility
      'place_of_receipt': placeOfReceipt,
      'placeOfReceipt': placeOfReceipt, // Keep legacy field for compatibility
      'sgst_no': sgstNo,
      'sgstNo': sgstNo, // Keep legacy field for compatibility
      'iec_code': iecCode,
      'iecCode': iecCode, // Keep legacy field for compatibility
      'freight_terms': freightTerms,
      'freightTerms': freightTerms, // Keep legacy field for compatibility
      'total_amount': totalAmount,
      'totalAmount': totalAmount, // Keep legacy field for compatibility
      'invoice_title': invoiceTitle,
      'invoiceTitle': invoiceTitle, // Keep legacy field for compatibility
      'status': status,
      'box_ids': boxIds,
      'boxIds': boxIds, // Keep legacy field for compatibility
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Create Shipment from Firebase data
  factory Shipment.fromFirebase(Map<String, dynamic> map) {
    return Shipment(
      invoiceNumber: map['invoiceNumber'] ?? map['invoice_number'] ?? '',
      shipper: map['shipper'] ?? '',
      shipperAddress: map['shipperAddress'] ?? map['shipper_address'] ?? '',
      consignee: map['consignee'] ?? '',
      consigneeAddress:
          map['consigneeAddress'] ?? map['consignee_address'] ?? '',
      clientRef: map['clientRef'] ?? map['client_ref'] ?? '',
      awb: map['AWB'] ?? map['awb'] ?? '',
      flightNo: map['flightNo'] ?? map['flight_no'] ?? '',
      dischargeAirport:
          map['dischargeAirport'] ?? map['discharge_airport'] ?? '',
      origin: map['origin'] ?? '',
      destination: map['destination'] ?? '',
      eta: map['eta'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['eta'])
          : DateTime.now(),
      invoiceDate: map['invoiceDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['invoiceDate'])
          : (map['invoice_date'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['invoice_date'])
              : null),
      dateOfIssue: map['dateOfIssue'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dateOfIssue'])
          : (map['date_of_issue'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['date_of_issue'])
              : null),
      placeOfReceipt: map['placeOfReceipt'] ?? map['place_of_receipt'] ?? '',
      sgstNo: map['sgstNo'] ?? map['sgst_no'] ?? '',
      iecCode: map['iecCode'] ?? map['iec_code'] ?? '',
      freightTerms: map['freightTerms'] ?? map['freight_terms'] ?? '',
      totalAmount:
          (map['totalAmount'] ?? map['total_amount'] ?? 0.0).toDouble(),
      invoiceTitle: map['invoiceTitle'] ?? map['invoice_title'] ?? '',
      status: map['status'] ?? 'pending',
      boxIds: List<String>.from(map['boxIds'] ?? map['box_ids'] ?? []),
    );
  }

  /// Legacy method for Firebase compatibility
  Map<String, dynamic> toMap() {
    return {
      'shipper': shipper,
      'shipper_address': shipperAddress,
      'consignee': consignee,
      'consignee_address': consigneeAddress,
      'client_ref': clientRef,
      'AWB': awb,
      'flight_no': flightNo,
      'discharge_airport': dischargeAirport,
      'origin': origin,
      'destination': destination,
      'eta': eta.millisecondsSinceEpoch,
      'invoice_date': invoiceDate?.millisecondsSinceEpoch,
      'date_of_issue': dateOfIssue?.millisecondsSinceEpoch,
      'place_of_receipt': placeOfReceipt,
      'sgst_no': sgstNo,
      'iec_code': iecCode,
      'freight_terms': freightTerms,
      'total_amount': totalAmount,
      'invoice_title': invoiceTitle,
      'status': status,
      'box_ids': boxIds,
    };
  }

  /// Create a copy with updated fields
  Shipment copyWith({
    String? invoiceNumber,
    String? shipper,
    String? shipperAddress,
    String? consignee,
    String? consigneeAddress,
    String? clientRef,
    String? awb,
    String? flightNo,
    String? dischargeAirport,
    String? origin,
    String? destination,
    DateTime? eta,
    DateTime? invoiceDate,
    DateTime? dateOfIssue,
    String? placeOfReceipt,
    String? sgstNo,
    String? iecCode,
    String? freightTerms,
    double? totalAmount,
    String? invoiceTitle,
    String? status,
    List<String>? boxIds,
  }) {
    return Shipment(
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      shipper: shipper ?? this.shipper,
      shipperAddress: shipperAddress ?? this.shipperAddress,
      consignee: consignee ?? this.consignee,
      consigneeAddress: consigneeAddress ?? this.consigneeAddress,
      clientRef: clientRef ?? this.clientRef,
      awb: awb ?? this.awb,
      flightNo: flightNo ?? this.flightNo,
      dischargeAirport: dischargeAirport ?? this.dischargeAirport,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      eta: eta ?? this.eta,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dateOfIssue: dateOfIssue ?? this.dateOfIssue,
      placeOfReceipt: placeOfReceipt ?? this.placeOfReceipt,
      sgstNo: sgstNo ?? this.sgstNo,
      iecCode: iecCode ?? this.iecCode,
      freightTerms: freightTerms ?? this.freightTerms,
      totalAmount: totalAmount ?? this.totalAmount,
      invoiceTitle: invoiceTitle ?? this.invoiceTitle,
      status: status ?? this.status,
      boxIds: boxIds ?? this.boxIds,
    );
  }

  @override
  String toString() => '$invoiceTitle - $awb ($invoiceNumber)';
}
