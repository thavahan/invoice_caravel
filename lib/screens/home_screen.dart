import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:invoice_generator/screens/invoice_list_screen.dart';
import 'package:invoice_generator/modules/orders/screens/orders_list_screen.dart';
import 'package:invoice_generator/providers/auth_provider.dart';
import 'package:invoice_generator/providers/invoice_provider.dart';
import 'package:invoice_generator/providers/theme_provider.dart';
import 'package:invoice_generator/services/data_service.dart';
import 'package:invoice_generator/screens/master_data/master_data_screen.dart';

/// Main home screen with tabs for Invoices and Orders
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DataService _dataService = DataService();
  InvoiceProvider? _invoiceProvider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeDataService();
  }

  Future<void> _initializeDataService() async {
    try {
      await _dataService.initialize();
    } catch (e) {
      debugPrint('Failed to initialize data service: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_invoiceProvider == null) {
      try {
        _invoiceProvider = Provider.of<InvoiceProvider>(context);
      } catch (e) {
        // Provider might not be available
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimary.withOpacity(0.7),
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
          _buildDrawerItem(Icons.cloud_sync, 'Sync to Cloud', false),
          _buildDrawerItem(Icons.settings_applications, 'Master Data', false),
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
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
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
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Cloud shippers: ${status['firebaseShippersCount'] ?? 0}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Local consignees: ${status['localConsigneesCount'] ?? 0}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Cloud consignees: ${status['firebaseConsigneesCount'] ?? 0}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Local product types: ${status['localProductTypesCount'] ?? 0}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Cloud product types: ${status['firebaseProductTypesCount'] ?? 0}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Local flower types: ${status['localFlowerTypesCount'] ?? 0}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Cloud flower types: ${status['firebaseFlowerTypesCount'] ?? 0}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
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
              'Found ${status['localShipmentsCount'] ?? 0} shipments to sync',
            ),
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

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Shipments and master data synced to cloud successfully!',
            ),
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
      selectedTileColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.1),
      onTap: () {
        Navigator.pop(context);

        // Handle navigation based on title
        if (title == 'Master Data') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MasterDataScreen()),
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          ),
          //title: Image.asset('asset/images/txt_caravel.png'),
          title: Text(
            'CARAVEL',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          bottom: PreferredSize(
            preferredSize:
                const Size.fromHeight(48 + 1), // TabBar height + divider
            child: Column(
              children: [
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(context).dividerColor.withOpacity(0.3),
                ),
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Invoices'),
                    Tab(text: 'Orders'),
                  ],
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),
        drawer: _buildNavigationDrawer(),
        body: TabBarView(
          controller: _tabController,
          children: const [InvoiceListScreen(), OrdersListScreen()],
        ),
      ),
    );
  }
}
