import 'package:flutter/material.dart';
import 'package:invoice_generator/screens/master_data/manage_shippers_screen.dart';
import 'package:invoice_generator/screens/master_data/manage_consignees_screen.dart';
import 'package:invoice_generator/screens/master_data/manage_product_types_screen.dart';
import 'package:invoice_generator/screens/master_data/manage_flower_types_screen.dart';
import 'package:invoice_generator/screens/master_data/firestore_data_viewer_screen.dart';
import 'package:invoice_generator/screens/master_data/database_data_viewer_screen.dart';
import 'package:invoice_generator/services/data_service.dart';
import 'package:invoice_generator/providers/auth_provider.dart';
import 'package:invoice_generator/widgets/branded_loading_indicator.dart';
import 'package:provider/provider.dart';

/// Main screen for managing master data (shippers, consignees, product types)
class MasterDataScreen extends StatefulWidget {
  const MasterDataScreen({Key? key}) : super(key: key);

  @override
  State<MasterDataScreen> createState() => _MasterDataScreenState();
}

class _MasterDataScreenState extends State<MasterDataScreen> {
  final DataService _dataService = DataService();
  Map<String, int> _counts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    setState(() => _isLoading = true);

    try {
      final shippers = await _dataService.getMasterShippers();
      final consignees = await _dataService.getMasterConsignees();
      final productTypes = await _dataService.getMasterProductTypes();
      final flowerTypes = await _dataService.getFlowerTypes();

      if (mounted) {
        setState(() {
          _counts = {
            'shippers': shippers.length,
            'consignees': consignees.length,
            'productTypes': productTypes.length,
            'flowerTypes': flowerTypes.length,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Data Management'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withOpacity(0.3)
            ],
          ),
        ),
        child: _isLoading
            ? const Center(child: BrandedLoadingWidget())
            : RefreshIndicator(
                onRefresh: _loadCounts,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          constraints: const BoxConstraints(minHeight: 120),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                Theme.of(context).colorScheme.surface
                              ],
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.settings_applications,
                                size: 48,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Master Data Management',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Manage shippers, consignees, and product types for quick invoice creation',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Prepare filtered items based on user permissions
                      Builder(
                        builder: (context) {
                          final currentUserEmail =
                              Provider.of<AuthProvider>(context, listen: false)
                                  .user
                                  ?.email;
                          final allItems = [
                            {
                              'title': 'Manage Shippers',
                              'subtitle':
                                  '${_counts['shippers'] ?? 0} shippers configured',
                              'icon': Icons.business,
                              'color': Colors.green,
                              'screen': const ManageShippersScreen(),
                            },
                            {
                              'title': 'Manage Consignees',
                              'subtitle':
                                  '${_counts['consignees'] ?? 0} consignees configured',
                              'icon': Icons.person_outline,
                              'color': Colors.orange,
                              'screen': const ManageConsigneesScreen(),
                            },
                            {
                              'title': 'Manage Product Types',
                              'subtitle':
                                  '${_counts['productTypes'] ?? 0} product types configured',
                              'icon': Icons.category,
                              'color': Colors.purple,
                              'screen': const ManageProductTypesScreen(),
                            },
                            {
                              'title': 'Manage Flower Types',
                              'subtitle':
                                  '${_counts['flowerTypes'] ?? 0} flower types configured',
                              'icon': Icons.local_florist,
                              'color': Colors.pink,
                              'screen': const ManageFlowerTypesScreen(),
                            },
                            {
                              'title': 'View Firestore Data',
                              'subtitle': 'Browse data in Firestore',
                              'icon': Icons.cloud,
                              'color': Colors.blue,
                              'screen': const FirestoreDataViewerScreen(),
                              'restricted': true,
                            },
                            {
                              'title': 'View Database Data',
                              'subtitle': 'Browse data in Database',
                              'icon': Icons.storage,
                              'color': Colors.teal,
                              'screen': const DatabaseDataViewerScreen(),
                              'restricted': true,
                            },
                          ];

                          final items = allItems.where((item) {
                            final isRestricted = item['restricted'] == true;
                            return !isRestricted ||
                                currentUserEmail == 'thavahan@gmail.com';
                          }).toList();

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: items.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return _buildMasterDataCard(
                                title: item['title'] as String,
                                subtitle: item['subtitle'] as String,
                                icon: item['icon'] as IconData,
                                color: item['color'] as Color,
                                onTap: () =>
                                    _navigateToScreen(item['screen'] as Widget),
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // Info Section
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'How it works',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '• Pre-configure commonly used shippers, consignees, and product types\n'
                                '• Use dropdown menus in invoice forms for quick selection\n'
                                '• Reduce typing errors and improve consistency\n'
                                '• View all your data in Firestore or local database\n'
                                '• Monitor data synchronization between cloud and local storage',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildMasterDataCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(minHeight: 80),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.5),
                Theme.of(context).colorScheme.surface
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color.withOpacity(0.8),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color.withOpacity(0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                color: color.withOpacity(0.6),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToScreen(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );

    // Always refresh counts when returning from a management screen
    _loadCounts();
  }
}
