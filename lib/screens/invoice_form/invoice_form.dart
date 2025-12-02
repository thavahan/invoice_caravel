import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:invoice_generator/models/shipment.dart';
import 'package:invoice_generator/models/shipment_box.dart';
import 'package:invoice_generator/models/shipment_product.dart';
import 'package:invoice_generator/providers/invoice_provider.dart';
import 'package:invoice_generator/services/data_service.dart';
import 'package:invoice_generator/services/local_database_service.dart';
import 'package:provider/provider.dart';

class InvoiceForm extends StatefulWidget {
  final Map<String, dynamic>? draftData;

  const InvoiceForm({Key? key, this.draftData}) : super(key: key);

  @override
  _InvoiceFormState createState() => _InvoiceFormState();
}

class _InvoiceFormState extends State<InvoiceForm>
    with TickerProviderStateMixin {
  // Form Controllers
  final TextEditingController _bonus_controller = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _invoiceNumberController =
      TextEditingController();
  final TextEditingController _invoiceTitleController = TextEditingController();
  final TextEditingController _shipperController = TextEditingController();
  final TextEditingController _consigneeController = TextEditingController();
  final TextEditingController _awbController = TextEditingController();
  final TextEditingController _flightNoController = TextEditingController();
  final TextEditingController _dischargeAirportController =
      TextEditingController();
  final TextEditingController _etaController = TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  // New field controllers for additional shipment data
  final TextEditingController _shipperAddressController =
      TextEditingController();
  final TextEditingController _consigneeAddressController =
      TextEditingController();
  final TextEditingController _clientRefController = TextEditingController();
  final TextEditingController _invoiceDateController = TextEditingController();
  final TextEditingController _dateOfIssueController = TextEditingController();
  final TextEditingController _placeOfReceiptController =
      TextEditingController();
  final TextEditingController _sgstNoController = TextEditingController();
  final TextEditingController _iecCodeController = TextEditingController();
  // final TextEditingController _freightTermsController = TextEditingController(); // No longer used

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Local database service and draft management
  final LocalDatabaseService _localDbService = LocalDatabaseService();
  String? currentDraftId;
  bool _isSaving = false;

  // Original invoice number for updates (separate from current form value)
  String? originalInvoiceNumber;

  // Step Management
  int currentStep = 0;
  PageController _pageController = PageController();

  // Form State
  bool isFormModified = false;
  Map<int, bool> stepValidation = {0: false, 1: false, 2: false};
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Card Expansion States
  bool isBasicInfoExpanded = true;
  bool isFlightDetailsExpanded = false;
  bool isItemsExpanded = false;
  bool isPricingExpanded = false;

  // Box and Item Management
  List<ShipmentBox> shipmentBoxes = [];

  // Simple shipment summary visibility
  bool showShipmentSummary = true;

  // Currently editing box/item
  int? selectedBoxIndex;
  bool isAddingNewBox = false;
  bool isAddingNewProduct = false;

  // Removed animation trigger as summary is always visible

  // Box form controllers
  final TextEditingController _boxNumberController = TextEditingController();
  final TextEditingController _boxDescriptionController =
      TextEditingController();
  final TextEditingController _boxLengthController = TextEditingController();
  final TextEditingController _boxWidthController = TextEditingController();
  final TextEditingController _boxHeightController = TextEditingController();

  // Product form controllers
  final TextEditingController _productTypeController = TextEditingController();
  final TextEditingController _itemWeightController = TextEditingController();
  final TextEditingController _itemRateController = TextEditingController();
  final TextEditingController _flowerTypeController =
      TextEditingController(text: 'LOOSE FLOWERS');
  final TextEditingController _approxQuantityController =
      TextEditingController();

  // Scroll controller for the Items & Pricing step so we can programmatically scroll
  // to top when showing the product form dialog.
  final ScrollController _itemsScrollController = ScrollController();

  // Auto-complete suggestions
  List<String> productTypeSuggestions = [
    'Electronics',
    'Clothing & Textiles',
    'Food & Beverages',
    'Machinery & Equipment',
    'Chemicals & Pharmaceuticals',
    'Automotive Parts',
    'Books & Documents',
    'Furniture & Home Decor',
    'Toys & Games',
    'Medical Equipment',
    'Jewelry & Accessories',
    'Sports Equipment',
    'Agricultural Products',
    'Raw Materials',
    'Other'
  ];

  // Dynamic suggestions from existing shipments
  List<String> originSuggestions = [];
  List<String> destinationSuggestions = [];
  List<String> clientRefSuggestions = [];
  List<String> placeOfReceiptSuggestions = [];
  List<String> gstNumberSuggestions = [];
  List<String> iecCodeSuggestions = [];
  List<String> flightNumberSuggestions = [];
  List<String> dischargeAirportSuggestions = [];

  // Master data for dropdowns
  List<Map<String, dynamic>> masterShippers = [];
  List<Map<String, dynamic>> masterConsignees = [];
  List<Map<String, dynamic>> masterProductTypes = [];
  List<Map<String, dynamic>> masterFlowerTypes = [];
  String? selectedShipperId;
  String? selectedConsigneeId;
  String? selectedProductTypeId;

  // Product form state
  String? selectedFlowerType;
  bool hasStems = false; // Default to No

  // Base approx quantity from product type for calculation
  int? baseApproxQuantity;

  // Freight terms state
  String? selectedFreightTerms;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only load initial data if this is a NEW form (not editing existing data)
      if (widget.draftData == null) {
        // Auto-generate invoice number and date for new forms
        _initializeNewForm();

        // For new forms, skip the heavy autosync and load master data directly from local DB (fast)
        debugPrint(
            '🔄 INVOICE_FORM: Loading master data for new form (skipping autosync)');
        _loadMasterDataFromLocal().then((_) {
          // Load autocomplete suggestions
          _loadAutocompleteSuggestions();
        }).catchError((e) {
          debugPrint('⚠️ INVOICE_FORM: Error loading local master data: $e');
          // Fallback to full data load if local fails
          final invoiceProvider =
              Provider.of<InvoiceProvider>(context, listen: false);
          invoiceProvider.loadInitialData().then((_) {
            _loadMasterData();
            _loadAutocompleteSuggestions();
          });
        });
      } else {
        // For editing mode, load minimal master data from local cache only
        _loadMasterDataFromLocal().then((_) {
          // Initialize from draft data AFTER master data is loaded
          if (widget.draftData != null) {
            debugPrint(
                '🔄 Starting draft initialization after master data load');
            _initializeFromDraft(widget.draftData!);
          }
        });
      }

      // Initialize from draft data if provided (for new forms)
      if (widget.draftData != null && widget.draftData!.isEmpty) {
        // This handles empty draft data case
        _initializeFromDraft(widget.draftData!);
      }
    });
    _bonus_controller.text = '0';
    _approxQuantityController.value = const TextEditingValue(
      text: '0',
      selection: TextSelection.collapsed(offset: 1),
    ); // Initialize approx quantity to 0

    // Initialize freight terms to "Pre Paid" as default
    selectedFreightTerms = 'Pre Paid';

    // Add listeners for form validation
    _invoiceTitleController.addListener(_validateCurrentStep);
    _shipperController.addListener(_validateCurrentStep);
    _consigneeController.addListener(_validateCurrentStep);

    // Add listeners to update dropdown selections when names change
    _shipperController.addListener(_updateSelectedIdsFromNames);
    _consigneeController.addListener(_updateSelectedIdsFromNames);
  }

  @override
  void dispose() {
    // Dispose controllers to avoid memory leaks
    try {
      _itemsScrollController.dispose();
    } catch (_) {}
    _bonus_controller.dispose();
    _typeController.dispose();
    _invoiceNumberController.dispose();
    _invoiceTitleController.dispose();
    _shipperController.dispose();
    _consigneeController.dispose();
    _awbController.dispose();
    _flightNoController.dispose();
    _dischargeAirportController.dispose();
    _etaController.dispose();
    _totalAmountController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _shipperAddressController.dispose();
    _consigneeAddressController.dispose();
    _clientRefController.dispose();
    _invoiceDateController.dispose();
    _dateOfIssueController.dispose();
    _placeOfReceiptController.dispose();
    _sgstNoController.dispose();
    _iecCodeController.dispose();
    _boxNumberController.dispose();
    _boxDescriptionController.dispose();
    _boxLengthController.dispose();
    _boxWidthController.dispose();
    _boxHeightController.dispose();
    _productTypeController.dispose();
    _itemWeightController.dispose();
    _itemRateController.dispose();
    _flowerTypeController.dispose();
    _approxQuantityController.dispose();
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Initialize new form with auto-generated invoice number and date
  Future<void> _initializeNewForm() async {
    try {
      debugPrint('🔄 Initializing new form with auto-generated values...');

      // Auto-generate invoice number
      final dataService = DataService();
      final nextInvoiceNumber = await dataService.getNextInvoiceNumber();
      _invoiceNumberController.text = nextInvoiceNumber;
      debugPrint('🔄 Auto-generated invoice number: $nextInvoiceNumber');

      // Auto-generate AWB number
      final nextAwbNumber = await dataService.getNextAwbNumber();
      _awbController.text = nextAwbNumber;
      debugPrint('🔄 Auto-generated AWB number: $nextAwbNumber');

      // Auto-populate invoice date with today's date
      final today = DateTime.now();
      final formattedDate =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      _invoiceDateController.text = formattedDate;
      debugPrint('🔄 Auto-populated invoice date: $formattedDate');
    } catch (e) {
      debugPrint('❌ Error initializing new form: $e');
      // Fallback values if auto-generation fails
      _invoiceNumberController.text =
          'KS${DateTime.now().millisecondsSinceEpoch.toString().substring(8, 12)}';
      _awbController.text =
          'AWB${DateTime.now().millisecondsSinceEpoch.toString().substring(8, 11)}';
      final today = DateTime.now();
      _invoiceDateController.text =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    }
  }

  // Load autocomplete suggestions from existing shipments
  Future<void> _loadAutocompleteSuggestions() async {
    try {
      debugPrint(
          '🔄 Loading autocomplete suggestions from existing shipments...');

      final localService = LocalDatabaseService();
      await localService.initialize();

      // Get all shipments from local database
      final shipments = await localService.getShipments();

      // Extract unique values for each field
      final origins = <String>{};
      final destinations = <String>{};
      final clientRefs = <String>{};
      final placesOfReceipt = <String>{};
      final gstNumbers = <String>{};
      final iecCodes = <String>{};
      final flightNumbers = <String>{};
      final dischargeAirports = <String>{};

      for (final shipment in shipments) {
        if (shipment.origin.isNotEmpty) {
          origins.add(shipment.origin);
        }
        if (shipment.destination.isNotEmpty) {
          destinations.add(shipment.destination);
        }
        if (shipment.clientRef.isNotEmpty) {
          clientRefs.add(shipment.clientRef);
        }
        if (shipment.placeOfReceipt.isNotEmpty) {
          placesOfReceipt.add(shipment.placeOfReceipt);
        }
        if (shipment.sgstNo.isNotEmpty) {
          gstNumbers.add(shipment.sgstNo);
        }
        if (shipment.iecCode.isNotEmpty) {
          iecCodes.add(shipment.iecCode);
        }
        if (shipment.flightNo.isNotEmpty) {
          flightNumbers.add(shipment.flightNo);
        }
        if (shipment.dischargeAirport.isNotEmpty) {
          dischargeAirports.add(shipment.dischargeAirport);
        }
      }

      // Update suggestion lists (only if widget still mounted)
      if (mounted) {
        setState(() {
          originSuggestions = origins.toList()..sort();
          destinationSuggestions = destinations.toList()..sort();
          clientRefSuggestions = clientRefs.toList()..sort();
          placeOfReceiptSuggestions = placesOfReceipt.toList()..sort();
          gstNumberSuggestions = gstNumbers.toList()..sort();
          iecCodeSuggestions = iecCodes.toList()..sort();
          flightNumberSuggestions = flightNumbers.toList()..sort();
          dischargeAirportSuggestions = dischargeAirports.toList()..sort();
        });
      }

      debugPrint('🔄 Loaded suggestions:');
      debugPrint('   - Origins: ${originSuggestions.length}');
      debugPrint('   - Destinations: ${destinationSuggestions.length}');
      debugPrint('   - Client Refs: ${clientRefSuggestions.length}');
      debugPrint('   - Places of Receipt: ${placeOfReceiptSuggestions.length}');
      debugPrint('   - GST Numbers: ${gstNumberSuggestions.length}');
      debugPrint('   - IEC Codes: ${iecCodeSuggestions.length}');
      debugPrint('   - Flight Numbers: ${flightNumberSuggestions.length}');
      debugPrint(
          '   - Discharge Airports: ${dischargeAirportSuggestions.length}');
    } catch (e) {
      debugPrint('❌ Error loading autocomplete suggestions: $e');
      // Continue with empty suggestions if loading fails
    }
  }

  // Load master data for dropdowns
  Future<void> _loadMasterData() async {
    try {
      debugPrint('🔧 INVOICE_FORM: Starting to load master data...');

      final dataService = DataService();
      final shippers = await dataService.getMasterShippers();
      final consignees = await dataService.getMasterConsignees();
      final productTypes = await dataService.getMasterProductTypes();
      final flowerTypes = await dataService.getFlowerTypes();

      debugPrint('🔧 INVOICE_FORM: Loaded ${shippers.length} shippers');
      debugPrint('🔧 INVOICE_FORM: Loaded ${consignees.length} consignees');
      debugPrint(
          '🔧 INVOICE_FORM: Loaded ${productTypes.length} product types');
      debugPrint('🔧 INVOICE_FORM: Loaded ${flowerTypes.length} flower types');

      if (mounted) {
        setState(() {
          // Convert dynamic lists to expected format
          masterShippers = shippers
              .map((item) {
                if (item is Map<String, dynamic>) {
                  return item;
                } else {
                  // Handle MasterShipper object
                  return {
                    'id': item.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    'name': item.name ?? 'Unknown Shipper',
                    'address': item.address ?? '',
                  };
                }
              })
              .toList()
              .cast<Map<String, dynamic>>();

          masterConsignees = consignees
              .map((item) {
                if (item is Map<String, dynamic>) {
                  return item;
                } else {
                  // Handle MasterConsignee object
                  return {
                    'id': item.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    'name': item.name ?? 'Unknown Consignee',
                    'address': item.address ?? '',
                  };
                }
              })
              .toList()
              .cast<Map<String, dynamic>>();

          masterProductTypes = productTypes
              .map((item) {
                if (item is Map<String, dynamic>) {
                  return item;
                } else {
                  // Handle MasterProductType object
                  return {
                    'id': item.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    'name': item.name ?? 'Unknown Product Type',
                    'approx_quantity':
                        item.approxQuantity ?? 1, // Use database field name
                  };
                }
              })
              .toList()
              .cast<Map<String, dynamic>>();

          masterFlowerTypes = flowerTypes
              .map((item) {
                if (item is Map<String, dynamic>) {
                  return item;
                } else {
                  // Handle FlowerType object
                  return {
                    'id': item.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    'flower_name': item.flowerName ?? 'Unknown Flower Type',
                    'description': item.description ?? '',
                  };
                }
              })
              .toList()
              .cast<Map<String, dynamic>>();

          debugPrint('🔧 INVOICE_FORM: Master Product Types with details:');
          for (final productType in masterProductTypes) {
            debugPrint(
                '   - ID: ${productType['id']}, Name: ${productType['name']}, ApproxQty: ${productType['approx_quantity']}');
          }

          debugPrint('🔧 INVOICE_FORM: Master Flower Types with details:');
          for (final flowerType in masterFlowerTypes) {
            debugPrint(
                '   - ID: ${flowerType['id']}, Name: ${flowerType['flower_name']}');
          }
        });

        debugPrint('🔧 INVOICE_FORM: Master data loaded successfully');
        debugPrint(
            '🔧 INVOICE_FORM: Shippers: ${masterShippers.map((s) => s['name']).join(', ')}');
        debugPrint(
            '🔧 INVOICE_FORM: Consignees: ${masterConsignees.map((c) => c['name']).join(', ')}');
        debugPrint(
            '🔧 INVOICE_FORM: Product Types: ${masterProductTypes.map((p) => p['name']).join(', ')}');
        debugPrint(
            '🔧 INVOICE_FORM: Flower Types: ${masterFlowerTypes.map((f) => f['flower_name']).join(', ')}');

        // Update selected IDs based on current controller values after master data loads
        _updateSelectedIdsFromNames();
      }
    } catch (e) {
      debugPrint('❌ INVOICE_FORM: Error loading master data: $e');
      // Provide empty lists as fallback
      if (mounted) {
        setState(() {
          masterShippers = [];
          masterConsignees = [];
          masterProductTypes = [];
          masterFlowerTypes = [];
        });
      }
    }
  }

  // Load master data from local database only (for editing mode - faster)
  Future<void> _loadMasterDataFromLocal() async {
    try {
      debugPrint(
          '⚡ INVOICE_FORM: Loading master data from local database only...');

      final localService = LocalDatabaseService();
      await localService.initialize();

      final shippers = await localService.getMasterShippers();
      final consignees = await localService.getMasterConsignees();
      final productTypes = await localService.getMasterProductTypes();
      final flowerTypes = await localService.getFlowerTypes();

      debugPrint(
          '⚡ INVOICE_FORM: Loaded ${shippers.length} shippers from local');
      debugPrint(
          '⚡ INVOICE_FORM: Loaded ${consignees.length} consignees from local');
      debugPrint(
          '⚡ INVOICE_FORM: Loaded ${productTypes.length} product types from local');
      debugPrint(
          '⚡ INVOICE_FORM: Loaded ${flowerTypes.length} flower types from local');

      if (mounted) {
        setState(() {
          // Convert model objects to Map format for UI
          masterShippers = shippers
              .map((shipper) => {
                    'id': shipper.id,
                    'name': shipper.name,
                    'address': shipper.address,
                  })
              .toList();

          masterConsignees = consignees
              .map((consignee) => {
                    'id': consignee.id,
                    'name': consignee.name,
                    'address': consignee.address,
                  })
              .toList();

          masterProductTypes = productTypes
              .map((productType) => {
                    'id': productType.id,
                    'name': productType.name,
                    'approx_quantity':
                        productType.approxQuantity, // Use database field name
                  })
              .toList();

          masterFlowerTypes = flowerTypes
              .map((flowerType) => {
                    'id': flowerType.id,
                    'flower_name': flowerType.flowerName,
                    'description': flowerType.description,
                  })
              .toList();
        });

        debugPrint('⚡ INVOICE_FORM: Local master data loaded successfully');
        debugPrint(
            '⚡ INVOICE_FORM: Shippers: ${masterShippers.map((s) => s['name']).join(', ')}');
        debugPrint(
            '⚡ INVOICE_FORM: Consignees: ${masterConsignees.map((c) => c['name']).join(', ')}');
        debugPrint(
            '⚡ INVOICE_FORM: Product Types: ${masterProductTypes.map((p) => p['name']).join(', ')}');
        debugPrint(
            '⚡ INVOICE_FORM: Flower Types: ${masterFlowerTypes.map((f) => f['flower_name']).join(', ')}');

        // Update selected IDs based on current controller values after master data loads
        _updateSelectedIdsFromNames();
      }
    } catch (e) {
      debugPrint('❌ INVOICE_FORM: Error loading local master data: $e');
      // Provide empty lists as fallback
      if (mounted) {
        setState(() {
          masterShippers = [];
          masterConsignees = [];
          masterProductTypes = [];
          masterFlowerTypes = [];
        });
      }
    }
  }

  void _validateCurrentStep() {
    setState(() {
      isFormModified = true;
      switch (currentStep) {
        case 0:
          stepValidation[0] = _invoiceNumberController.text.isNotEmpty &&
              _invoiceTitleController.text.isNotEmpty &&
              _shipperController.text.isNotEmpty &&
              _consigneeController.text.isNotEmpty;
          break;
        case 1:
          stepValidation[1] = _awbController.text.isNotEmpty &&
              _flightNoController.text.isNotEmpty &&
              _dischargeAirportController.text.isNotEmpty;
          break;
        case 2:
          stepValidation[2] = _totalAmountController.text.isNotEmpty;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        '🎨 BUILD: InvoiceForm build called - shipmentBoxes.length: ${shipmentBoxes.length}');

    return Consumer<InvoiceProvider>(
      builder: (context, invoiceProvider, child) {
        if (invoiceProvider.error != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(invoiceProvider.error!)),
            );
          });
        }

        if (invoiceProvider.isLoading) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (invoiceProvider.isBusy) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
          );
        }

        if (invoiceProvider.selectedItem != null) {
          _typeController.text =
              '${invoiceProvider.selectedItem!.form} - ${invoiceProvider.selectedItem!.weightKg}kg    |    Qty: ${invoiceProvider.selectedItem!.quantity}';
        }

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                // Modern Header with Progress
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.surface,
                        Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withOpacity(0.3),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).shadowColor.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header Row
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: Icon(Icons.arrow_back,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface),
                                onPressed: () => Navigator.pop(context, true),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.draftData != null
                                        ? 'Update Shipment'
                                        : 'New Shipment',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Step ${currentStep + 1} of 3',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: Icon(Icons.save_outlined,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface),
                                onPressed: _saveDraft,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Progress Indicator
                      _buildProgressIndicator(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                // Content Area with PageView wrapped in a Form so validators run
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          currentStep = index;
                        });
                      },
                      children: [
                        _buildBasicInfoStep(invoiceProvider),
                        _buildFlightDetailsStep(invoiceProvider),
                        _buildItemsAndPricingStep(invoiceProvider),
                      ],
                    ),
                  ),
                ),

                // Navigation Footer
                _buildNavigationFooter(invoiceProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  // Progress Indicator
  Widget _buildProgressIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(3, (index) {
          bool isCompleted = stepValidation[index] == true;
          bool isCurrent = currentStep == index;

          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isCompleted
                    ? Colors.green[600] // Use green for completed steps
                    : isCurrent
                        ? Theme.of(context)
                            .colorScheme
                            .primary // Use primary color for current step
                        : Theme.of(context).colorScheme.onSurface.withOpacity(
                            0.2), // Use muted surface color for incomplete steps
              ),
            ),
          );
        }),
      ),
    );
  }

  // Step 1: Basic Shipment Information
  Widget _buildBasicInfoStep(InvoiceProvider invoiceProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step Title Card
            Card(
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(0.1),
                      Theme.of(context).primaryColor.withOpacity(0.2)
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description,
                            color: Theme.of(context).primaryColor, size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Basic Shipment Information',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the essential details for your shipment',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Enhanced Input Fields
            _buildEnhancedTextField(
              controller: _invoiceNumberController,
              label: 'Invoice Number',
              hint: 'Auto-generated (KS format)',
              icon: Icons.receipt,
              textCapitalization: TextCapitalization.characters,
              validator: (value) =>
                  value?.isEmpty == true ? 'Invoice number is required' : null,
              isRequired: true,
            ),

            _buildEnhancedTextField(
              controller: _invoiceTitleController,
              label: 'Shipment Title',
              hint: 'Enter a descriptive title for this shipment',
              icon: Icons.title,
              validator: (value) =>
                  value?.isEmpty == true ? 'Title is required' : null,
              isRequired: true,
            ),

            // Shipper Dropdown
            _buildMasterDataDropdown(
              label: 'Shipper Name',
              hint: 'Select or type shipper name',
              icon: Icons.business,
              items: masterShippers,
              selectedId: selectedShipperId,
              controller: _shipperController,
              addressController: _shipperAddressController,
              onChanged: (shipperId) {
                setState(() {
                  selectedShipperId = shipperId;
                  if (shipperId != null && shipperId != 'custom') {
                    try {
                      final Map<String, dynamic> shipper = masterShippers
                          .firstWhere((s) => s['id'] == shipperId);
                      if (shipper.isNotEmpty) {
                        _shipperAddressController.text =
                            shipper['address'] ?? '';
                      }
                    } catch (e) {
                      debugPrint('Error selecting shipper: $e');
                    }
                  }
                });
              },
              isRequired: true,
            ),

            // Consignee Dropdown
            _buildMasterDataDropdown(
              label: 'Consignee Name',
              hint: 'Select or type consignee name',
              icon: Icons.person,
              items: masterConsignees,
              selectedId: selectedConsigneeId,
              controller: _consigneeController,
              addressController: _consigneeAddressController,
              onChanged: (consigneeId) {
                setState(() {
                  selectedConsigneeId = consigneeId;
                  if (consigneeId != null && consigneeId != 'custom') {
                    try {
                      final Map<String, dynamic> consignee = masterConsignees
                          .firstWhere((c) => c['id'] == consigneeId);
                      if (consignee.isNotEmpty) {
                        _consigneeAddressController.text =
                            consignee['address'] ?? '';
                      }
                    } catch (e) {
                      debugPrint('Error selecting consignee: $e');
                    }
                  }
                });
              },
              isRequired: true,
            ),

            _buildAutocompleteTextField(
              controller: _originController,
              label: 'Origin Location',
              hint: 'Where is the shipment starting from?',
              icon: Icons.flight_takeoff,
              suggestions: originSuggestions,
              textCapitalization: TextCapitalization.words,
            ),

            _buildAutocompleteTextField(
              controller: _destinationController,
              label: 'Destination Location',
              hint: 'Where is the shipment going?',
              icon: Icons.flight_land,
              suggestions: destinationSuggestions,
              textCapitalization: TextCapitalization.words,
            ),

            // Additional Shipment Details Section
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Additional Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildEnhancedTextField(
                    controller: _shipperAddressController,
                    label: 'Shipper Address',
                    hint: 'Complete address of the shipper',
                    icon: Icons.location_on,
                    textCapitalization: TextCapitalization.words,
                  ),
                  _buildEnhancedTextField(
                    controller: _consigneeAddressController,
                    label: 'Consignee Address',
                    hint: 'Complete address of the consignee',
                    icon: Icons.location_on,
                    textCapitalization: TextCapitalization.words,
                  ),
                  _buildAutocompleteTextField(
                    controller: _clientRefController,
                    label: 'Client Reference',
                    hint: 'Client reference number or code',
                    icon: Icons.tag,
                    suggestions: clientRefSuggestions,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  _buildDateOnlyField(
                    controller: _invoiceDateController,
                    label: 'Invoice Date',
                    hint: 'Auto-populated with today\'s date',
                    icon: Icons.calendar_today,
                  ),
                  _buildDateOnlyField(
                    controller: _dateOfIssueController,
                    label: 'Date of Issue',
                    hint: 'Select date of issue',
                    icon: Icons.calendar_today,
                  ),
                  _buildAutocompleteTextField(
                    controller: _placeOfReceiptController,
                    label: 'Place of Receipt',
                    hint: 'Location where goods were received',
                    icon: Icons.place,
                    suggestions: placeOfReceiptSuggestions,
                    textCapitalization: TextCapitalization.words,
                  ),
                  _buildAutocompleteTextField(
                    controller: _sgstNoController,
                    label: 'GST Number',
                    hint: 'Goods and Services Tax Number',
                    icon: Icons.confirmation_number,
                    suggestions: gstNumberSuggestions,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  _buildAutocompleteTextField(
                    controller: _iecCodeController,
                    label: 'IEC Code',
                    hint: 'Import Export Code',
                    icon: Icons.import_export,
                    suggestions: iecCodeSuggestions,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  // Freight Terms Dropdown
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String>(
                      value: selectedFreightTerms,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Freight Terms',
                        hintText: 'Select freight terms',
                        prefixIcon: Icon(Icons.local_shipping,
                            color: Theme.of(context).primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Theme.of(context).primaryColor, width: 2),
                        ),
                        filled: true,
                        fillColor:
                            Theme.of(context).inputDecorationTheme.fillColor,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem<String>(
                          value: 'Pre Paid',
                          child: Text('Pre Paid'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'Post Paid',
                          child: Text('Post Paid'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedFreightTerms = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Freight terms is required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Step 2: Flight & Logistics Details
  Widget _buildFlightDetailsStep(InvoiceProvider invoiceProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step Title Card
            Card(
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [Colors.orange[50]!, Colors.orange[100]!],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flight, color: Colors.orange[700], size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Flight & Logistics Details',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter flight and logistics information',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _buildEnhancedTextField(
              controller: _awbController,
              label: 'AWB (Air Waybill)',
              hint: 'Enter the air waybill number',
              icon: Icons.receipt_long,
              validator: (value) =>
                  value?.isEmpty == true ? 'AWB is required' : null,
              isRequired: true,
              textCapitalization: TextCapitalization.characters,
            ),

            _buildAutocompleteTextField(
              controller: _flightNoController,
              label: 'Flight Number',
              hint: 'e.g., AA101, BA215',
              icon: Icons.flight,
              suggestions: flightNumberSuggestions,
              validator: (value) =>
                  value?.isEmpty == true ? 'Flight number is required' : null,
              isRequired: true,
              textCapitalization: TextCapitalization.characters,
            ),

            _buildAutocompleteTextField(
              controller: _dischargeAirportController,
              label: 'Discharge Airport',
              hint: 'Select destination airport',
              icon: Icons.local_airport,
              suggestions: dischargeAirportSuggestions,
              validator: (value) =>
                  value?.isEmpty == true ? 'Airport is required' : null,
              isRequired: true,
              textCapitalization: TextCapitalization.characters,
            ),

            _buildDateOnlyField(
              controller: _etaController,
              label: 'Estimated Time of Arrival',
              hint: 'Select ETA date',
              icon: Icons.schedule,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Step 3: Boxes & Items Management
  Widget _buildItemsAndPricingStep(InvoiceProvider invoiceProvider) {
    return SingleChildScrollView(
      controller: _itemsScrollController,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Form Dialog
          if (isAddingNewProduct) _buildProductFormDialog(),

          // Step Title Card
          Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    Colors.green[50]!,
                    Colors.green[100]!,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.inventory, color: Colors.green[700], size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Boxes & Items Management',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage shipment boxes and items',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Animated Shipment Summary Card
          if (showShipmentSummary) _buildAnimatedShipmentSummary(),

          const SizedBox(height: 16),

          // Add New Box Button
          Container(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startAddingNewBox,
              icon: const Icon(Icons.add_box),
              label: const Text('Add New Box'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Existing Boxes List
          if (shipmentBoxes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Shipment Boxes (${shipmentBoxes.length})',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...(() {
              debugPrint(
                  '🎨 RENDER: Building ${shipmentBoxes.length} box cards');
              return shipmentBoxes.asMap().entries.map((entry) {
                int index = entry.key;
                ShipmentBox box = entry.value;
                debugPrint(
                    '🎨 Rendering box ${index}: ${box.boxNumber} with ${box.products.length} products');
                return _buildBoxCard(box, index);
              }).toList();
            })(),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'No boxes added yet. Click "Add New Box" to start adding items to your shipment.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Pricing Section
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pricing Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                _buildEnhancedTextField(
                  controller: _totalAmountController,
                  label: 'Total Amount',
                  hint: 'Enter total shipment amount',
                  icon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  validator: (value) => value?.isEmpty == true
                      ? 'Total amount is required'
                      : null,
                  isRequired: true,
                ),

                // Conclusion statement for pricing information
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pricing Summary',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total shipment value: \$${_totalAmountController.text.isEmpty ? '0.00' : _totalAmountController.text}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // Navigation Footer
  Widget _buildNavigationFooter(InvoiceProvider invoiceProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Previous Button - Only show when NOT on first step
            if (currentStep > 0)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Dismiss keyboard before navigation
                    FocusScope.of(context).unfocus();
                    if (currentStep > 0) {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
            else
              // Empty space when on first step
              const Expanded(child: SizedBox()),

            const SizedBox(width: 16),

            // Next/Complete Button - Always show
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Dismiss keyboard before navigation
                  FocusScope.of(context).unfocus();
                  if (currentStep < 2) {
                    // Go to next step
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    // Complete the form
                    await _completeForm(invoiceProvider);
                  }
                },
                icon: Icon(currentStep < 2 ? Icons.arrow_forward : Icons.check),
                label: Text(currentStep < 2 ? 'Next' : 'Complete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Enhanced Input Field Widget
  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool isRequired = false,
    Function(String)? onChanged,
    TextCapitalization textCapitalization = TextCapitalization.words,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
        onChanged: onChanged,
        textCapitalization: textCapitalization,
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: Theme.of(context).primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Theme.of(context).inputDecorationTheme.fillColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  // Master Data Dropdown Widget (Selection Only)
  Widget _buildMasterDataDropdown({
    required String label,
    required String hint,
    required IconData icon,
    required List<Map<String, dynamic>> items,
    required String? selectedId,
    required TextEditingController controller,
    required TextEditingController addressController,
    required Function(String?) onChanged,
    bool isRequired = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dropdown for master data selection only
          DropdownButtonFormField<String>(
            value: selectedId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: isRequired ? '$label *' : label,
              hintText: hint,
              prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Theme.of(context).primaryColor, width: 2),
              ),
              filled: true,
              fillColor: Theme.of(context).inputDecorationTheme.fillColor,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            ),
            items: [
              // Only existing master data items - no "Add New..." option
              ...items.map((item) => DropdownMenuItem<String>(
                    value: item['id'],
                    child: Text(item['name']),
                  )),
            ],
            onChanged: (value) {
              onChanged(value);
              if (value != null) {
                final selectedItem =
                    items.firstWhere((item) => item['id'] == value);
                controller.text = selectedItem['name'];
                addressController.text = selectedItem['address'] ?? '';
              }
            },
            validator: (value) {
              if (isRequired && (value == null || value.isEmpty)) {
                return '$label is required';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // Autocomplete TextField
  Widget _buildAutocompleteTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required List<String> suggestions,
    String? hint,
    String? Function(String?)? validator,
    bool isRequired = false,
    TextCapitalization textCapitalization = TextCapitalization.words,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Autocomplete<String>(
        initialValue: TextEditingValue(text: controller.text),
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return suggestions;
          }
          return suggestions.where((String option) {
            return option
                .toLowerCase()
                .contains(textEditingValue.text.toLowerCase());
          });
        },
        fieldViewBuilder: (BuildContext context,
            TextEditingController fieldController,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted) {
          return TextFormField(
            controller: fieldController,
            focusNode: focusNode,
            validator: validator,
            textCapitalization: textCapitalization,
            decoration: InputDecoration(
              labelText: isRequired ? '$label *' : label,
              hintText: hint,
              prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: Theme.of(context).primaryColor, width: 2),
              ),
              filled: true,
              fillColor: Theme.of(context).inputDecorationTheme.fillColor,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          );
        },
        onSelected: (selection) {
          controller.text = selection;
        },
      ),
    );
  }

  // Date Only Field (without time)
  Widget _buildDateOnlyField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
          suffixIcon: Icon(Icons.calendar_today,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: Theme.of(context).primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Theme.of(context).inputDecorationTheme.fillColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        onTap: () async {
          final DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2101),
          );
          if (pickedDate != null) {
            controller.text =
                '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
          }
        },
      ),
    );
  }

  // Helper Methods
  Future<void> _saveDraft() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Ensure database service is initialized
      await _localDbService.initialize();

      final draftData = _prepareDraftData();

      String draftId;
      if (currentDraftId != null) {
        await _localDbService.updateDraft(currentDraftId!, draftData);
        draftId = currentDraftId!;
        debugPrint('💾 Draft updated with ID: $draftId');
      } else {
        draftId = await _localDbService.saveDraft(draftData);
        debugPrint('💾 Draft saved with ID: $draftId');
      }

      if (mounted) {
        setState(() {
          currentDraftId = draftId;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Draft saved successfully')),
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving draft: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving draft: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Prepares draft data from current form state
  Map<String, dynamic> _prepareDraftData() {
    debugPrint(
        '💾 _prepareDraftData called - preparing to save ${shipmentBoxes.length} boxes');

    final boxesData = shipmentBoxes
        .map((box) => {
              'id': box.id,
              'boxNumber': box.boxNumber,
              'length': box.length,
              'width': box.width,
              'height': box.height,
              'products': box.products
                  .map((product) => {
                        'id': product.id,
                        'type': product.type,
                        'description': product.description,
                        'flowerType': product.flowerType,
                        'hasStems': product.hasStems,
                        'weight': product.weight,
                        'rate': product.rate,
                        'approxQuantity': product.approxQuantity,
                      })
                  .toList(),
            })
        .toList();

    debugPrint('💾 Boxes data to save: ${boxesData.length} boxes');
    for (int i = 0; i < boxesData.length; i++) {
      final products = boxesData[i]['products'] as List? ?? [];
      debugPrint(
          '   Box ${i + 1}: ${boxesData[i]['boxNumber']} with ${products.length} products');
    }

    return {
      'invoiceNumber': _invoiceNumberController.text,
      'invoiceTitle': _invoiceTitleController.text,
      'shipper': _shipperController.text,
      'consignee': _consigneeController.text,
      'awb': _awbController.text,
      'flightNo': _flightNoController.text,
      'dischargeAirport': _dischargeAirportController.text,
      'eta': _etaController.text,
      'totalAmount': _totalAmountController.text,
      'origin': _originController.text,
      'destination': _destinationController.text,
      'bonus': _bonus_controller.text,
      'type': _typeController.text,
      'shipperAddress': _shipperAddressController.text,
      'consigneeAddress': _consigneeAddressController.text,
      'clientRef': _clientRefController.text,
      'invoiceDate': _invoiceDateController.text,
      'dateOfIssue': _dateOfIssueController.text,
      'placeOfReceipt': _placeOfReceiptController.text,
      'sgstNo': _sgstNoController.text,
      'iecCode': _iecCodeController.text,
      'freightTerms': selectedFreightTerms,
      'boxes': boxesData,
      'currentStep': currentStep,
      'showShipmentSummary': showShipmentSummary,
      'isBasicInfoExpanded': isBasicInfoExpanded,
      'isFlightDetailsExpanded': isFlightDetailsExpanded,
      'isItemsExpanded': isItemsExpanded,
      'isPricingExpanded': isPricingExpanded,
    };
  }

  /// Initialize form fields from draft data
  void _initializeFromDraft(Map<String, dynamic> draftData) {
    debugPrint(
        '📊 _initializeFromDraft called with draft data keys: ${draftData.keys.toList()}');

    // Handle nested draft data structure - if draftData contains 'draftData' key, use that
    Map<String, dynamic> actualDraftData = draftData;
    if (draftData.containsKey('draftData') &&
        draftData['draftData'] is Map<String, dynamic>) {
      actualDraftData = draftData['draftData'] as Map<String, dynamic>;
      debugPrint('📊 Using nested draftData');
    }

    debugPrint('📊 Actual draft data keys: ${actualDraftData.keys.toList()}');
    debugPrint('📦 Boxes data in draft: ${actualDraftData['boxes']}');

    // Store the original invoice number for updates (before user can modify it)
    // Normalize to uppercase for consistency
    originalInvoiceNumber = (actualDraftData['invoiceNumber'] ??
            DateTime.now().millisecondsSinceEpoch.toString())
        .toString()
        .toUpperCase();
    debugPrint('🔄 Stored original invoice number: $originalInvoiceNumber');

    // Initialize text controllers
    // Normalize invoice number and AWB to uppercase
    _invoiceNumberController.text =
        (actualDraftData['invoiceNumber'] ?? '').toString().toUpperCase();
    _invoiceTitleController.text = actualDraftData['invoiceTitle'] ?? '';
    _shipperController.text = actualDraftData['shipper'] ?? '';
    _consigneeController.text = actualDraftData['consignee'] ?? '';
    _awbController.text =
        (actualDraftData['awb'] ?? '').toString().toUpperCase();
    _flightNoController.text = actualDraftData['flightNo'] ?? '';
    _dischargeAirportController.text =
        actualDraftData['dischargeAirport'] ?? '';
    _etaController.text = actualDraftData['eta'] ?? '';
    _totalAmountController.text = actualDraftData['totalAmount'] ?? '';
    _originController.text = actualDraftData['origin'] ?? '';
    _destinationController.text = actualDraftData['destination'] ?? '';
    _bonus_controller.text = actualDraftData['bonus'] ?? '';
    _typeController.text = actualDraftData['type'] ?? '';

    // Prevent invoice number from being the same as AWB
    if (_invoiceNumberController.text == _awbController.text &&
        _invoiceNumberController.text.isNotEmpty) {
      _invoiceNumberController.text += '-INV';
      debugPrint('🔄 Modified invoice number to avoid AWB conflict');
    }

    // Initialize new field controllers
    _shipperAddressController.text = actualDraftData['shipperAddress'] ?? '';
    _consigneeAddressController.text =
        actualDraftData['consigneeAddress'] ?? '';
    _clientRefController.text = actualDraftData['clientRef'] ?? '';
    _invoiceDateController.text = actualDraftData['invoiceDate'] ?? '';
    _dateOfIssueController.text = actualDraftData['dateOfIssue'] ?? '';
    _placeOfReceiptController.text = actualDraftData['placeOfReceipt'] ?? '';
    _sgstNoController.text = actualDraftData['sgstNo'] ?? '';
    _iecCodeController.text = actualDraftData['iecCode'] ?? '';
    // Initialize freight terms from draft, defaulting to "Pre Paid" if not set
    selectedFreightTerms = actualDraftData['freightTerms'] ?? 'Pre Paid';

    // Initialize form state
    currentStep = actualDraftData['currentStep'] ?? 0;
    showShipmentSummary = actualDraftData['showShipmentSummary'] ?? true;
    isBasicInfoExpanded = actualDraftData['isBasicInfoExpanded'] ?? true;
    isFlightDetailsExpanded =
        actualDraftData['isFlightDetailsExpanded'] ?? false;
    isItemsExpanded = actualDraftData['isItemsExpanded'] ?? false;
    isPricingExpanded = actualDraftData['isPricingExpanded'] ?? false;

    // Initialize boxes if they exist
    if (actualDraftData['boxes'] != null && actualDraftData['boxes'] is List) {
      final boxesData = actualDraftData['boxes'] as List<dynamic>;
      debugPrint('📦 Initializing ${boxesData.length} boxes from draft');

      shipmentBoxes = boxesData
          .map((boxData) {
            if (boxData is Map<String, dynamic>) {
              final products = (boxData['products'] as List<dynamic>?)
                      ?.map((productData) {
                        if (productData is Map<String, dynamic>) {
                          // Generate ID if not present to avoid Firebase errors
                          final productId = productData['id'] ??
                              DateTime.now().millisecondsSinceEpoch.toString();
                          return ShipmentProduct(
                            id: productId,
                            boxId: '', // Will be set when box is created
                            type: productData['type'] ?? '',
                            description: productData['description'] ?? '',
                            flowerType: productData['flowerType'] ?? '',
                            hasStems: productData['hasStems'] ?? false,
                            weight: productData['weight'] ?? 0.0,
                            rate: productData['rate'] ?? 0.0,
                            approxQuantity: productData['approxQuantity'] ?? 0,
                          );
                        }
                        return null;
                      })
                      .where((product) => product != null)
                      .cast<ShipmentProduct>()
                      .toList() ??
                  [];

              return ShipmentBox(
                id: boxData['id'] ?? '',
                shipmentId: originalInvoiceNumber ?? '',
                boxNumber: boxData['boxNumber'] ?? '',
                length: boxData['length'] ?? 0.0,
                width: boxData['width'] ?? 0.0,
                height: boxData['height'] ?? 0.0,
                products: products,
              );
            }
            return null;
          })
          .where((box) => box != null)
          .cast<ShipmentBox>()
          .toList();

      debugPrint('📦 Successfully initialized ${shipmentBoxes.length} boxes');
      // Renumber boxes to ensure sequential numbering
      _renumberBoxes();
    }

    // Update selected IDs based on existing shipper/consignee names from draft
    _initializeSelectedIdsFromDraft(actualDraftData);
  }

  // Initialize selected IDs for dropdowns based on existing shipper/consignee names from draft
  void _initializeSelectedIdsFromDraft(Map<String, dynamic> draftData) {
    final shipperName = draftData['shipper'] as String?;
    final consigneeName = draftData['consignee'] as String?;

    if (shipperName != null && shipperName.isNotEmpty) {
      final matchingShipper = masterShippers.firstWhere(
        (shipper) => shipper['name'] == shipperName,
        orElse: () => <String, dynamic>{},
      );
      if (matchingShipper.isNotEmpty) {
        selectedShipperId = matchingShipper['id'];
        debugPrint('🔄 Initialized selectedShipperId: $selectedShipperId');
      }
    }

    if (consigneeName != null && consigneeName.isNotEmpty) {
      final matchingConsignee = masterConsignees.firstWhere(
        (consignee) => consignee['name'] == consigneeName,
        orElse: () => <String, dynamic>{},
      );
      if (matchingConsignee.isNotEmpty) {
        selectedConsigneeId = matchingConsignee['id'];
        debugPrint('🔄 Initialized selectedConsigneeId: $selectedConsigneeId');
      }
    }
  }

  // Update selected IDs for dropdowns based on current shipper/consignee names
  // This method runs after master data is loaded and when names change during updates
  void _updateSelectedIdsFromNames() {
    final currentShipperName = _shipperController.text.trim();
    final currentConsigneeName = _consigneeController.text.trim();

    if (currentShipperName.isNotEmpty) {
      final matchingShipper = masterShippers.firstWhere(
        (shipper) => shipper['name'] == currentShipperName,
        orElse: () => <String, String>{},
      );
      if (matchingShipper.isNotEmpty) {
        selectedShipperId = matchingShipper['id'];
        debugPrint('🔄 Updated selectedShipperId: $selectedShipperId');
      } else {
        selectedShipperId = 'custom';
        debugPrint('🔄 Set selectedShipperId to custom');
      }
    } else {
      selectedShipperId = null;
    }

    if (currentConsigneeName.isNotEmpty) {
      final matchingConsignee = masterConsignees.firstWhere(
        (consignee) => consignee['name'] == currentConsigneeName,
        orElse: () => <String, String>{},
      );
      if (matchingConsignee.isNotEmpty) {
        selectedConsigneeId = matchingConsignee['id'];
        debugPrint('🔄 Updated selectedConsigneeId: $selectedConsigneeId');
      } else {
        selectedConsigneeId = 'custom';
        debugPrint('🔄 Set selectedConsigneeId to custom');
      }
    } else {
      selectedConsigneeId = null;
    }
  }

  // Box and Product Management Methods
  void _startAddingNewBox() {
    setState(() {
      // Create a new box directly with default values
      final boxNumber = 'Box No ${(shipmentBoxes.length + 1).toString()}';
      final newBox = ShipmentBox(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        shipmentId: originalInvoiceNumber ?? _invoiceNumberController.text,
        boxNumber: boxNumber,
        length: 30.0, // Default dimensions
        width: 20.0,
        height: 15.0,
        products: [],
      );
      shipmentBoxes.add(newBox);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Box added successfully')),
    );
  }

  void _deleteBox(int index) {
    setState(() {
      shipmentBoxes.removeAt(index);
      // Renumber all remaining boxes sequentially
      _renumberBoxes();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Box deleted successfully')),
    );
  }

  // Helper method to renumber all boxes sequentially
  void _renumberBoxes() {
    for (int i = 0; i < shipmentBoxes.length; i++) {
      shipmentBoxes[i] = ShipmentBox(
        id: shipmentBoxes[i].id,
        shipmentId: shipmentBoxes[i].shipmentId,
        boxNumber: 'Box No ${(i + 1).toString()}',
        length: shipmentBoxes[i].length,
        width: shipmentBoxes[i].width,
        height: shipmentBoxes[i].height,
        products: shipmentBoxes[i].products,
      );
    }
  }

  void _saveProduct() {
    // Validate inputs
    final weight = double.tryParse(_itemWeightController.text);
    final rate = double.tryParse(_itemRateController.text);
    final approxQuantity = int.tryParse(_approxQuantityController.text) ?? 0;

    if (_productTypeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a product type')),
      );
      return;
    }

    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weight')),
      );
      return;
    }

    if (rate == null || rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid rate')),
      );
      return;
    }

    if (selectedBoxIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No box selected for product')),
      );
      return;
    }

    setState(() {
      final newProduct = ShipmentProduct(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        boxId: shipmentBoxes[selectedBoxIndex!].id,
        type: _productTypeController.text,
        description: '', // No longer used
        flowerType: selectedFlowerType ?? '',
        hasStems: hasStems,
        weight: weight,
        rate: rate,
        approxQuantity: approxQuantity,
      );

      shipmentBoxes[selectedBoxIndex!].products.add(newProduct);

      // Reset form state
      isAddingNewProduct = false;
      selectedBoxIndex = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product added successfully')),
    );
  }

  void _cancelAddingProduct() {
    setState(() {
      isAddingNewProduct = false;
      selectedBoxIndex = null;
    });
  }

  Widget _buildProductFormDialog() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.green[50]!,
              Colors.green[100]!,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_shopping_cart,
                    color: Colors.green[700], size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Add New Product',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _cancelAddingProduct,
                  icon: const Icon(Icons.close),
                  color: Colors.grey[600],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Product Type Dropdown
            _buildMasterDataDropdown(
              label: 'Product Type',
              hint: 'Select product type',
              icon: Icons.category,
              items: masterProductTypes,
              selectedId: selectedProductTypeId,
              controller: _productTypeController,
              addressController:
                  TextEditingController(), // Not used for products
              onChanged: (productTypeId) {
                setState(() {
                  selectedProductTypeId = productTypeId;
                  if (productTypeId != null && productTypeId != 'custom') {
                    try {
                      final Map<String, dynamic> productType =
                          masterProductTypes
                              .firstWhere((pt) => pt['id'] == productTypeId);
                      if (productType.isNotEmpty) {
                        _productTypeController.text = productType['name'];
                        // Store the base approx quantity from master data
                        baseApproxQuantity =
                            productType['approx_quantity'] ?? 1;
                        // Set the approx quantity field to the base value
                        _approxQuantityController.text =
                            baseApproxQuantity.toString();
                      }
                    } catch (e) {
                      debugPrint('Error selecting product type: $e');
                    }
                  } else {
                    // Reset base quantity when custom is selected
                    baseApproxQuantity = null;
                  }
                });
              },
              isRequired: true,
            ),

            const SizedBox(height: 16),

            // Flower Type Dropdown (always visible, dynamic from master data)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<String>(
                value: selectedFlowerType,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Flower Type',
                  hintText: 'Select flower type',
                  prefixIcon: Icon(Icons.local_florist,
                      color: Theme.of(context).primaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Theme.of(context).primaryColor, width: 2),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
                items: masterFlowerTypes
                    .map((flowerType) => DropdownMenuItem<String>(
                          value: flowerType['flower_name'] as String,
                          child: Text(flowerType['flower_name'] as String),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedFlowerType = value;
                  });
                },
              ),
            ),

            // Has Stems Toggle
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: SwitchListTile(
                title: const Text('Has Stems?'),
                value: hasStems,
                onChanged: (value) {
                  setState(() {
                    hasStems = value;
                  });
                },
                secondary: Icon(
                  hasStems ? Icons.grass : Icons.grass_outlined,
                  color: Theme.of(context).primaryColor,
                ),
                activeColor: Theme.of(context).primaryColor,
                contentPadding: EdgeInsets.zero,
              ),
            ),

            const SizedBox(height: 16),

            // Weight and Rate Row
            Row(
              children: [
                Expanded(
                  child: _buildEnhancedTextField(
                    controller: _itemWeightController,
                    label: 'Weight (kg)',
                    hint: 'Product weight',
                    icon: Icons.scale,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    validator: (value) {
                      if (value?.isEmpty == true) return 'Required';
                      final num = double.tryParse(value!);
                      if (num == null || num <= 0) return 'Invalid';
                      return null;
                    },
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        final weight = double.tryParse(value);
                        if (weight != null && weight > 0) {
                          // Auto calculate approx quantity based on weight and base quantity from product type
                          final calculatedQuantity =
                              (weight * (baseApproxQuantity ?? 1)).round();
                          _approxQuantityController.text =
                              calculatedQuantity.toString();
                        }
                      }
                    },
                    isRequired: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildEnhancedTextField(
                    controller: _itemRateController,
                    label: 'Rate',
                    hint: 'Price per unit',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    validator: (value) {
                      if (value?.isEmpty == true) return 'Required';
                      final num = double.tryParse(value!);
                      if (num == null || num <= 0) return 'Invalid';
                      return null;
                    },
                    isRequired: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Approximate Quantity
            _buildEnhancedTextField(
              controller: _approxQuantityController,
              label: 'Approx. Quantity',
              hint: 'Approximate quantity',
              icon: Icons.format_list_numbered,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+')),
              ],
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _cancelAddingProduct,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Add Product'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoxCard(ShipmentBox box, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    box.boxNumber,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'delete':
                        _deleteBox(index);
                        break;
                      case 'add_product':
                        _startAddingProductToBox(index);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'add_product',
                      child: Text('Add Product'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete Box'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Dimensions: ${box.length} x ${box.width} x ${box.height} cm',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (box.products.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Products (${box.products.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ...box.products.map((product) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.type,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        Text(
                          '${product.weight}kg',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  void _startAddingProductToBox(int boxIndex) {
    setState(() {
      isAddingNewProduct = true;
      selectedBoxIndex = boxIndex;
      _productTypeController.clear();
      _itemWeightController.clear();
      _itemRateController.clear();
      selectedFlowerType = null;
      hasStems = false;
      _approxQuantityController.text = '0';
      // Reset base approx quantity when starting new product
      baseApproxQuantity = null;
      selectedProductTypeId = null;
    });

    // After the frame rebuilds with the product form at the top,
    // scroll the Items & Pricing step to the top so the dialog is visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (_itemsScrollController.hasClients) {
          _itemsScrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      } catch (_) {}
    });
  }

  Widget _buildAnimatedShipmentSummary() {
    return AnimatedOpacity(
      opacity: showShipmentSummary ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor.withOpacity(0.1),
                Theme.of(context).primaryColor.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.inventory,
                      color: Theme.of(context).primaryColor, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Shipment Summary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryItem(
                      'Boxes',
                      shipmentBoxes.length.toString(),
                      Icons.inventory_2,
                    ),
                  ),
                  Expanded(
                    child: _buildSummaryItem(
                      'Products',
                      shipmentBoxes
                          .fold(0, (sum, box) => sum + box.products.length)
                          .toString(),
                      Icons.category,
                    ),
                  ),
                  Expanded(
                    child: _buildSummaryItem(
                      'Total Weight',
                      '${shipmentBoxes.fold(0.0, (sum, box) => sum + box.products.fold(0.0, (productSum, product) => productSum + product.weight))}kg',
                      Icons.scale,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _completeForm(InvoiceProvider invoiceProvider) async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    try {
      // Create Shipment object
      // Normalize invoice number and AWB to uppercase for consistency
      final normalizedInvoiceNumber =
          _invoiceNumberController.text.toUpperCase().trim();
      final normalizedAwb = _awbController.text.toUpperCase().trim();

      final shipment = Shipment(
        invoiceNumber: normalizedInvoiceNumber,
        shipper: _shipperController.text,
        shipperAddress: _shipperAddressController.text,
        consignee: _consigneeController.text,
        consigneeAddress: _consigneeAddressController.text,
        clientRef: _clientRefController.text,
        awb: normalizedAwb,
        flightNo: _flightNoController.text,
        dischargeAirport: _dischargeAirportController.text,
        origin: _originController.text,
        destination: _destinationController.text,
        eta: DateTime.tryParse(_etaController.text) ??
            DateTime.now().add(Duration(days: 1)),
        invoiceDate: _invoiceDateController.text.isNotEmpty
            ? DateTime.tryParse(_invoiceDateController.text)
            : null,
        dateOfIssue: _dateOfIssueController.text.isNotEmpty
            ? DateTime.tryParse(_dateOfIssueController.text)
            : null,
        placeOfReceipt: _placeOfReceiptController.text,
        sgstNo: _sgstNoController.text,
        iecCode: _iecCodeController.text,
        freightTerms: selectedFreightTerms ?? 'Pre Paid',
        totalAmount: double.tryParse(_totalAmountController.text) ?? 0.0,
        invoiceTitle: _invoiceTitleController.text,
        status: 'pending',
      );

      // Extract boxes data
      final boxesData = shipmentBoxes
          .map((box) => {
                'id': box.id,
                'boxNumber': box.boxNumber,
                'length': box.length,
                'width': box.width,
                'height': box.height,
                'products': box.products
                    .map((product) => {
                          'id': product.id.isEmpty
                              ? DateTime.now().millisecondsSinceEpoch.toString()
                              : product.id,
                          'type': product.type,
                          'description': product.description,
                          'flowerType': product.flowerType,
                          'hasStems': product.hasStems,
                          'weight': product.weight,
                          'rate': product.rate,
                          'approxQuantity': product.approxQuantity,
                        })
                    .toList(),
              })
          .toList();

      await invoiceProvider.createShipmentWithBoxes(shipment, boxesData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shipment created successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ Error completing form: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating shipment: $e')),
        );
      }
    }
  }
}
