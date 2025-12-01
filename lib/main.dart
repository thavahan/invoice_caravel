import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:invoice_generator/providers/invoice_provider.dart';
import 'package:invoice_generator/providers/theme_provider.dart';
import 'package:invoice_generator/providers/auth_provider.dart';
import 'package:invoice_generator/widgets/auth_wrapper.dart';
import 'package:invoice_generator/services/local_database_service.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check connectivity before initializing Firebase
  bool shouldInitializeFirebase = false;
  try {
    final connectivity = Connectivity();
    final results = await connectivity.checkConnectivity();

    // In connectivity_plus 6.0.0, checkConnectivity returns List<ConnectivityResult>
    shouldInitializeFirebase = results.isNotEmpty &&
        results.any((result) => result != ConnectivityResult.none);

    if (shouldInitializeFirebase) {
      print('📶 Network detected, initializing Firebase...');
    } else {
      print('📵 No network detected, skipping Firebase initialization');
    }
  } catch (e) {
    print('⚠️ Connectivity check failed, skipping Firebase: $e');
    shouldInitializeFirebase = false;
  }

  // Initialize Firebase only if we have connectivity
  bool firebaseInitialized = false;
  if (shouldInitializeFirebase) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('⏰ Firebase initialization timed out');
          throw Exception('Firebase initialization timeout');
        },
      );
      firebaseInitialized = true;
      print('✅ Firebase initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize Firebase: $e');
      firebaseInitialized = false;
    }
  }

  // Store Firebase initialization status for later use
  await _storeFirebaseStatus(firebaseInitialized);

  // Initialize sqflite for desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Restrict to portrait orientation only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize SQLite database
  try {
    await LocalDatabaseService().initialize();
    print('✅ SQLite database initialized successfully');
  } catch (e) {
    print('❌ Failed to initialize database: $e');
  }

  // Create ThemeProvider and initialize theme preference
  final themeProvider = ThemeProvider();
  try {
    await themeProvider.initTheme();
    print('✅ Theme preference initialized successfully');
  } catch (e) {
    print('❌ Failed to initialize theme preference: $e');
  }

  // Create providers
  final authProvider = AuthProvider();
  final invoiceProvider = InvoiceProvider();

  // Set up provider references for login-time sync
  authProvider.setInvoiceProvider(invoiceProvider);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: invoiceProvider),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false, // Remove debug banner
            theme: ThemeProvider.lightTheme,
            darkTheme: ThemeProvider.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const AuthWrapper(),
          );
        },
      ),
    ),
  );
}

/// Store Firebase initialization status for services to check
Future<void> _storeFirebaseStatus(bool initialized) async {
  // This will be used by DataService to know if Firebase is available
  // We'll use SharedPreferences or a simple static variable
  FirebaseAvailability.isInitialized = initialized;
}

/// Global class to track Firebase availability
class FirebaseAvailability {
  static bool isInitialized = false;
  static bool get isAvailable => isInitialized;
}
