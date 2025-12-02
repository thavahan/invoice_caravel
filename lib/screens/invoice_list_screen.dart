import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:invoice_generator/screens/invoice_form/invoice_form.dart';
import 'package:invoice_generator/screens/master_data/master_data_screen.dart';
import 'package:invoice_generator/providers/theme_provider.dart';
import 'package:invoice_generator/providers/auth_provider.dart';
import 'package:invoice_generator/providers/invoice_provider.dart';
import 'package:invoice_generator/services/local_database_service.dart';
import 'package:invoice_generator/services/pdf_service.dart';
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

    // Load invoices after a slight delay to ensure database service is fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInvoices();
    });
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
      await _databaseService.deleteDraft(draftId);
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
                                size: 24,
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
                              padding: const EdgeInsets.all(8),
                              splashRadius: 20,
                              tooltip: 'Open menu',
                            ),
                            const SizedBox(width: 16),
                            // Gmail-style Search Bar
                            Expanded(
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .inputDecorationTheme
                                      .fillColor,
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
                            const SizedBox(width: 12),
                            // Gmail-style Profile Avatar
                            Container(
                              margin: const EdgeInsets.only(right: 4),
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.blue[600],
                                child: const Text(
                                  'A',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
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
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : _showDrafts
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
                                  padding: const EdgeInsets.all(0),
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
                      child: CircularProgressIndicator(),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          setState(() {
            selectedIndex = index;
          });
          _handleBottomNavTap(index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: 'Shipments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.drafts),
            label: 'Drafts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Tracking',
          ),
        ],
      ),
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
            decoration: const BoxDecoration(
              color: Colors.blue,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: const [
                      Text(
                        'Invoice Manager',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Manage your logistics invoices',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.logout,
                    color: Colors.white,
                    size: 28,
                  ),
                  tooltip: 'Logout',
                  onPressed: _handleLogout,
                ),
              ],
            ),
          ),
          _buildDrawerItem(Icons.dashboard, 'Dashboard', true),
          _buildDrawerItem(Icons.receipt_long, 'All Invoices', false),
          _buildDrawerItem(Icons.pending, 'Pending Shipments', false),
          _buildDrawerItem(Icons.local_shipping, 'In Transit', false),
          _buildDrawerItem(Icons.check_circle, 'Delivered', false),
          const Divider(),
          _buildDrawerItem(Icons.settings_applications, 'Master Data', false),
          _buildDrawerItem(Icons.analytics, 'Reports', false),
          _buildDrawerItem(Icons.inventory, 'Inventory', false),
          _buildDrawerItem(Icons.people, 'Customers', false),
          _buildDrawerItem(Icons.location_on, 'Tracking', false),
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

  Widget _buildDrawerItem(IconData icon, String title, bool isSelected) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.blue : Colors.grey[600],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.blue : Colors.grey[800],
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.blue.withValues(alpha: 0.1),
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
            color: Colors.grey[600],
          ),
          title: const Text(
            'Dark Theme',
            style: TextStyle(
              fontWeight: FontWeight.normal,
            ),
          ),
          trailing: Switch(
            value: themeProvider.isDarkMode,
            onChanged: (value) {
              themeProvider.toggleTheme();
            },
            activeColor: Colors.blue,
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
            CircularProgressIndicator(),
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
      padding: const EdgeInsets.all(0),
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
      await _databaseService.deleteShipment(shipmentId);
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

    // Format date
    String dateStr = 'Unknown Date';
    if (invoice['createdAt'] != null) {
      final date =
          DateTime.fromMillisecondsSinceEpoch(invoice['createdAt'] as int);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        dateStr = '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays < 7) {
        const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        dateStr = days[date.weekday % 7];
      } else {
        dateStr = '${date.day}/${date.month}';
      }
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 0.5,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 8.0,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getStatusColor(status).withValues(alpha: 0.1),
            border: Border.all(
              color: _getStatusColor(status),
              width: 2,
            ),
          ),
          child: Icon(
            _getStatusIcon(status),
            color: _getStatusColor(status),
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                shipper,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              dateStr,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              'To: $consignee • $status',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Icon(
          Icons.star_border,
          color: Colors.grey[400],
          size: 20,
        ),
        onTap: () {
          _showInvoiceDetails(context, invoice);
        },
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
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
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
              decoration: const BoxDecoration(
                color: Colors.white,
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
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  // Header with title and action buttons
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[200]!, width: 1),
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
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                detailedInvoice['invoiceTitle'] ??
                                    'Untitled Invoice',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
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
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                onPressed: () {
                                  Navigator.pop(context); // Close bottom sheet
                                  _editInvoice(detailedInvoice);
                                },
                                icon:
                                    const Icon(Icons.edit, color: Colors.blue),
                                tooltip: 'Edit Invoice',
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Export/Print button
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                onPressed: () {
                                  _showExportOptions(context, detailedInvoice);
                                },
                                icon: const Icon(Icons.print,
                                    color: Colors.green),
                                tooltip: 'Export/Print',
                              ),
                            ),
                            const SizedBox(width: 8),

                            // More options button
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
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
                                    color: Colors.grey[600]),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'status',
                                    child: ListTile(
                                      leading: Icon(Icons.update, size: 20),
                                      title: Text('Update Status'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: Icon(Icons.delete,
                                          color: Colors.red, size: 20),
                                      title: Text('Delete',
                                          style: TextStyle(color: Colors.red)),
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
                color: isTotal ? Colors.black : Colors.grey,
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
                color: isTotal ? Colors.green[700] : Colors.black,
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

      final boxesFromDb = await _databaseService
          .getBoxesForShipment(matchingShipment.invoiceNumber);

      if (boxesFromDb.isEmpty) {
        print(
            'DEBUG: No boxes returned for shipment invoice ${matchingShipment.invoiceNumber} (awb=${matchingShipment.awb}).');
      }
      final boxes = <Map<String, dynamic>>[];

      for (final box in boxesFromDb) {
        final products = box.products
            .map((product) => {
                  'type': product.type,
                  'description': product.description,
                  'weight': product.weight,
                  'rate': product.rate,
                })
            .toList();

        boxes.add({
          'boxNumber': box.boxNumber,
          'length': box.length,
          'width': box.width,
          'height': box.height,
          'products': products,
        });
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
              color: Colors.blue[50],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.inventory_2, size: 20, color: Colors.blue[700]),
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
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${boxes.length} boxes containing ${_getTotalProducts(boxes)} items',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Tap to expand',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue[700],
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
              color: Colors.grey[200],
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
          color: Colors.orange[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.inventory, color: Colors.orange[700], size: 20),
      ),
      title: Text(
        boxNumber,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Size: $dimensions',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          Text(
            'Weight: ${boxWeight.toStringAsFixed(2)} kg • Value: \$${boxTotal.toStringAsFixed(2)}',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${products.length} items',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.green[700],
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
    final description = product['description'] ?? '';
    final weight = (product['weight'] as num?)?.toDouble() ?? 0.0;
    final rate = (product['rate'] as num?)?.toDouble() ?? 0.0;
    final productTotal = weight * rate;

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.category, color: Colors.blue[700], size: 16),
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
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${weight}kg × \$${rate.toStringAsFixed(2)} = \$${productTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.grey[700],
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
              color: Colors.grey[50],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
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
              'id': boxRaw['id'] ?? shipmentId,
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
        decoration: const BoxDecoration(
          color: Colors.white,
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
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Export Options',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
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
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child:
                            const Icon(Icons.picture_as_pdf, color: Colors.red),
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
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child:
                            const Icon(Icons.table_chart, color: Colors.green),
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
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.print, color: Colors.blue),
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
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.share, color: Colors.orange),
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
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.email, color: Colors.purple),
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
        invoiceNumber: (invoice['invoiceNumber'] ?? 'N/A').toString(),
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

      // Show PDF preview dialog
      _showPdfPreviewDialog(invoice, shipment, items, totalBoxes, totalWeight);
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

  /// Show PDF preview dialog
  void _showPdfPreviewDialog(Map<String, dynamic> invoice, Shipment shipment,
      List<dynamic> items, int totalBoxes, double totalWeight) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.picture_as_pdf, color: Colors.red),
            SizedBox(width: 8),
            Expanded(child: Text('PDF Export Preview')),
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
              Text('Shipper: ${shipment.shipper}'),
              Text('Consignee: ${shipment.consignee}'),
              Text('AWB: ${shipment.awb}'),
              Text('Flight: ${shipment.flightNo}'),
              Text('Airport: ${shipment.dischargeAirport}'),
              Text('Boxes: $totalBoxes'),
              Text('Total Weight: ${totalWeight.toStringAsFixed(2)} kg'),
              Text('Amount: \$${shipment.totalAmount.toStringAsFixed(2)}'),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red[700], size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will generate a professional PDF invoice document.',
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
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
              await _executePdfGeneration(shipment, items);
            },
            icon: Icon(Icons.picture_as_pdf, size: 16),
            label: Text('Generate PDF'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
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
      await pdfService.generateShipmentPDF(shipment, items, true);
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
        invoiceNumber: (invoice['invoiceNumber'] ?? 'N/A').toString(),
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
      await pdfService.generateShipmentPDF(shipment, items, true);

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
        invoiceNumber: (invoice['invoiceNumber'] ?? 'N/A').toString(),
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
      await pdfService.generateShipmentPDF(
          shipment, items, false); // false for share

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

  /// Export as Excel (CSV format)
  Future<void> _exportAsExcel(Map<String, dynamic> invoice) async {
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
                    'Creating Excel export for "${invoice['invoiceTitle'] ?? 'Invoice'}"...'),
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

      // Create comprehensive CSV content
      final StringBuffer csvBuffer = StringBuffer();

      // Header section
      csvBuffer.writeln('Invoice Export Report');
      csvBuffer.writeln('Generated,${DateTime.now().toString()}');
      csvBuffer.writeln('');

      // Invoice Information
      csvBuffer.writeln('INVOICE INFORMATION');
      csvBuffer
          .writeln('Invoice Number,"${invoice['invoiceNumber'] ?? 'N/A'}"');
      csvBuffer.writeln('Invoice Title,"${invoice['invoiceTitle'] ?? 'N/A'}"');
      csvBuffer.writeln(
          'Date Created,"${invoice['createdAt']?.toString() ?? 'N/A'}"');
      csvBuffer.writeln('Status,"${invoice['status'] ?? 'Draft'}"');
      csvBuffer.writeln('');

      // Shipment Information
      csvBuffer.writeln('SHIPMENT INFORMATION');
      csvBuffer.writeln('Shipper,"${detailedInvoiceData['shipper'] ?? 'N/A'}"');
      csvBuffer
          .writeln('Consignee,"${detailedInvoiceData['consignee'] ?? 'N/A'}"');
      csvBuffer.writeln('AWB Number,"${detailedInvoiceData['awb'] ?? 'N/A'}"');
      csvBuffer.writeln(
          'Flight Number,"${detailedInvoiceData['flightNo'] ?? 'N/A'}"');
      csvBuffer.writeln(
          'Discharge Airport,"${detailedInvoiceData['dischargeAirport'] ?? 'N/A'}"');
      csvBuffer.writeln(
          'Total Amount,"${detailedInvoiceData['totalAmount'] ?? 0.0}"');
      csvBuffer.writeln('');

      // Box and Product Details
      csvBuffer.writeln('BOX AND PRODUCT DETAILS');
      csvBuffer.writeln(
          'Box Number,Length,Width,Height,Product Type,Description,Weight,Rate');

      int totalBoxes = 0;
      double totalWeight = 0.0;
      double totalValue = 0.0;

      if (detailedInvoiceData['boxes'] != null) {
        for (var box in detailedInvoiceData['boxes']) {
          totalBoxes++;
          final boxNumber = box['boxNumber'] ?? 'N/A';
          final length = box['length'] ?? 0.0;
          final width = box['width'] ?? 0.0;
          final height = box['height'] ?? 0.0;

          if (box['products'] != null) {
            for (var product in box['products']) {
              final weight =
                  double.tryParse(product['weight']?.toString() ?? '0') ?? 0.0;
              final rate =
                  double.tryParse(product['rate']?.toString() ?? '0') ?? 0.0;
              totalWeight += weight;
              totalValue += rate;

              csvBuffer.writeln('"$boxNumber","$length","$width","$height",'
                  '"${product['type'] ?? 'N/A'}",'
                  '"${product['description'] ?? 'N/A'}",'
                  '"$weight","$rate"');
            }
          } else {
            csvBuffer.writeln(
                '"$boxNumber","$length","$width","$height","No Products","","0.0","0.0"');
          }
        }
      } else {
        csvBuffer
            .writeln('"No boxes found","0","0","0","N/A","N/A","0.0","0.0"');
      }

      // Summary section
      csvBuffer.writeln('');
      csvBuffer.writeln('EXPORT SUMMARY');
      csvBuffer.writeln('Total Boxes,$totalBoxes');
      csvBuffer.writeln('Total Weight,$totalWeight');
      csvBuffer.writeln('Total Value,$totalValue');
      csvBuffer.writeln('Export Date,${DateTime.now().toString()}');

      final csvContent = csvBuffer.toString();

      // Simulate processing time
      await Future.delayed(Duration(milliseconds: 800));

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Show preview dialog with options
      _showExcelPreviewDialog(invoice, csvContent);
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
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _exportAsExcel(invoice),
          ),
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
}
