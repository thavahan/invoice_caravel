import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:invoice_generator/screens/invoice_form/invoice_form.dart';
import 'package:invoice_generator/screens/master_data/master_data_screen.dart';
import 'package:invoice_generator/providers/theme_provider.dart';
import 'package:invoice_generator/providers/auth_provider.dart';
import 'package:invoice_generator/providers/invoice_provider.dart';
import 'package:invoice_generator/services/local_database_service.dart';
import 'package:invoice_generator/services/data_service.dart';
import 'package:invoice_generator/services/pdf_service.dart';
import 'package:invoice_generator/widgets/branded_loading_indicator.dart';
import 'package:invoice_generator/services/excel_file_service.dart';
import 'package:invoice_generator/models/shipment.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({Key? key}) : super(key: key);

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  final LocalDatabaseService _databaseService = LocalDatabaseService();
  final DataService _dataService = DataService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _invoiceNumberController =
      TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Map<String, dynamic>> invoices = [];
  List<Map<String, dynamic>> filteredInvoices = [];
  List<Map<String, dynamic>> drafts = [];
  bool isLoading = true;
  bool isSearching = false;
  bool showAdvancedSearch = false;
  int selectedIndex = 0;
  bool _showDrafts = false;
  bool _loadingDrafts = false;
  // Provider sync listener
  InvoiceProvider? _invoiceProvider;
  bool _providerListenerAdded = false;
  bool _lastProviderSyncState = false;

  // Search filters
  DateTime? fromDate;
  DateTime? toDate;
  String selectedStatus = 'All';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);

    // Initialize data service
    _initializeDataService();

    // Load invoices after a slight delay to ensure database service is fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInvoices();
    });
  }

  Future<void> _initializeDataService() async {
    try {
      await _dataService.initialize();
    } catch (e) {
      // Handle initialization error if needed
      debugPrint('Failed to initialize data service: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Attach a listener to InvoiceProvider so we refresh the list after login-time sync
    if (!_providerListenerAdded) {
      try {
        final provider = Provider.of<InvoiceProvider>(context);
        _invoiceProvider = provider;
        _invoiceProvider?.addListener(_onProviderUpdate);
        _providerListenerAdded = true;
        _lastProviderSyncState =
            _invoiceProvider?.hasPerformedLoginSync ?? false;
      } catch (e) {
        // Provider might not be available in some contexts; ignore silently
      }
    }
  }

  @override
  void dispose() {
    if (_providerListenerAdded && _invoiceProvider != null) {
      try {
        _invoiceProvider?.removeListener(_onProviderUpdate);
      } catch (e) {
        // ignore
      }
    }
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _invoiceNumberController.dispose();
    super.dispose();
  }

  void _onProviderUpdate() {
    if (!mounted) return;
    final current = _invoiceProvider?.hasPerformedLoginSync ?? false;
    if (current != _lastProviderSyncState) {
      _lastProviderSyncState = current;
      if (current) {
        // Refresh invoices and drafts after login-time sync
        _refreshInvoices();
      }
    }
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    final invoiceNumber = _invoiceNumberController.text.toLowerCase();

    setState(() {
      filteredInvoices = invoices.where((invoice) {
        // Text search
        bool matchesTextSearch = true;
        if (query.isNotEmpty) {
          final title = (invoice['invoiceTitle'] ?? '').toLowerCase();
          final shipper = (invoice['shipper'] ?? '').toLowerCase();
          final consignee = (invoice['consignee'] ?? '').toLowerCase();
          final trackingNumber =
              (invoice['trackingNumber'] ?? '').toLowerCase();
          matchesTextSearch = title.contains(query) ||
              shipper.contains(query) ||
              consignee.contains(query) ||
              trackingNumber.contains(query);
        }

        // Invoice number search
        bool matchesInvoiceNumber = true;
        if (invoiceNumber.isNotEmpty) {
          final invoiceId = (invoice['id'] ?? '').toLowerCase();
          final invoiceTitle = (invoice['invoiceTitle'] ?? '').toLowerCase();
          final trackingNum = (invoice['trackingNumber'] ?? '').toLowerCase();
          matchesInvoiceNumber = invoiceId.contains(invoiceNumber) ||
              invoiceTitle.contains(invoiceNumber) ||
              trackingNum.contains(invoiceNumber);
        }

        // Status filter
        bool matchesStatus = true;
        if (selectedStatus != 'All') {
          final status = (invoice['status'] ?? '').toLowerCase();
          matchesStatus = status.toLowerCase() == selectedStatus.toLowerCase();
        }

        // Date filter
        bool matchesDateRange = true;
        if (fromDate != null || toDate != null) {
          if (invoice['createdAt'] != null) {
            final invoiceDate = DateTime.fromMillisecondsSinceEpoch(
                invoice['createdAt'] as int);

            if (fromDate != null && invoiceDate.isBefore(fromDate!)) {
              matchesDateRange = false;
            }
            if (toDate != null &&
                invoiceDate.isAfter(toDate!.add(const Duration(days: 1)))) {
              matchesDateRange = false;
            }
          } else {
            matchesDateRange = false;
          }
        }

        return matchesTextSearch &&
            matchesInvoiceNumber &&
            matchesStatus &&
            matchesDateRange;
      }).toList();
    });
  }

  Future<void> _loadInvoices() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Initialize database service if not already done
      await _databaseService.initialize();

      // Get shipments from SQLite and convert to compatible format
      final shipments = await _databaseService.getShipments();

      // Convert Shipment objects to maps for UI compatibility
      final results = shipments
          .map((shipment) => {
                'id': shipment.invoiceNumber,
                'invoiceTitle': shipment.invoiceTitle,
                'shipper': shipment.shipper,
                'consignee': shipment.consignee,
                'awb': shipment.awb,
                'flightNo': shipment.flightNo,
                'dischargeAirport': shipment.dischargeAirport,
                'eta': shipment.eta.millisecondsSinceEpoch,
                'total_amount': shipment.totalAmount,
                'status': shipment.status,
                'createdAt': shipment.invoiceDate?.millisecondsSinceEpoch ??
                    shipment.dateOfIssue?.millisecondsSinceEpoch ??
                    shipment.eta.millisecondsSinceEpoch,
              })
          .toList();

      print('✅ Loaded ${results.length} invoices from database');

      if (mounted) {
        setState(() {
          invoices = results;
          filteredInvoices = results;
          isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading invoices: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load invoices: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    }
  }

  /// Load drafts from Firebase
  Future<void> _loadDrafts() async {
    if (!mounted) return;

    setState(() {
      _loadingDrafts = true;
    });

    try {
      final results = await _databaseService.getDrafts();
      if (mounted) {
        setState(() {
          drafts = results;
          _loadingDrafts = false;
        });
      }
    } catch (e) {
      print('Error loading drafts: $e');
      if (mounted) {
        setState(() {
          _loadingDrafts = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load drafts: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    }
  }

  Future<void> _refreshInvoices() async {
    await _loadInvoices();
    if (_showDrafts) {
      await _loadDrafts();
    }
  }

  /// Delete a draft
  Future<void> _deleteDraft(String draftId) async {
    try {
      await _dataService.deleteDraft(draftId);
      await _loadDrafts();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete draft: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    }
  }

  /// Publish draft to shipment
  Future<void> _publishDraft(String draftId) async {
    try {
      final shipmentId = await _databaseService.publishDraft(draftId);
      await _loadDrafts();
      await _loadInvoices();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Draft published as shipment (ID: ${shipmentId.substring(0, 8)}...)'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.fixed,
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                setState(() {
                  _showDrafts = false;
                });
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish draft: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    }
  }

  /// Update shipment status
  Future<void> _updateShipmentStatus(
      String shipmentId, String newStatus) async {
    try {
      await _databaseService.updateShipmentStatus(shipmentId, newStatus);
      await _loadInvoices();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shipment status updated to $newStatus'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch InvoiceProvider to react to loading state changes
    final invoiceProvider = context.watch<InvoiceProvider>();
    final showLoading = isLoading || invoiceProvider.isLoading;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildNavigationDrawer(),
      drawerEnableOpenDragGesture: true,
      body: Stack(
        children: [
          Column(
            children: [
              // Gmail-style Header
              Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      // Top Bar with menu and search
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context).appBarTheme.backgroundColor,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context)
                                  .shadowColor
                                  .withValues(alpha: 0.1),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.menu,
                                color: Colors.grey,
                                size: 20,
                              ),
                              onPressed: () {
                                // Ensure immediate response
                                final scaffoldState = _scaffoldKey.currentState;
                                if (scaffoldState != null &&
                                    scaffoldState.hasDrawer) {
                                  scaffoldState.openDrawer();
                                } else {
                                  Scaffold.of(context).openDrawer();
                                }
                              },
                              padding: const EdgeInsets.all(6),
                              splashRadius: 16,
                              tooltip: 'Open menu',
                            ),
                            const SizedBox(width: 0),
                            // Gmail-style Search Bar
                            Expanded(
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: Theme.of(context).dividerColor,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context)
                                          .shadowColor
                                          .withValues(alpha: 0.05),
                                      spreadRadius: 1,
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: 'Search invoices',
                                    prefixIcon: const Icon(Icons.search,
                                        color: Colors.grey),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        showAdvancedSearch
                                            ? Icons.filter_list
                                            : Icons.tune,
                                        color: showAdvancedSearch
                                            ? Colors.blue
                                            : Colors.grey,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          showAdvancedSearch =
                                              !showAdvancedSearch;
                                        });
                                      },
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  onTap: () {
                                    setState(() {
                                      isSearching = true;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Gmail-style Profile Avatar
                            Container(
                              margin: const EdgeInsets.only(right: 4),
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: Colors.blue[600],
                                child: const Text(
                                  'A',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Advanced Search Panel
              if (showAdvancedSearch) _buildAdvancedSearchPanel(),
              // Content Area
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshInvoices,
                  child: _showDrafts
                      ? _buildDraftsView()
                      : filteredInvoices.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inbox_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchController.text.isNotEmpty
                                        ? 'No invoices found'
                                        : 'No Invoices',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(top: 16),
                              itemCount: filteredInvoices.length,
                              itemBuilder: (context, index) {
                                final invoice = filteredInvoices[index];
                                return _buildGmailStyleInvoiceItem(invoice);
                              },
                            ),
                ),
              ),
            ],
          ),

          // Full-screen loading overlay to make loading state obvious
          showLoading
              ? Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.25),
                    child: const Center(
                      child: BrandedLoadingWidget(),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ],
      ),
      // Context-aware Compose Button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InvoiceForm(),
            ),
          ).then((result) {
            // Refresh the appropriate list when returning
            if (result == true) {
              if (_showDrafts) {
                _loadDrafts();
              } else {
                _loadInvoices();
              }
            }
          });
        },
        icon: Icon(_showDrafts ? Icons.edit : Icons.add),
        label: Text(_showDrafts ? 'New Draft' : 'New Shipment'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      // Invoice Management Bottom Navigation
      // bottomNavigationBar: BottomNavigationBar(
      //   currentIndex: selectedIndex,
      //   onTap: (index) {
      //     setState(() {
      //       selectedIndex = index;
      //     });
      //     _handleBottomNavTap(index);
      //   },
      //   type: BottomNavigationBarType.fixed,
      //   selectedItemColor: Colors.blue,
      //   unselectedItemColor: Colors.grey,
      //   items: const [
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.dashboard),
      //       label: 'Dashboard',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.local_shipping),
      //       label: 'Shipments',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.drafts),
      //       label: 'Drafts',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.analytics),
      //       label: 'Reports',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.search),
      //       label: 'Tracking',
      //     ),
      //   ],
      // ),
    );
  }

  void _handleBottomNavTap(int index) {
    switch (index) {
      case 0:
        setState(() {
          _showDrafts = false;
        });
        _loadInvoices();
        break;
      case 1:
        setState(() {
          _showDrafts = false;
        });
        _filterByStatus(['pending', 'in transit']);
        break;
      case 2:
        setState(() {
          _showDrafts = true;
        });
        _loadDrafts();
        break;
      case 3:
        setState(() {
          _showDrafts = false;
        });
        break;
      case 4:
        setState(() {
          _showDrafts = false;
        });
        _searchController.clear();
        setState(() {
          isSearching = true;
        });
        break;
    }
  }

  void _filterByStatus(List<String> statuses) {
    setState(() {
      filteredInvoices = invoices.where((invoice) {
        final status = (invoice['status'] ?? '').toLowerCase();
        return statuses.any((s) => status.contains(s.toLowerCase()));
      }).toList();
    });
  }

  // Navigation Drawer for Invoice Management
  Widget _buildNavigationDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Invoice Manager',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Manage your logistics invoices',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.logout,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 28,
                  ),
                  tooltip: 'Logout',
                  onPressed: _handleLogout,
                ),
              ],
            ),
          ),
          _buildDrawerItem(Icons.dashboard, 'Dashboard', true),
          // _buildDrawerItem(Icons.receipt_long, 'All Invoices', false),
          // _buildDrawerItem(Icons.pending, 'Pending Shipments', false),
          // _buildDrawerItem(Icons.local_shipping, 'In Transit', false),
          // _buildDrawerItem(Icons.check_circle, 'Delivered', false),
          _buildDrawerItem(Icons.cloud_sync, 'Sync to Cloud', false),
          // const Divider(),
          _buildDrawerItem(Icons.settings_applications, 'Master Data', false),
          // _buildDrawerItem(Icons.analytics, 'Reports', false),
          // _buildDrawerItem(Icons.inventory, 'Inventory', false),
          // _buildDrawerItem(Icons.people, 'Customers', false),
          // _buildDrawerItem(Icons.location_on, 'Tracking', false),
          const Divider(),
          _buildDrawerItem(Icons.settings, 'Settings', false),
          _buildThemeToggle(),
          _buildDrawerItem(Icons.help_outline, 'Help & Support', false),
          _buildDrawerItem(Icons.info_outline, 'About', false),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final authProvider = context.read<AuthProvider>();
        await authProvider.signOut();

        if (mounted) {
          // Navigate to home route and remove all previous routes
          // AuthWrapper will automatically show login screen after signOut
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/',
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logout failed: ${e.toString()}')),
          );
        }
      }
    }
  }

  /// Unified sync to cloud operation - consolidates sync data and migrate to cloud
  Future<void> _syncToCloud() async {
    try {
      // Check connectivity first
      final dataSourceInfo = await _dataService.getDataSourceInfo();
      final isOffline = !(dataSourceInfo['isOnline'] ?? false);
      final forceOffline = dataSourceInfo['forceOffline'] ?? false;

      if (isOffline || forceOffline) {
        _showOfflineNotificationPopup(
          'Sync to Cloud',
          'Cannot sync data to cloud while offline. Please check your internet connection and try again.',
        );
        return;
      }

      // Get migration status to determine what action to take
      final status = await _invoiceProvider!.getMigrationStatus();

      if (status['hasMigrated'] == true && status['localShipmentsCount'] == 0) {
        // Already synced, show status
        _showSyncCompleteDialog(status);
      } else if (status['localShipmentsCount'] == 0) {
        // No data to sync
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No local data found to sync'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        // Data available, show confirmation
        _showSyncConfirmationDialog(status);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show offline notification popup
  void _showOfflineNotificationPopup(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Offline Mode'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'You can continue working with local data. Cloud sync will be available when you\'re back online.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show sync complete dialog
  void _showSyncCompleteDialog(Map<String, dynamic> status) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            const Text('Sync Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your data is already synced to the cloud.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'Local shipments: ${status['localShipmentsCount'] ?? 0}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    'Cloud shipments: ${status['firebaseShipmentsCount'] ?? 0}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Local shippers: ${status['localShippersCount'] ?? 0}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 12),
                  ),
                  Text(
                    'Cloud shippers: ${status['firebaseShippersCount'] ?? 0}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 12),
                  ),
                  Text(
                    'Local consignees: ${status['localConsigneesCount'] ?? 0}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 12),
                  ),
                  Text(
                    'Cloud consignees: ${status['firebaseConsigneesCount'] ?? 0}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 12),
                  ),
                  Text(
                    'Local product types: ${status['localProductTypesCount'] ?? 0}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 12),
                  ),
                  Text(
                    'Cloud product types: ${status['firebaseProductTypesCount'] ?? 0}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 12),
                  ),
                  Text(
                    'Local flower types: ${status['localFlowerTypesCount'] ?? 0}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 12),
                  ),
                  Text(
                    'Cloud flower types: ${status['firebaseFlowerTypesCount'] ?? 0}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show sync confirmation dialog
  void _showSyncConfirmationDialog(Map<String, dynamic> status) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync Data to Cloud'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Found ${status['localShipmentsCount'] ?? 0} shipments to sync'),
            const SizedBox(height: 8),
            const Text(
              'This will also sync your master data (shippers, consignees, product types) to ensure consistency across devices.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will upload your local data to the cloud for backup and synchronization.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performSyncToCloud();
            },
            child: const Text('Start Sync'),
          ),
        ],
      ),
    );
  }

  /// Perform the actual sync operation
  Future<void> _performSyncToCloud() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Syncing shipments and master data to cloud...'),
            duration: Duration(seconds: 60), // Long timeout
            backgroundColor: Colors.blue,
          ),
        );
      }

      // Perform the sync
      await _invoiceProvider!.syncToFirebase();

      // Refresh data
      await _loadInvoices();
      await _loadDrafts();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Shipments and master data synced to cloud successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDrawerItem(IconData icon, String title, bool isSelected) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor:
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      onTap: () {
        Navigator.pop(context);

        // Handle navigation based on title
        if (title == 'Master Data') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MasterDataScreen(),
            ),
          );
        } else if (title == 'Sync to Cloud') {
          _syncToCloud();
        }
        // Add other navigation handlers here as needed
      },
    );
  }

  Widget _buildThemeToggle() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return ListTile(
          leading: Icon(
            themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          title: Text(
            'Dark Theme',
            style: TextStyle(
              fontWeight: FontWeight.normal,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          trailing: Switch(
            value: themeProvider.isDarkMode,
            onChanged: (value) {
              themeProvider.toggleTheme();
            },
            activeColor: Theme.of(context).colorScheme.primary,
          ),
          onTap: () {
            themeProvider.toggleTheme();
          },
        );
      },
    );
  }

  // ========== VIEW BUILDERS ==========

  /// Build drafts view
  Widget _buildDraftsView() {
    if (_loadingDrafts) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BrandedLoadingWidget.small(),
            SizedBox(height: 16),
            Text(
              'Loading drafts...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (drafts.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.drafts_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No drafts found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your saved drafts will appear here',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 16),
      itemCount: drafts.length,
      itemBuilder: (context, index) {
        final draft = drafts[index];
        return _buildDraftItem(draft);
      },
    );
  }

  /// Build individual draft item
  Widget _buildDraftItem(Map<String, dynamic> draft) {
    final title = draft['invoiceTitle'] ?? 'Untitled Draft';
    final shipper = draft['shipper'] ?? 'No shipper';
    final consignee = draft['consignee'] ?? 'No consignee';
    final updatedAt = draft['updatedAt'];

    String timeDisplay = 'Unknown time';
    if (updatedAt != null) {
      final date = DateTime.fromMillisecondsSinceEpoch(updatedAt as int);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays > 0) {
        timeDisplay = '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        timeDisplay = '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        timeDisplay = '${diff.inMinutes}m ago';
      } else {
        timeDisplay = 'Just now';
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.orange.withValues(alpha: 0.1),
            border: Border.all(color: Colors.orange, width: 2),
          ),
          child: const Icon(Icons.drafts, color: Colors.orange, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'From: $shipper → $consignee',
              style: TextStyle(color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'Updated: $timeDisplay',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _editDraft(draft);
                break;
              case 'publish':
                _publishDraft(draft['id']);
                break;
              case 'delete':
                _showDeleteDraftDialog(draft);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit, size: 20),
                title: Text('Edit Draft'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'publish',
              child: ListTile(
                leading: Icon(Icons.publish, size: 20),
                title: Text('Publish as Shipment'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red, size: 20),
                title:
                    Text('Delete Draft', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        onTap: () => _editDraft(draft),
      ),
    );
  }

  /// Edit draft
  void _editDraft(Map<String, dynamic> draft) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceForm(draftData: draft),
      ),
    ).then((result) {
      if (result == true) {
        _loadDrafts();
      }
    });
  }

  /// Show delete draft confirmation dialog
  void _showDeleteDraftDialog(Map<String, dynamic> draft) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Draft'),
        content: Text(
            'Are you sure you want to delete "${draft['invoiceTitle'] ?? 'Untitled Draft'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteDraft(draft['id']);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Show delete shipment confirmation dialog
  void _showDeleteShipmentDialog(Map<String, dynamic> shipment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Shipment'),
        content: Text(
            'Are you sure you want to delete "${shipment['invoiceTitle'] ?? shipment['AWB'] ?? 'this shipment'}"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteShipment(shipment['id']);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Delete shipment
  Future<void> _deleteShipment(String shipmentId) async {
    try {
      await _dataService.deleteShipment(shipmentId);
      await _loadInvoices();

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shipment deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete shipment: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.fixed,
          ),
        );
      }
    }
  }

  // Gmail-style Invoice Item
  Widget _buildGmailStyleInvoiceItem(Map<String, dynamic> invoice) {
    final String title = invoice['invoiceTitle'] ?? 'Untitled Invoice';
    final String shipper = invoice['shipper'] ?? 'Unknown Shipper';
    final String consignee = invoice['consignee'] ?? 'Unknown Consignee';
    final String status = invoice['status'] ?? 'Pending';
    final String invoiceNumber =
        invoice['invoiceNumber'] ?? invoice['id'] ?? 'N/A';

    // Get screen size for responsive design
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate responsive scaling factors
    final isSmallScreen = screenWidth < 360;
    final isLargeScreen = screenWidth > 600;
    final scaleFactor = isSmallScreen ? 0.85 : (isLargeScreen ? 1.1 : 1.0);

    // Format date
    String dateStr = 'Unknown Date';
    bool isCurrentWeek = false;
    if (invoice['createdAt'] != null) {
      final date =
          DateTime.fromMillisecondsSinceEpoch(invoice['createdAt'] as int);
      final now = DateTime.now();
      final diff = now.difference(date);

      // Check if date is in current week (Monday to Sunday)
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      isCurrentWeek =
          date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
              date.isBefore(endOfWeek.add(const Duration(days: 1)));

      if (diff.inDays == 0) {
        dateStr = '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (isCurrentWeek) {
        const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        dateStr = days[date.weekday % 7];
      } else {
        dateStr =
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8 * scaleFactor),
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(8 * scaleFactor),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                width: 0.5 * scaleFactor,
              ),
            ),
            borderRadius: BorderRadius.circular(8 * scaleFactor),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.only(
              left: 8.0 * scaleFactor,
              right: 16.0 * scaleFactor,
              top: 6.0 * scaleFactor,
              bottom: 6.0 * scaleFactor,
            ),
            horizontalTitleGap: 16.0 * scaleFactor,
            leading: Container(
              width: 44 * scaleFactor,
              height: 44 * scaleFactor,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                  width: 1.5 * scaleFactor,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4 * scaleFactor,
                    offset: Offset(0, 2 * scaleFactor),
                  ),
                ],
              ),
              child: ClipOval(
                child: Container(
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(4 * scaleFactor),
                    child: Image.asset(
                      'asset/images/brand_logo.png',
                      fit: BoxFit.cover,
                      width: 36 * scaleFactor,
                      height: 36 * scaleFactor,
                    ),
                  ),
                ),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    shipper,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14 * scaleFactor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 2 * scaleFactor),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 12 * scaleFactor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 1 * scaleFactor),
                Text(
                  'To: $consignee',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11 * scaleFactor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Invoice number badge
                Container(
                  constraints: BoxConstraints(
                    minWidth: 60 * scaleFactor,
                    maxWidth: 100 * scaleFactor,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 10 * scaleFactor,
                    vertical: 5 * scaleFactor,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor.withValues(alpha: 0.9),
                        Theme.of(context).primaryColor.withValues(alpha: 0.7),
                        Theme.of(context).primaryColor.withValues(alpha: 0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8 * scaleFactor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.1),
                        blurRadius: 2 * scaleFactor,
                        offset: Offset(0, 1 * scaleFactor),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1 * scaleFactor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          '#$invoiceNumber',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9 * scaleFactor,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3 * scaleFactor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status below invoice number
                SizedBox(height: 4 * scaleFactor),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8 * scaleFactor,
                    vertical: 2 * scaleFactor,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8 * scaleFactor),
                    border: Border.all(
                      color: _getStatusColor(status).withValues(alpha: 0.3),
                      width: 1 * scaleFactor,
                    ),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 8 * scaleFactor,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            onTap: () {
              _showInvoiceDetails(context, invoice);
            },
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green;
      case 'in transit':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Icons.check_circle_outline;
      case 'in transit':
        return Icons.local_shipping_outlined;
      case 'pending':
        return Icons.schedule_outlined;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  void _showInvoiceDetails(BuildContext context, Map<String, dynamic> invoice) {
    // Show loading indicator while fetching detailed data
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (context, scrollController) =>
            FutureBuilder<Map<String, dynamic>>(
          future: _getDetailedInvoiceData(
              invoice['invoiceNumber'] ?? invoice['id']),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      BrandedLoadingWidget.small(),
                      SizedBox(height: 16),
                      Text('Loading invoice details...'),
                    ],
                  ),
                ),
              );
            }

            final detailedInvoice = snapshot.data ?? invoice;
            final boxes =
                detailedInvoice['boxes'] as List<Map<String, dynamic>>? ?? [];
            final calculatedTotals = _calculateInvoiceTotals(boxes);

            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  // Header with title and action buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.3),
                            width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Invoice Preview',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                detailedInvoice['invoiceTitle'] ??
                                    'Untitled Invoice',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Action buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Edit button
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                onPressed: () {
                                  Navigator.pop(context); // Close bottom sheet
                                  _editInvoice(detailedInvoice);
                                },
                                icon: Icon(Icons.edit,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer),
                                tooltip: 'Edit Invoice',
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Export/Print button
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                onPressed: () {
                                  _showExportOptions(context, detailedInvoice);
                                },
                                icon: Icon(Icons.print,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSecondaryContainer),
                                tooltip: 'Export/Print',
                              ),
                            ),
                            const SizedBox(width: 8),

                            // More options button
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: PopupMenuButton<String>(
                                onSelected: (value) {
                                  switch (value) {
                                    case 'status':
                                      _showStatusUpdateDialog(detailedInvoice);
                                      break;
                                    case 'delete':
                                      Navigator.pop(context);
                                      _showDeleteShipmentDialog(
                                          detailedInvoice);
                                      break;
                                  }
                                },
                                icon: Icon(Icons.more_vert,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'status',
                                    child: ListTile(
                                      leading: Icon(Icons.update, size: 20),
                                      title: Text('Update Status'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: Icon(Icons.delete,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error,
                                          size: 20),
                                      title: Text('Delete',
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error)),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Invoice details content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                      detailedInvoice['status'] ?? 'pending')
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _getStatusColor(
                                    detailedInvoice['status'] ?? 'pending'),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getStatusIcon(
                                      detailedInvoice['status'] ?? 'pending'),
                                  size: 16,
                                  color: _getStatusColor(
                                      detailedInvoice['status'] ?? 'pending'),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  (detailedInvoice['status'] ?? 'Pending')
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: _getStatusColor(
                                        detailedInvoice['status'] ?? 'pending'),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Basic Information Section
                          _buildSection(
                            'Basic Information',
                            Icons.info_outline,
                            [
                              _buildDetailRow(
                                  'Invoice Number',
                                  detailedInvoice['invoiceNumber'] ??
                                      detailedInvoice['id']),
                              _buildDetailRow('Invoice Title',
                                  detailedInvoice['invoiceTitle']),
                              _buildDetailRow(
                                  'AWB Number', detailedInvoice['awb']),
                              _buildDetailRow(
                                  'Flight Number',
                                  _getInvoiceField(detailedInvoice,
                                      ['flightNo', 'flight_no'])),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Shipping Details Section
                          _buildSection(
                            'Shipping Details',
                            Icons.local_shipping,
                            [
                              _buildDetailRow(
                                  'Shipper', detailedInvoice['shipper']),
                              _buildDetailRow(
                                  'Consignee', detailedInvoice['consignee']),
                              _buildDetailRow(
                                  'Discharge Airport',
                                  _getInvoiceField(detailedInvoice, [
                                    'dischargeAirport',
                                    'discharge_airport'
                                  ])),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Boxes and Products Section
                          if (boxes.isNotEmpty) ...[
                            _buildBoxesSection(boxes),
                            const SizedBox(height: 20),
                          ] else ...[
                            // Show message when no boxes/products are found
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                border: Border.all(color: Colors.orange[200]!),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.orange[700], size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'No Boxes & Products Found',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.orange[800],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'This invoice doesn\'t contain detailed box and product information. Add boxes and products when creating or editing the invoice.',
                                          style: TextStyle(
                                            color: Colors.orange[700],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Financial Information Section
                          _buildSection(
                            'Financial Information',
                            Icons.attach_money,
                            [
                              _buildDetailRow('Subtotal',
                                  '\$${(calculatedTotals['subtotal'] ?? 0.0).toStringAsFixed(2)}'),
                              if ((calculatedTotals['tax'] ?? 0.0) > 0)
                                _buildDetailRow('Tax',
                                    '\$${(calculatedTotals['tax'] ?? 0.0).toStringAsFixed(2)}'),
                              if ((calculatedTotals['discount'] ?? 0.0) > 0)
                                _buildDetailRow('Discount',
                                    '-\$${(calculatedTotals['discount'] ?? 0.0).toStringAsFixed(2)}'),
                              const Divider(),
                              _buildDetailRow(
                                'Total Amount',
                                '\$${(calculatedTotals['total'] ?? 0.0).toStringAsFixed(2)}',
                                isTotal: true,
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Dates Section
                          _buildSection(
                            'Important Dates',
                            Icons.calendar_today,
                            [
                              _buildDetailRow(
                                  'ETA',
                                  detailedInvoice['eta'] != null
                                      ? _formatDate(
                                          DateTime.fromMillisecondsSinceEpoch(
                                              detailedInvoice['eta'] as int))
                                      : 'N/A'),
                              _buildDetailRow(
                                  'Created Date',
                                  detailedInvoice['createdAt'] != null
                                      ? _formatDate(
                                          DateTime.fromMillisecondsSinceEpoch(
                                              detailedInvoice['createdAt']
                                                  as int))
                                      : 'N/A'),
                            ],
                          ),

                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
                color: isTotal
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: isTotal ? 16 : 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
              style: TextStyle(
                fontSize: isTotal ? 18 : 16,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                color: isTotal
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper to prefer multiple possible keys for a field (handles snake_case and camelCase)
  String _getInvoiceField(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (map.containsKey(key)) {
        final v = map[key];
        if (v != null) {
          final s = v.toString();
          if (s.trim().isNotEmpty) return s;
        }
      }
    }
    return 'N/A';
  }

  /// Get detailed invoice data with boxes and products
  Future<Map<String, dynamic>> _getDetailedInvoiceData(String invoiceId) async {
    try {
      // First try to get from drafts (may have more detailed data)
      final drafts = await _databaseService.getDrafts();
      final matchingDraft = drafts.firstWhere(
        (draft) => draft['id'] == invoiceId,
        orElse: () => <String, dynamic>{},
      );

      if (matchingDraft.isNotEmpty && matchingDraft['draftData'] != null) {
        final draftData = matchingDraft['draftData'] as Map<String,
            dynamic>; // If draft has boxes data, convert it to the expected format
        List<Map<String, dynamic>> boxes = [];
        if (draftData['boxes'] != null) {
          final draftBoxes = draftData['boxes'] as List<dynamic>;
          boxes = draftBoxes.map((box) {
            if (box is Map<String, dynamic>) {
              return {
                'id': box['id'] ?? '',
                'boxNumber': box['boxNumber'] ?? 'Box 1',
                'length': box['length'] ?? 0.0,
                'width': box['width'] ?? 0.0,
                'height': box['height'] ?? 0.0,
                'products': box['products'] ?? [],
              };
            }
            return <String, dynamic>{};
          }).toList();
        }

        // Ensure flight and discharge airport are present in returned draft map
        final flightFromDraft = draftData['flightNo'] ??
            draftData['flight_no'] ??
            matchingDraft['flightNo'] ??
            matchingDraft['flight_no'] ??
            'N/A';

        final dischargeFromDraft = draftData['dischargeAirport'] ??
            draftData['discharge_airport'] ??
            matchingDraft['dischargeAirport'] ??
            matchingDraft['discharge_airport'] ??
            'N/A';

        debugPrint(
            '📝 DEBUG: Returning draft data with flightNo: "$flightFromDraft"');

        return {
          ...matchingDraft,
          ...draftData,
          'flightNo': flightFromDraft,
          'dischargeAirport': dischargeFromDraft,
          'boxes': boxes,
        };
      }

      // If not found in drafts, get from shipments
      final shipments = await _databaseService.getShipments();

      // Try to find shipment by different ID fields
      Shipment? matchingShipment;

      // Normalize invoiceId to lowercase for case-insensitive comparison
      final normalizedInvoiceId = invoiceId.toLowerCase();

      try {
        // First try exact invoice number match (case-insensitive)
        matchingShipment = shipments.firstWhere(
          (shipment) =>
              shipment.invoiceNumber.toLowerCase() == normalizedInvoiceId,
          orElse: () => throw Exception('Not found'),
        );
      } catch (e) {
        // If not found by invoice number, try by ID or other identifiers (case-insensitive)
        try {
          matchingShipment = shipments.firstWhere(
            (shipment) =>
                shipment.invoiceNumber
                    .toLowerCase()
                    .contains(normalizedInvoiceId) ||
                shipment.awb.toLowerCase() == normalizedInvoiceId ||
                shipment.invoiceTitle.toLowerCase() == normalizedInvoiceId,
            orElse: () => throw Exception('Not found'),
          );
        } catch (e2) {
          // If still not found, create a basic shipment from available invoice data
          print(
              '⚠️ WARNING: Creating basic shipment data for invoice: $invoiceId');

          // Return basic data structure that won't crash PDF generation
          return {
            'id': invoiceId.toString(),
            'invoiceTitle': 'Invoice',
            'shipper': 'Unknown Shipper',
            'consignee': 'Unknown Consignee',
            'awb': 'N/A',
            'flightNo': 'N/A',
            'dischargeAirport': 'N/A',
            'origin': 'N/A',
            'destination': 'N/A',
            'eta': DateTime.now().millisecondsSinceEpoch,
            'totalAmount': 0.0,
            'status': 'draft',
            'createdAt': DateTime.now().millisecondsSinceEpoch,
            'boxes': [], // Empty boxes array
          };
        }
      }

      // Get boxes and products from database (only if shipment was found)
      // Boxes are stored keyed by shipment invoice number in the DB

      // Log found shipment fields to help debugging missing flight/discharge values
      print(
          'DEBUG: Found shipment -> invoiceNumber: ${matchingShipment.invoiceNumber}, awb: ${matchingShipment.awb}, flightNo: ${matchingShipment.flightNo}, dischargeAirport: ${matchingShipment.dischargeAirport}');

      final boxesFromDb = await _dataService
          .getBoxesForShipment(matchingShipment.invoiceNumber);

      if (boxesFromDb.isEmpty) {
        print(
            'DEBUG: No boxes returned for shipment invoice ${matchingShipment.invoiceNumber} (awb=${matchingShipment.awb}).');
      }
      final boxes = <Map<String, dynamic>>[];

      for (final box in boxesFromDb) {
        final products = box.products
            .map((product) => {
                  'id': product.id,
                  'type': product.type,
                  'description': product.description,
                  'weight': product.weight,
                  'rate': product.rate,
                  'flowerType': product.flowerType,
                  'hasStems': product.hasStems,
                  'approxQuantity': product.approxQuantity,
                  'boxNumber': box.boxNumber,
                })
            .toList();

        boxes.add({
          'id': box.id,
          'boxNumber': box.boxNumber,
          'length': box.length,
          'width': box.width,
          'height': box.height,
          'products': products,
        });
      }

      // Sort boxes by box number and renumber them sequentially for correct display
      boxes.sort((a, b) {
        final aNum = _extractBoxNumber(a['boxNumber'] as String? ?? '');
        final bNum = _extractBoxNumber(b['boxNumber'] as String? ?? '');
        return aNum.compareTo(bNum);
      });

      // Renumber boxes sequentially
      for (int i = 0; i < boxes.length; i++) {
        final newBoxNumber = 'Box No ${(i + 1).toString()}';
        boxes[i]['boxNumber'] = newBoxNumber;
        // Also update boxNumber in products
        final products = boxes[i]['products'] as List<dynamic>;
        for (var product in products) {
          if (product is Map<String, dynamic>) {
            product['boxNumber'] = newBoxNumber;
          }
        }
      }

      // Convert shipment to map with loaded boxes and products
      final shipmentMap = {
        'id': matchingShipment.invoiceNumber,
        'invoiceTitle': matchingShipment.invoiceTitle,
        'shipper': matchingShipment.shipper,
        'consignee': matchingShipment.consignee,
        'awb': matchingShipment.awb,
        'flightNo': matchingShipment.flightNo,
        'dischargeAirport': matchingShipment.dischargeAirport,
        'origin': matchingShipment.origin,
        'destination': matchingShipment.destination,
        'eta': matchingShipment.eta.millisecondsSinceEpoch,
        'totalAmount': matchingShipment.totalAmount,
        'status': matchingShipment.status,
        'createdAt': matchingShipment.invoiceDate?.millisecondsSinceEpoch ??
            matchingShipment.dateOfIssue?.millisecondsSinceEpoch ??
            matchingShipment.eta.millisecondsSinceEpoch,
        // Additional fields from Shipment model
        'shipperAddress': matchingShipment.shipperAddress,
        'consigneeAddress': matchingShipment.consigneeAddress,
        'clientRef': matchingShipment.clientRef,
        'invoiceDate': matchingShipment.invoiceDate?.millisecondsSinceEpoch,
        'dateOfIssue': matchingShipment.dateOfIssue?.millisecondsSinceEpoch,
        'placeOfReceipt': matchingShipment.placeOfReceipt,
        'sgstNo': matchingShipment.sgstNo,
        'iecCode': matchingShipment.iecCode,
        'freightTerms': matchingShipment.freightTerms,
        'boxes': boxes,
      };

      debugPrint(
          '📦 DEBUG: Returning shipmentMap with flightNo: "${shipmentMap['flightNo']}"');

      return shipmentMap;
    } catch (e) {
      print('Error fetching detailed invoice data: $e');
      return {};
    }
  }

  /// Calculate invoice totals from boxes and products
  Map<String, double> _calculateInvoiceTotals(
      List<Map<String, dynamic>> boxes) {
    double subtotal = 0.0;
    double totalWeight = 0.0;
    int totalItems = 0;

    for (final box in boxes) {
      final products = box['products'] as List<dynamic>? ?? [];

      for (final product in products) {
        if (product is Map<String, dynamic>) {
          final weight = (product['weight'] as num?)?.toDouble() ?? 0.0;
          final rate = (product['rate'] as num?)?.toDouble() ?? 0.0;

          final productTotal = weight * rate;
          subtotal += productTotal;
          totalWeight += weight;
          totalItems += 1;
        }
      }
    }

    // Calculate tax (assuming 10% tax rate)
    final tax = subtotal * 0.10;

    // No discount for now
    final discount = 0.0;

    // Calculate final total
    final total = subtotal + tax - discount;

    return {
      'subtotal': subtotal,
      'tax': tax,
      'discount': discount,
      'total': total,
      'totalWeight': totalWeight,
      'totalItems': totalItems.toDouble(),
    };
  }

  /// Build boxes and products section
  Widget _buildBoxesSection(List<Map<String, dynamic>> boxes) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.inventory_2,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Boxes & Products Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${boxes.length} boxes containing ${_getTotalProducts(boxes)} items',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Tap to expand',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Boxes list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: boxes.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
            itemBuilder: (context, index) => _buildBoxItem(boxes[index], index),
          ),
        ],
      ),
    );
  }

  /// Build individual box item
  Widget _buildBoxItem(Map<String, dynamic> box, int index) {
    final products = box['products'] as List<dynamic>? ?? [];
    final boxNumber = box['boxNumber'] ?? 'Box ${index + 1}';
    final dimensions =
        box['length'] != null && box['width'] != null && box['height'] != null
            ? '${box['length']}×${box['width']}×${box['height']} cm'
            : 'No dimensions';

    double boxTotal = 0.0;
    double boxWeight = 0.0;

    for (final product in products) {
      if (product is Map<String, dynamic>) {
        final weight = (product['weight'] as num?)?.toDouble() ?? 0.0;
        final rate = (product['rate'] as num?)?.toDouble() ?? 0.0;

        boxTotal += weight * rate;
        boxWeight += weight;
      }
    }

    return ExpansionTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.inventory,
            color: Theme.of(context).colorScheme.onPrimaryContainer, size: 20),
      ),
      title: Text(
        boxNumber,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weight: ${boxWeight.toStringAsFixed(2)} kg • Value: \$${boxTotal.toStringAsFixed(2)}',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12),
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${products.length} items',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
      ),
      children: products.map<Widget>((product) {
        if (product is Map<String, dynamic>) {
          return _buildProductItem(product);
        }
        return const SizedBox.shrink();
      }).toList(),
    );
  }

  /// Build individual product item
  Widget _buildProductItem(Map<String, dynamic> product) {
    final type = product['type'] ?? 'Unknown';
    final weight = (product['weight'] as num?)?.toDouble() ?? 0.0;
    final rate = (product['rate'] as num?)?.toDouble() ?? 0.0;
    final productTotal = weight * rate;

    // Build structured product details
    final flowerType = product['flowerType'] ?? 'LOOSE FLOWERS';
    final hasStems = product['hasStems'] ?? false;
    final approxQuantity = (product['approxQuantity'] as num?)?.toInt() ?? 0;
    final stemsText = hasStems ? 'WITH STEMS' : 'NO STEMS';
    final structuredDetails =
        '($flowerType, $stemsText, APPROX $approxQuantity NOS)';

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.category,
                color: Theme.of(context).colorScheme.primary, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  structuredDetails,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${weight}kg × \$${rate.toStringAsFixed(2)} = \$${productTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${productTotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                  fontSize: 14,
                ),
              ),
              Text(
                '${weight.toStringAsFixed(1)} kg',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Get total number of products across all boxes
  int _getTotalProducts(List<Map<String, dynamic>> boxes) {
    int total = 0;
    for (final box in boxes) {
      final products = box['products'] as List<dynamic>? ?? [];
      total += products.length;
    }
    return total;
  }

  /// Build a section with title and content
  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Edit invoice by navigating to invoice form
  void _editInvoice(Map<String, dynamic> invoice) async {
    try {
      final dbService = LocalDatabaseService();
      await dbService.initialize();

      // Normalize invoice id / invoiceNumber - prefer invoiceNumber (DB uses invoice_number)
      final String shipmentId = (invoice['invoiceNumber'] ??
              invoice['id'] ??
              invoice['awb'] ??
              invoice['AWB'] ??
              '')
          .toString();

      List<Map<String, dynamic>> boxesForForm = [];

      // If the passed invoice already contains boxes (e.g., preview of a draft), use them.
      if (invoice['boxes'] != null && (invoice['boxes'] as List).isNotEmpty) {
        final rawBoxes = invoice['boxes'] as List<dynamic>;
        boxesForForm = rawBoxes.map((boxRaw) {
          if (boxRaw is Map<String, dynamic>) {
            final productsRaw = (boxRaw['products'] as List<dynamic>?) ?? [];
            final products = productsRaw.map((p) {
              // Products from draft data are already Map<String, dynamic>
              if (p is Map<String, dynamic>) {
                return p;
              }
              // Fallback for any other type
              return <String, dynamic>{};
            }).toList();

            return {
              'id': boxRaw['id'] ?? '',
              'boxNumber': boxRaw['boxNumber'] ?? 'Box',
              'length': boxRaw['length'] ?? 0.0,
              'width': boxRaw['width'] ?? 0.0,
              'height': boxRaw['height'] ?? 0.0,
              'products': products,
            };
          }
          return <String, dynamic>{};
        }).toList();
      } else {
        // Fallback: load boxes/products from local DB using shipmentId
        final boxes = await dbService.getBoxesForShipment(shipmentId);
        boxesForForm = boxes
            .map((box) => {
                  'id': box.id,
                  'boxNumber': box.boxNumber,
                  'length': box.length,
                  'width': box.width,
                  'height': box.height,
                  'products':
                      box.products.map((product) => product.toMap()).toList(),
                })
            .toList();
      }

      // Prepare invoiceData with consistent keys expected by InvoiceForm
      final invoiceData = {
        'id': shipmentId,
        'invoiceNumber': shipmentId,
        'invoiceTitle':
            invoice['invoice_title'] ?? invoice['invoiceTitle'] ?? '',
        'shipper': invoice['shipper'] ?? '',
        'consignee': invoice['consignee'] ?? '',
        'awb': invoice['awb'] ?? invoice['AWB'] ?? '',
        'flightNo': invoice['flight_no'] ?? invoice['flightNo'] ?? '',
        'dischargeAirport':
            invoice['discharge_airport'] ?? invoice['dischargeAirport'] ?? '',
        'origin': invoice['origin'] ?? '',
        'destination': invoice['destination'] ?? '',
        'eta': invoice['eta'] != null
            ? DateTime.fromMillisecondsSinceEpoch(invoice['eta'] as int)
                .toString()
                .substring(0, 16)
            : '',
        'totalAmount':
            (invoice['total_amount'] ?? invoice['totalAmount'] ?? 0.0)
                .toString(),
        'status': invoice['status'] ?? '',
        'quantity': '', // Not available in current shipment data
        'bonus': '0', // Default value
        'type': '', // Not available in current shipment data
        'trackingNumber': '', // Not available in current shipment data
        'shipperAddress': invoice['shipperAddress'] ?? '',
        'consigneeAddress': invoice['consigneeAddress'] ?? '',
        'clientRef': invoice['clientRef'] ?? '',
        'invoiceDate': invoice['invoiceDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(invoice['invoiceDate'] as int)
                .toString()
                .split(' ')[0] // Just the date part
            : '',
        'dateOfIssue': invoice['dateOfIssue'] != null
            ? DateTime.fromMillisecondsSinceEpoch(invoice['dateOfIssue'] as int)
                .toString()
                .split(' ')[0] // Just the date part
            : '',
        'placeOfReceipt': invoice['placeOfReceipt'] ?? '',
        'sgstNo': invoice['sgstNo'] ?? '',
        'iecCode': invoice['iecCode'] ?? '',
        'freightTerms': invoice['freightTerms'] ?? '',
        'currentStep': 0, // Start from first step
        'showShipmentSummary': true,
        'isBasicInfoExpanded': true,
        'isFlightDetailsExpanded': false,
        'isItemsExpanded': false,
        'isPricingExpanded': false,
        'boxes': boxesForForm,
        'productTypeSuggestions': [], // Will be loaded by form
        'airportSuggestions': [], // Will be loaded by form
        'airlineSuggestions': [], // Will be loaded by form
      };

      print('🔍 DEBUG: Full invoice data being passed to form:');
      print('🔍 DEBUG: flightNo: "${invoiceData['flightNo']}"');
      print('🔍 DEBUG: dischargeAirport: "${invoiceData['dischargeAirport']}"');
      print('🔍 DEBUG: Original invoice keys: ${invoice.keys.toList()}');
      print('🔍 DEBUG: Original invoice flight_no: "${invoice['flight_no']}"');
      print('🔍 DEBUG: Original invoice flightNo: "${invoice['flightNo']}"');
      print(
          '🔍 DEBUG: Original invoice discharge_airport: "${invoice['discharge_airport']}"');
      print(
          '🔍 DEBUG: Original invoice dischargeAirport: "${invoice['dischargeAirport']}"');

      print('🔍 DEBUG: Full invoice data being passed to form:');
      print('🔍 DEBUG: flightNo: "${invoiceData['flightNo']}"');
      print('🔍 DEBUG: dischargeAirport: "${invoiceData['dischargeAirport']}"');
      print('🔍 DEBUG: Original invoice keys: ${invoice.keys.toList()}');
      print('🔍 DEBUG: Original invoice flight_no: "${invoice['flight_no']}"');
      print('🔍 DEBUG: Original invoice flightNo: "${invoice['flightNo']}"');
      print(
          '🔍 DEBUG: Original invoice discharge_airport: "${invoice['discharge_airport']}"');
      print(
          '🔍 DEBUG: Original invoice dischargeAirport: "${invoice['dischargeAirport']}"');

      debugPrint('🚀 DEBUG: About to navigate to InvoiceForm with draftData');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InvoiceForm(draftData: invoiceData),
        ),
      ).then((result) {
        if (result == true) {
          _loadInvoices(); // Refresh the list
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load shipment data: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Show export/print options
  void _showExportOptions(BuildContext context, Map<String, dynamic> invoice) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Export Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),

            // Make the options scrollable to prevent overflow
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Export as PDF
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.picture_as_pdf,
                            color:
                                Theme.of(context).colorScheme.onErrorContainer),
                      ),
                      title: const Text('Export as PDF'),
                      subtitle: const Text('Save invoice as PDF document'),
                      onTap: () {
                        Navigator.pop(context); // Close export options
                        Navigator.pop(context); // Close invoice preview
                        _exportAsPDF(invoice);
                      },
                    ),

                    // Export as Excel
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.table_chart,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer),
                      ),
                      title: const Text('Export as Excel'),
                      subtitle: const Text('Save invoice data as spreadsheet'),
                      onTap: () {
                        Navigator.pop(context); // Close export options
                        Navigator.pop(context); // Close invoice preview
                        _exportAsExcel(invoice);
                      },
                    ),

                    // Print Invoice
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.print,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer),
                      ),
                      title: const Text('Print Invoice'),
                      subtitle: const Text('Print physical copy'),
                      onTap: () {
                        Navigator.pop(context); // Close export options
                        Navigator.pop(context); // Close invoice preview
                        _printInvoice(invoice);
                      },
                    ),

                    // Share Invoice
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.share,
                            color: Theme.of(context)
                                .colorScheme
                                .onTertiaryContainer),
                      ),
                      title: const Text('Share Invoice'),
                      subtitle: const Text('Share via email or messaging'),
                      onTap: () {
                        Navigator.pop(context); // Close export options
                        Navigator.pop(context); // Close invoice preview
                        _shareInvoice(invoice);
                      },
                    ),

                    // Email Invoice
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.email,
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                      title: const Text('Email Invoice'),
                      subtitle: const Text('Send invoice via email'),
                      onTap: () {
                        Navigator.pop(context); // Close export options
                        Navigator.pop(context); // Close invoice preview
                        _emailInvoice(invoice);
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Show status update dialog
  void _showStatusUpdateDialog(Map<String, dynamic> invoice) {
    final statuses = ['pending', 'in transit', 'delivered', 'cancelled'];
    final currentStatus = invoice['status']?.toLowerCase() ?? 'pending';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: statuses.map((status) {
            final isSelected = status == currentStatus;
            return ListTile(
              leading: Icon(
                _getStatusIcon(status),
                color: _getStatusColor(status),
              ),
              title: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? _getStatusColor(status) : null,
                ),
              ),
              trailing: isSelected ? const Icon(Icons.check) : null,
              onTap: () {
                Navigator.pop(context);
                _updateShipmentStatus(
                    invoice['invoiceNumber'] ?? invoice['id'], status);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Export invoice as PDF with save functionality
  Future<void> _exportAsPDF(Map<String, dynamic> invoice) async {
    try {
      // Show preparing message with loading indicator
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                    'Preparing PDF for "${invoice['invoiceTitle'] ?? 'Invoice'}"...'),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.fixed,
          duration: const Duration(seconds: 30),
        ),
      );

      // Validate invoice data
      if (invoice.isEmpty) {
        throw Exception('Invoice data is empty');
      }

      final invoiceId = invoice['id'] ?? invoice['invoiceNumber'];
      if (invoiceId == null) {
        throw Exception('Invoice ID not found');
      }

      // Get detailed invoice data including boxes and products
      final detailedInvoiceData = await _getDetailedInvoiceData(invoiceId);

      // Validate detailed data
      if (detailedInvoiceData.isEmpty) {
        throw Exception('Could not retrieve invoice details');
      }

      // Create shipment object for PDF generation
      final shipment = Shipment(
        invoiceNumber: (detailedInvoiceData['invoiceNumber'] ??
                detailedInvoiceData['id'] ??
                'N/A')
            .toString(),
        shipper: (detailedInvoiceData['shipper'] ?? 'N/A').toString(),
        shipperAddress:
            (detailedInvoiceData['shipperAddress'] ?? '').toString(),
        consignee: (detailedInvoiceData['consignee'] ?? 'N/A').toString(),
        consigneeAddress:
            (detailedInvoiceData['consigneeAddress'] ?? '').toString(),
        awb: (detailedInvoiceData['awb'] ?? 'N/A').toString(),
        flightNo: (detailedInvoiceData['flightNo'] ?? 'N/A').toString(),
        dischargeAirport:
            (detailedInvoiceData['dischargeAirport'] ?? 'N/A').toString(),
        eta: detailedInvoiceData['eta'] is int
            ? DateTime.fromMillisecondsSinceEpoch(detailedInvoiceData['eta'])
            : DateTime.tryParse(detailedInvoiceData['eta']?.toString() ?? '') ??
                DateTime.now(),
        totalAmount:
            (detailedInvoiceData['totalAmount'] as num?)?.toDouble() ?? 0.0,
        invoiceTitle: (invoice['invoiceTitle'] ?? 'Invoice').toString(),
        origin: (detailedInvoiceData['origin'] ?? 'N/A').toString(),
        destination: (detailedInvoiceData['destination'] ?? 'N/A').toString(),
        status: (detailedInvoiceData['status'] ?? 'draft').toString(),
        // Add missing fields for PDF population
        invoiceDate: detailedInvoiceData['invoiceDate'] is int
            ? DateTime.fromMillisecondsSinceEpoch(
                detailedInvoiceData['invoiceDate'])
            : null,
        dateOfIssue: detailedInvoiceData['dateOfIssue'] is int
            ? DateTime.fromMillisecondsSinceEpoch(
                detailedInvoiceData['dateOfIssue'])
            : null,
        placeOfReceipt:
            (detailedInvoiceData['placeOfReceipt'] ?? '').toString(),
        sgstNo: (detailedInvoiceData['sgstNo'] ?? '').toString(),
        iecCode: (detailedInvoiceData['iecCode'] ?? '').toString(),
        freightTerms: (detailedInvoiceData['freightTerms'] ?? '').toString(),
      );

      // Get items from boxes
      final List<dynamic> items = [];

      if (detailedInvoiceData['boxes'] != null) {
        for (var box in detailedInvoiceData['boxes']) {
          if (box['products'] != null) {
            items.addAll(box['products']);
          }
        }
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Directly generate PDF with preview
      await _executePdfGeneration(shipment, items);
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // More specific error handling
      String errorMessage;
      if (e.toString().contains('Invoice not found')) {
        errorMessage = 'Invoice data not found in database';
      } else if (e.toString().contains('Invoice ID not found')) {
        errorMessage = 'Invalid invoice - missing identifier';
      } else if (e.toString().contains('Invoice data is empty')) {
        errorMessage = 'Invoice data is corrupted or empty';
      } else {
        errorMessage = 'Failed to prepare PDF: ${e.toString()}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(errorMessage)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'RETRY',
            textColor: Colors.white,
            onPressed: () => _exportAsPDF(invoice),
          ),
        ),
      );
    }
  }

  /// Execute PDF generation
  Future<void> _executePdfGeneration(
      Shipment shipment, List<dynamic> items) async {
    try {
      print('🚀 PDF Generation Started');
      print(
          '🔍 Shipment: ${shipment.invoiceNumber}, Items count: ${items.length}');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Text('Generating PDF document...'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Generate PDF using PdfService
      print('📄 Calling PDF Service...');
      final pdfService = PdfService();
      await pdfService.generateShipmentPDF(shipment, items);
      print('✅ PDF Generation Completed');

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              const Text('PDF generated successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'VIEW',
            textColor: Colors.white,
            onPressed: () {
              // PDF is already shown in preview mode
            },
          ),
        ),
      );
    } catch (e, stackTrace) {
      print('❌ PDF Generation Error: $e');
      print('📍 Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Failed to generate PDF: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'RETRY',
            textColor: Colors.white,
            onPressed: () => _executePdfGeneration(shipment, items),
          ),
        ),
      );
    }
  }

  /// Print invoice
  Future<void> _printInvoice(Map<String, dynamic> invoice) async {
    try {
      // Show preparing message with loading indicator
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                    'Preparing "${invoice['invoiceTitle'] ?? 'Invoice'}" for printing...'),
              ),
            ],
          ),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.fixed,
          duration: Duration(seconds: 30),
        ),
      );

      // Get detailed invoice data
      final detailedInvoiceData = await _getDetailedInvoiceData(
          invoice['id'] ?? invoice['invoiceNumber']);

      // Create shipment object for PDF generation
      final shipment = Shipment(
        invoiceNumber: (detailedInvoiceData['invoiceNumber'] ??
                detailedInvoiceData['id'] ??
                'N/A')
            .toString(),
        shipper: (detailedInvoiceData['shipper'] ?? 'N/A').toString(),
        shipperAddress:
            (detailedInvoiceData['shipperAddress'] ?? '').toString(),
        consignee: (detailedInvoiceData['consignee'] ?? 'N/A').toString(),
        consigneeAddress:
            (detailedInvoiceData['consigneeAddress'] ?? '').toString(),
        awb: (detailedInvoiceData['awb'] ?? 'N/A').toString(),
        flightNo: (detailedInvoiceData['flightNo'] ?? 'N/A').toString(),
        dischargeAirport:
            (detailedInvoiceData['dischargeAirport'] ?? 'N/A').toString(),
        eta: detailedInvoiceData['eta'] is int
            ? DateTime.fromMillisecondsSinceEpoch(detailedInvoiceData['eta'])
            : DateTime.tryParse(detailedInvoiceData['eta']?.toString() ?? '') ??
                DateTime.now(),
        totalAmount:
            (detailedInvoiceData['totalAmount'] as num?)?.toDouble() ?? 0.0,
        invoiceTitle: (invoice['invoiceTitle'] ?? 'Invoice').toString(),
        origin: (detailedInvoiceData['origin'] ?? 'N/A').toString(),
        destination: (detailedInvoiceData['destination'] ?? 'N/A').toString(),
        status: (detailedInvoiceData['status'] ?? 'draft').toString(),
        // Add missing fields for PDF population
        invoiceDate: detailedInvoiceData['invoiceDate'] is int
            ? DateTime.fromMillisecondsSinceEpoch(
                detailedInvoiceData['invoiceDate'])
            : null,
        dateOfIssue: detailedInvoiceData['dateOfIssue'] is int
            ? DateTime.fromMillisecondsSinceEpoch(
                detailedInvoiceData['dateOfIssue'])
            : null,
        placeOfReceipt:
            (detailedInvoiceData['placeOfReceipt'] ?? '').toString(),
        sgstNo: (detailedInvoiceData['sgstNo'] ?? '').toString(),
        iecCode: (detailedInvoiceData['iecCode'] ?? '').toString(),
        freightTerms: (detailedInvoiceData['freightTerms'] ?? '').toString(),
      );

      // Get items from boxes
      final List<dynamic> items = [];
      int totalBoxes = 0;
      double totalWeight = 0.0;

      if (detailedInvoiceData['boxes'] != null) {
        totalBoxes = detailedInvoiceData['boxes'].length;
        for (var box in detailedInvoiceData['boxes']) {
          if (box['products'] != null) {
            items.addAll(box['products']);
            // Calculate total weight
            for (var product in box['products']) {
              totalWeight +=
                  double.tryParse(product['weight']?.toString() ?? '0') ?? 0.0;
            }
          }
        }
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Show print options dialog
      _showPrintOptionsDialog(
          invoice, shipment, items, totalBoxes, totalWeight);
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                  child: Text('Print preparation failed: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _printInvoice(invoice),
          ),
        ),
      );
    }
  }

  /// Show print options dialog
  void _showPrintOptionsDialog(Map<String, dynamic> invoice, Shipment shipment,
      List<dynamic> items, int totalBoxes, double totalWeight) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.print, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(child: Text('Print Options')),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invoice: ${invoice['invoiceTitle'] ?? 'Untitled'}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Number: ${invoice['invoiceNumber'] ?? 'N/A'}'),
              Text('Boxes: $totalBoxes'),
              Text('Total Weight: ${totalWeight.toStringAsFixed(2)} kg'),
              Text('Amount: \$${shipment.totalAmount.toStringAsFixed(2)}'),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will generate a professional PDF and open the print dialog.',
                        style: TextStyle(color: Colors.blue[700], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await _executePrint(shipment, items);
            },
            icon: Icon(Icons.print, size: 16),
            label: Text('Print'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          ),
        ],
      ),
    );
  }

  /// Execute the actual print operation
  Future<void> _executePrint(Shipment shipment, List<dynamic> items) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 16),
              Text('Generating print document...'),
            ],
          ),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Generate PDF for printing
      final pdfService = PdfService();
      await pdfService.generateShipmentPDF(shipment, items);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Print dialog opened successfully'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Print failed: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _executePrint(shipment, items),
          ),
        ),
      );
    }
  }

  /// Share invoice
  Future<void> _shareInvoice(Map<String, dynamic> invoice) async {
    try {
      // Show preparing message with loading indicator
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                    'Preparing "${invoice['invoiceTitle'] ?? 'Invoice'}" for sharing...'),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.fixed,
          duration: Duration(seconds: 30),
        ),
      );

      // Get detailed invoice data
      final detailedInvoiceData = await _getDetailedInvoiceData(
          invoice['id'] ?? invoice['invoiceNumber']);

      // Create shipment object for PDF generation
      final shipment = Shipment(
        invoiceNumber: (detailedInvoiceData['invoiceNumber'] ??
                detailedInvoiceData['id'] ??
                'N/A')
            .toString(),
        shipper: (detailedInvoiceData['shipper'] ?? 'N/A').toString(),
        shipperAddress:
            (detailedInvoiceData['shipperAddress'] ?? '').toString(),
        consignee: (detailedInvoiceData['consignee'] ?? 'N/A').toString(),
        consigneeAddress:
            (detailedInvoiceData['consigneeAddress'] ?? '').toString(),
        awb: (detailedInvoiceData['awb'] ?? 'N/A').toString(),
        flightNo: (detailedInvoiceData['flightNo'] ?? 'N/A').toString(),
        dischargeAirport:
            (detailedInvoiceData['dischargeAirport'] ?? 'N/A').toString(),
        eta: detailedInvoiceData['eta'] is int
            ? DateTime.fromMillisecondsSinceEpoch(detailedInvoiceData['eta'])
            : DateTime.tryParse(detailedInvoiceData['eta']?.toString() ?? '') ??
                DateTime.now(),
        totalAmount:
            (detailedInvoiceData['totalAmount'] as num?)?.toDouble() ?? 0.0,
        invoiceTitle: (invoice['invoiceTitle'] ?? 'Invoice').toString(),
        origin: (detailedInvoiceData['origin'] ?? 'N/A').toString(),
        destination: (detailedInvoiceData['destination'] ?? 'N/A').toString(),
        status: (detailedInvoiceData['status'] ?? 'draft').toString(),
        // Add missing fields for PDF population
        invoiceDate: detailedInvoiceData['invoiceDate'] is int
            ? DateTime.fromMillisecondsSinceEpoch(
                detailedInvoiceData['invoiceDate'])
            : null,
        dateOfIssue: detailedInvoiceData['dateOfIssue'] is int
            ? DateTime.fromMillisecondsSinceEpoch(
                detailedInvoiceData['dateOfIssue'])
            : null,
        placeOfReceipt:
            (detailedInvoiceData['placeOfReceipt'] ?? '').toString(),
        sgstNo: (detailedInvoiceData['sgstNo'] ?? '').toString(),
        iecCode: (detailedInvoiceData['iecCode'] ?? '').toString(),
        freightTerms: (detailedInvoiceData['freightTerms'] ?? '').toString(),
      );

      // Get items from boxes
      final List<dynamic> items = [];
      int totalBoxes = 0;
      double totalWeight = 0.0;

      if (detailedInvoiceData['boxes'] != null) {
        totalBoxes = detailedInvoiceData['boxes'].length;
        for (var box in detailedInvoiceData['boxes']) {
          if (box['products'] != null) {
            items.addAll(box['products']);
            for (var product in box['products']) {
              totalWeight +=
                  double.tryParse(product['weight']?.toString() ?? '0') ?? 0.0;
            }
          }
        }
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Show share options dialog
      _showShareOptionsDialog(
          invoice, shipment, items, totalBoxes, totalWeight);
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                  child: Text('Share preparation failed: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _shareInvoice(invoice),
          ),
        ),
      );
    }
  }

  /// Show share options dialog
  void _showShareOptionsDialog(Map<String, dynamic> invoice, Shipment shipment,
      List<dynamic> items, int totalBoxes, double totalWeight) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.share, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(child: Text('Share Options')),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invoice: ${invoice['invoiceTitle'] ?? 'Untitled'}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Number: ${invoice['invoiceNumber'] ?? 'N/A'}'),
              Text('Boxes: $totalBoxes'),
              Text('Total Weight: ${totalWeight.toStringAsFixed(2)} kg'),
              Text('Amount: \$${shipment.totalAmount.toStringAsFixed(2)}'),
              SizedBox(height: 16),
              Text('Choose sharing format:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 8),

              // Share format options
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.picture_as_pdf, color: Colors.red),
                      title: Text('Share as PDF'),
                      subtitle: Text('Professional invoice document'),
                      onTap: () {
                        Navigator.of(context).pop();
                        _shareAsPdf(shipment, items);
                      },
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.text_snippet, color: Colors.blue),
                      title: Text('Share as Text'),
                      subtitle: Text('Simple text summary'),
                      onTap: () {
                        Navigator.of(context).pop();
                        _shareAsText(
                            invoice, shipment, totalBoxes, totalWeight);
                      },
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.table_chart, color: Colors.green),
                      title: Text('Share as CSV'),
                      subtitle: Text('Spreadsheet-compatible data'),
                      onTap: () {
                        Navigator.of(context).pop();
                        _shareAsCsv(invoice, shipment, items);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Share as PDF
  Future<void> _shareAsPdf(Shipment shipment, List<dynamic> items) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 16),
              Text('Generating PDF for sharing...'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Generate and share PDF
      final pdfService = PdfService();
      await pdfService.generateShipmentPDF(shipment, items);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('PDF shared successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share PDF: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Share as text summary
  Future<void> _shareAsText(Map<String, dynamic> invoice, Shipment shipment,
      int totalBoxes, double totalWeight) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 16),
              Text('Preparing text summary...'),
            ],
          ),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Create text summary
      final textContent = '''
📄 INVOICE SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🧾 Invoice Details
• Number: ${shipment.invoiceNumber}
• Title: ${shipment.invoiceTitle}
• Date: ${DateTime.now().toString().substring(0, 16)}

🚚 Shipment Information
• Shipper: ${shipment.shipper}
• Consignee: ${shipment.consignee}
• AWB: ${shipment.awb}
• Flight: ${shipment.flightNo}
• Airport: ${shipment.dischargeAirport}

📦 Shipment Summary
• Total Boxes: $totalBoxes
• Total Weight: ${totalWeight.toStringAsFixed(2)} kg
• Total Amount: \$${shipment.totalAmount.toStringAsFixed(2)}

Generated via Invoice Generator App
${DateTime.now()}
''';

      // Copy to clipboard and show share intent
      await _copyToClipboard(textContent, 'Invoice summary');

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      // Note: In a real app, you would use share_plus plugin here
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share text: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Share as CSV data
  Future<void> _shareAsCsv(Map<String, dynamic> invoice, Shipment shipment,
      List<dynamic> items) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 16),
              Text('Generating CSV data...'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Create CSV content (simplified for sharing)
      final csvContent = '''Invoice,${shipment.invoiceNumber}
Title,${shipment.invoiceTitle}
Shipper,${shipment.shipper}
Consignee,${shipment.consignee}
AWB,${shipment.awb}
Flight,${shipment.flightNo}
Airport,${shipment.dischargeAirport}
Total Amount,${shipment.totalAmount}
Generated,${DateTime.now()}''';

      // Copy to clipboard and share
      await _copyToClipboard(csvContent, 'CSV data');

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share CSV: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Export as Excel (.xlsx format) with proper file generation
  Future<void> _exportAsExcel(Map<String, dynamic> invoice) async {
    try {
      // Call the new Excel generation service
      await ExcelFileService.generateAndExportExcel(
        context,
        invoice,
        _getDetailedInvoiceData,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Excel export failed: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Show Excel preview dialog with export options
  void _showExcelPreviewDialog(
      Map<String, dynamic> invoice, String csvContent) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.table_chart, color: Colors.green),
            SizedBox(width: 8),
            Expanded(child: Text('Excel Export Preview')),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invoice: ${invoice['invoiceTitle'] ?? 'Untitled'}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Export contains: Invoice details, shipment info, box/product data, and summary',
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 16),
              Text('CSV Preview:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.grey[50],
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      csvContent.length > 1000
                          ? csvContent.substring(0, 1000) +
                              '\n... (content truncated for preview)'
                          : csvContent,
                      style: TextStyle(
                        fontFamily: 'Courier New',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await _copyToClipboard(csvContent, 'Excel data');
            },
            icon: Icon(Icons.copy, size: 16),
            label: Text('Copy'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              await _saveExcelFile(invoice, csvContent);
            },
            icon: Icon(Icons.download, size: 16),
            label: Text('Save'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  /// Save Excel file to device storage
  Future<void> _saveExcelFile(
      Map<String, dynamic> invoice, String csvContent) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 16),
              Text('Saving Excel file...'),
            ],
          ),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'invoice_${invoice['invoiceNumber'] ?? DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(csvContent);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Excel file saved: $fileName')),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () {
              // Note: File opening would require platform-specific implementation
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('File location: ${file.path}'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save Excel file: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Copy content to clipboard with feedback
  Future<void> _copyToClipboard(String content, String type) async {
    try {
      await Clipboard.setData(ClipboardData(text: content));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('$type copied to clipboard'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to copy: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Email invoice
  Future<void> _emailInvoice(Map<String, dynamic> invoice) async {
    try {
      // Show preparing message with loading indicator
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                    'Preparing "${invoice['invoiceTitle'] ?? 'Invoice'}" for email...'),
              ),
            ],
          ),
          backgroundColor: Colors.purple,
          behavior: SnackBarBehavior.fixed,
          duration: Duration(seconds: 30),
        ),
      );

      // Get detailed invoice data
      final detailedInvoiceData = await _getDetailedInvoiceData(
          invoice['id'] ?? invoice['invoiceNumber']);

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Show enhanced email composition dialog
      _showEmailCompositionDialog(invoice, detailedInvoiceData);
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                  child: Text('Email preparation failed: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _emailInvoice(invoice),
          ),
        ),
      );
    }
  }

  /// Show enhanced email composition dialog
  void _showEmailCompositionDialog(
      Map<String, dynamic> invoice, Map<String, dynamic> detailedData) {
    final toEmailController = TextEditingController();
    final ccEmailController = TextEditingController();
    final subjectController = TextEditingController(
      text:
          'Invoice ${invoice['invoiceNumber'] ?? 'N/A'} - ${invoice['invoiceTitle'] ?? 'Shipment Details'}',
    );
    final messageController = TextEditingController(
      text: '''Dear Valued Customer,

Please find the attached invoice for your recent shipment.

Invoice Details:
• Invoice Number: ${invoice['invoiceNumber'] ?? 'N/A'}
• Title: ${invoice['invoiceTitle'] ?? 'N/A'}
• AWB: ${detailedData['awb'] ?? 'N/A'}
• Flight: ${detailedData['flightNo'] ?? 'N/A'}
• Amount: \$${detailedData['totalAmount'] ?? '0.00'}

If you have any questions regarding this invoice, please don't hesitate to contact us.

Thank you for choosing our services.

Best regards,
Invoice Generator Team''',
    );

    bool includeExcel = true;
    bool includePdf = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.email, color: Colors.purple[600]),
              const SizedBox(width: 8),
              const Expanded(child: Text('Email Invoice')),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            height: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Invoice Summary
                  Card(
                    color: Colors.purple[50],
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invoice Summary',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple[700]),
                          ),
                          SizedBox(height: 4),
                          Text(
                              '${invoice['invoiceTitle'] ?? 'Untitled'} (${invoice['invoiceNumber'] ?? 'N/A'})'),
                          Text(
                              'Amount: \$${detailedData['totalAmount'] ?? '0.00'}'),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Email Fields
                  TextField(
                    controller: toEmailController,
                    decoration: const InputDecoration(
                      labelText: 'To Email *',
                      hintText: 'recipient@example.com',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ccEmailController,
                    decoration: const InputDecoration(
                      labelText: 'CC Email (Optional)',
                      hintText: 'cc@example.com',
                      prefixIcon: Icon(Icons.group),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      prefixIcon: Icon(Icons.subject),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: messageController,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      prefixIcon: Icon(Icons.message),
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 8,
                  ),
                  const SizedBox(height: 16),

                  // Attachment Options
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attachments',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          CheckboxListTile(
                            title: Text('Include PDF Invoice'),
                            subtitle: Text('Professional invoice document'),
                            value: includePdf,
                            onChanged: (value) =>
                                setState(() => includePdf = value ?? true),
                            secondary:
                                Icon(Icons.picture_as_pdf, color: Colors.red),
                            dense: true,
                          ),
                          CheckboxListTile(
                            title: Text('Include Excel Export'),
                            subtitle: Text('Spreadsheet with invoice data'),
                            value: includeExcel,
                            onChanged: (value) =>
                                setState(() => includeExcel = value ?? true),
                            secondary:
                                Icon(Icons.table_chart, color: Colors.green),
                            dense: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: toEmailController.text.trim().isEmpty
                  ? null
                  : () {
                      Navigator.pop(context);
                      _sendEmailWithAttachments(
                        invoice,
                        detailedData,
                        toEmailController.text.trim(),
                        ccEmailController.text.trim(),
                        subjectController.text,
                        messageController.text,
                        includePdf,
                        includeExcel,
                      );
                    },
              icon: const Icon(Icons.send),
              label: const Text('Send Email'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            ),
          ],
        ),
      ),
    );
  }

  /// Send email with attachments
  Future<void> _sendEmailWithAttachments(
    Map<String, dynamic> invoice,
    Map<String, dynamic> detailedData,
    String toEmail,
    String ccEmail,
    String subject,
    String message,
    bool includePdf,
    bool includeExcel,
  ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 16),
              Expanded(child: Text('Preparing email with attachments...')),
            ],
          ),
          backgroundColor: Colors.purple,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 10),
        ),
      );

      // Simulate attachment preparation
      await Future.delayed(Duration(milliseconds: 1500));

      List<String> attachments = [];
      if (includePdf)
        attachments.add('invoice_${invoice['invoiceNumber']}.pdf');
      if (includeExcel)
        attachments.add('invoice_${invoice['invoiceNumber']}.csv');

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Show email composition summary
      _showEmailSummaryDialog(toEmail, ccEmail, subject, attachments);
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Email sending failed: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Show email summary dialog
  void _showEmailSummaryDialog(String toEmail, String ccEmail, String subject,
      List<String> attachments) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.mark_email_read, color: Colors.green),
            SizedBox(width: 8),
            Text('Email Ready'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📧 Email Details:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('To: $toEmail'),
            if (ccEmail.isNotEmpty) Text('CC: $ccEmail'),
            Text('Subject: $subject'),
            SizedBox(height: 16),
            Text('📎 Attachments:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            ...attachments.map((attachment) => Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Text('• $attachment'),
                )),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'In a production app, this would open your email client with the invoice attached.',
                      style: TextStyle(color: Colors.blue[700], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // Advanced Search Panel
  Widget _buildAdvancedSearchPanel() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Invoice Number Search
          TextField(
            controller: _invoiceNumberController,
            decoration: InputDecoration(
              labelText: 'Invoice Number',
              hintText: 'Search by invoice or tracking number',
              prefixIcon: const Icon(Icons.receipt_long),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            onChanged: (value) => _applyFilters(),
          ),
          const SizedBox(height: 12),

          // Date Range
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectFromDate(),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          fromDate != null
                              ? 'From: ${fromDate!.day}/${fromDate!.month}/${fromDate!.year}'
                              : 'From Date',
                          style: TextStyle(
                            color: fromDate != null
                                ? Colors.black
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectToDate(),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          toDate != null
                              ? 'To: ${toDate!.day}/${toDate!.month}/${toDate!.year}'
                              : 'To Date',
                          style: TextStyle(
                            color: toDate != null
                                ? Colors.black
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status Dropdown
          DropdownButtonFormField<String>(
            value: selectedStatus,
            decoration: InputDecoration(
              labelText: 'Status',
              prefixIcon: const Icon(Icons.local_shipping),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            items: ['All', 'Pending', 'In Transit', 'Delivered', 'Cancelled']
                .map((status) => DropdownMenuItem(
                      value: status,
                      child: Text(status),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedStatus = value ?? 'All';
              });
              _applyFilters();
            },
          ),
          const SizedBox(height: 12),

          // Clear Filters Button
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Filters'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      showAdvancedSearch = false;
                    });
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectFromDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != fromDate) {
      setState(() {
        fromDate = picked;
      });
      _applyFilters();
    }
  }

  Future<void> _selectToDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: toDate ?? DateTime.now(),
      firstDate: fromDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != toDate) {
      setState(() {
        toDate = picked;
      });
      _applyFilters();
    }
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _invoiceNumberController.clear();
      fromDate = null;
      toDate = null;
      selectedStatus = 'All';
      filteredInvoices = invoices;
    });
  }

  /// Extract box number from box number string (e.g., "Box No 3" -> 3)
  int _extractBoxNumber(String boxNumber) {
    final match = RegExp(r'(\d+)').firstMatch(boxNumber);
    return match != null ? int.parse(match.group(1)!) : 0;
  }
}
