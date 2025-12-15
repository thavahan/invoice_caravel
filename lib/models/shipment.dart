class Shipment {
  final String invoiceNumber;
  final String shipper;
  final String shipperAddress;
  final String consignee;
  final String consigneeAddress;
  final String clientRef;
  final String awb;
  final String masterAwb; // New field - Master AWB (optional)
  final String houseAwb; // New field - House AWB (optional)
  final String flightNo;
  final DateTime? flightDate; // New field - FLIGHT Date (mandatory)
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
  final double
      grossWeight; // Changed from totalAmount to grossWeight (optional)
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
    this.masterAwb = '', // New field - Master AWB (optional)
    this.houseAwb = '', // New field - House AWB (optional)
    required this.flightNo,
    required this.flightDate, // New field - FLIGHT Date (mandatory)
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
    this.grossWeight =
        0.0, // Changed from totalAmount to grossWeight (optional)
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
      masterAwb: map['master_awb'] ?? '', // New field
      houseAwb: map['house_awb'] ?? '', // New field
      flightNo: map['flight_no'] ?? '',
      flightDate: map['flight_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['flight_date'])
          : null, // New field
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
      grossWeight: (map['gross_weight'] ?? map['total_amount'] ?? 0.0)
          .toDouble(), // Support legacy total_amount field
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
      masterAwb: map['masterAwb'] ?? map['master_awb'] ?? '', // New field
      houseAwb: map['houseAwb'] ?? map['house_awb'] ?? '', // New field
      flightNo: map['flight_no'] ?? '',
      flightDate: map['flight_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['flight_date'])
          : null, // New field
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
      grossWeight: (map['gross_weight'] ?? map['total_amount'] ?? 0.0)
          .toDouble(), // Support legacy total_amount
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
      'master_awb': masterAwb, // New field
      'house_awb': houseAwb, // New field
      'flight_no': flightNo,
      'flight_date': flightDate?.millisecondsSinceEpoch, // New field
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
      'gross_weight': grossWeight, // Changed from total_amount
      'invoice_title': invoiceTitle,
      'status': status,
    };
  }

  /// Convert to Firebase format
  Map<String, dynamic> toFirebase() {
    return {
      'invoiceNumber': invoiceNumber,
      'shipper': shipper,
      'shipperAddress': shipperAddress,
      'consignee': consignee,
      'consigneeAddress': consigneeAddress,
      'clientRef': clientRef,
      'awb': awb,
      'masterAwb': masterAwb,
      'houseAwb': houseAwb,
      'flightNo': flightNo,
      'flightDate': flightDate?.millisecondsSinceEpoch,
      'dischargeAirport': dischargeAirport,
      'origin': origin,
      'destination': destination,
      'eta': eta.millisecondsSinceEpoch,
      'invoiceDate': invoiceDate?.millisecondsSinceEpoch,
      'dateOfIssue': dateOfIssue?.millisecondsSinceEpoch,
      'placeOfReceipt': placeOfReceipt,
      'sgstNo': sgstNo,
      'iecCode': iecCode,
      'freightTerms': freightTerms,
      'grossWeight': grossWeight,
      'invoiceTitle': invoiceTitle,
      'status': status,
      'boxIds': boxIds,
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
      masterAwb: map['masterAwb'] ?? map['master_awb'] ?? '', // New field
      houseAwb: map['houseAwb'] ?? map['house_awb'] ?? '', // New field
      flightNo: map['flightNo'] ?? map['flight_no'] ?? '',
      flightDate: map['flightDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['flightDate'])
          : (map['flight_date'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['flight_date'])
              : null), // New field
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
      grossWeight: (map['grossWeight'] ??
              map['gross_weight'] ??
              map['totalAmount'] ??
              map['total_amount'] ??
              0.0)
          .toDouble(), // Support legacy fields
      invoiceTitle: map['invoiceTitle'] ?? map['invoice_title'] ?? '',
      status: map['status'] ?? 'pending',
      boxIds: List<String>.from(map['boxIds'] ?? map['box_ids'] ?? []),
    );
  }

  /// Legacy method for Firebase compatibility
  Map<String, dynamic> toMap() {
    return {
      'shipper': shipper,
      'shipperAddress': shipperAddress,
      'consignee': consignee,
      'consigneeAddress': consigneeAddress,
      'clientRef': clientRef,
      'awb': awb,
      'masterAwb': masterAwb,
      'houseAwb': houseAwb,
      'flightNo': flightNo,
      'flightDate': flightDate?.millisecondsSinceEpoch,
      'dischargeAirport': dischargeAirport,
      'origin': origin,
      'destination': destination,
      'eta': eta.millisecondsSinceEpoch,
      'invoiceDate': invoiceDate?.millisecondsSinceEpoch,
      'dateOfIssue': dateOfIssue?.millisecondsSinceEpoch,
      'placeOfReceipt': placeOfReceipt,
      'sgstNo': sgstNo,
      'iecCode': iecCode,
      'freightTerms': freightTerms,
      'grossWeight': grossWeight,
      'invoiceTitle': invoiceTitle,
      'status': status,
      'boxIds': boxIds,
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
    String? masterAwb, // New field
    String? houseAwb, // New field
    String? flightNo,
    DateTime? flightDate, // New field
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
    double? grossWeight, // Changed from totalAmount
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
      masterAwb: masterAwb ?? this.masterAwb, // New field
      houseAwb: houseAwb ?? this.houseAwb, // New field
      flightNo: flightNo ?? this.flightNo,
      flightDate: flightDate ?? this.flightDate, // New field
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
      grossWeight: grossWeight ?? this.grossWeight, // Changed from totalAmount
      invoiceTitle: invoiceTitle ?? this.invoiceTitle,
      status: status ?? this.status,
      boxIds: boxIds ?? this.boxIds,
    );
  }

  // Backward compatibility getter for totalAmount
  double get totalAmount => grossWeight;

  @override
  String toString() => '$invoiceTitle - $awb ($invoiceNumber)';
}
