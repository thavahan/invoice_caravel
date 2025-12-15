import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:invoice_generator/providers/auth_provider.dart';
import 'package:invoice_generator/screens/auth/login_screen.dart';
import 'package:invoice_generator/screens/splash/splash_screen.dart';
import 'package:invoice_generator/screens/invoice_list_screen.dart';
import 'package:invoice_generator/widgets/error_boundary.dart';
import 'package:invoice_generator/widgets/sync_progress_indicator.dart';
import 'package:invoice_generator/services/database_service.dart';

/// AuthWrapper handles authentication state routing
/// Shows splash screen while checking auth state, then routes to appropriate screen
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        print(
            '🔐 AUTH_WRAPPER: isLoading=${authProvider.isLoading}, isAuthenticated=${authProvider.isAuthenticated}, user=${authProvider.user?.email ?? 'null'}, firebaseAvailable=${authProvider.isFirebaseAvailable}');
        print('👤 CURRENT_USER_ID: ${authProvider.user?.uid ?? 'null'}');
        print(
            '💾 DATABASE_USER_ID: ${DatabaseService().getCurrentUserId() ?? 'null'}');

        // Show splash screen while auth state is being determined
        if (authProvider.isLoading) {
          print('🔄 AUTH_WRAPPER: Showing SplashScreen (loading)');
          return SplashScreen();
        }

        // If user is authenticated, show the main app
        if (authProvider.isAuthenticated) {
          print('✅ AUTH_WRAPPER: Showing InvoiceListScreen (authenticated)');
          // Return the main app content (InvoiceListScreen) with sync overlay
          return ErrorBoundary(
            child: Stack(
              children: [
                const InvoiceListScreen(),
                SyncProgressOverlay(),
              ],
            ),
          );
        }

        // If not authenticated (regardless of Firebase availability), show login screen
        print('❌ AUTH_WRAPPER: Showing LoginScreen (not authenticated)');
        return const LoginScreen();
      },
    );
  }
}
