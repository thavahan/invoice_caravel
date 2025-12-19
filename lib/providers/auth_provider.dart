import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:logger/logger.dart';
import 'package:invoice_generator/services/database_service.dart';
import 'package:invoice_generator/services/data_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:invoice_generator/providers/invoice_provider.dart';

/// Manages authentication state using Firebase Auth
class AuthProvider with ChangeNotifier {
  FirebaseAuth? _auth;
  final Logger _logger = Logger();
  InvoiceProvider? _invoiceProvider; // Reference for login-time sync

  User? _user;
  bool _isLoading =
      true; // Start as loading until Firebase status is determined
  String? _error;
  bool _isFirebaseAvailable = false;
  String? _previousUserId; // Track previous user ID for login/logout detection
  bool _hasLoggedOut = false; // Track if user has logged out

  // Sync progress tracking
  bool _isSyncing = false;
  double _syncProgress = 0.0;
  String _syncStatus = '';
  bool _showSyncProgress = false;
  bool _syncJustCompleted = false;

  /// Current authenticated user
  User? get user => _user;

  /// Whether authentication is in progress
  bool get isLoading => _isLoading;

  /// Current error message
  String? get error => _error;

  /// Whether user is authenticated
  bool get isAuthenticated => _user != null;

  /// Whether Firebase is available for authentication
  bool get isFirebaseAvailable => _isFirebaseAvailable;

  // Sync progress getters
  bool get isSyncing => _isSyncing;
  double get syncProgress => _syncProgress;
  String get syncStatus => _syncStatus;
  bool get showSyncProgress => _showSyncProgress;
  bool get syncJustCompleted => _syncJustCompleted;

  AuthProvider() {
    print('🔥 AUTH_PROVIDER: Initializing AuthProvider');
    _initializeAuth();
  }

  /// Set InvoiceProvider reference for login-time sync
  void setInvoiceProvider(InvoiceProvider invoiceProvider) {
    _invoiceProvider = invoiceProvider;
    _logger.i('🔗 InvoiceProvider reference set for login-time sync');
  }

  Future<void> _initializeAuth() async {
    try {
      // Check if Firebase is initialized
      if (Firebase.apps.isEmpty) {
        print('🔥 AUTH_PROVIDER: Firebase not initialized, using offline mode');
        _isFirebaseAvailable = false;
        _isLoading = false;
        _user = null;

        // Set default user ID for offline mode to enable database operations
        DatabaseService().setCurrentUserId('offline_user');
        print('🔥 AUTH_PROVIDER: Set offline user ID for database operations');

        notifyListeners();
        return;
      }

      // Firebase is available, set up auth
      _auth = FirebaseAuth.instance;
      _isFirebaseAvailable = true;

      // Listen to authentication state changes
      _auth!.authStateChanges().listen(_onAuthStateChanged);

      // Add timeout to prevent hanging if Firebase doesn't respond
      Future.delayed(const Duration(seconds: 10), () {
        if (_isLoading && _user == null) {
          print('🔥 AUTH_PROVIDER: Timeout reached, forcing loading to false');
          _isLoading = false;
          notifyListeners();
        }
      });
    } catch (e) {
      print('🔥 AUTH_PROVIDER: Firebase auth initialization failed: $e');
      _isFirebaseAvailable = false;
      _isLoading = false;
      _user = null;

      // Set default user ID for offline mode to enable database operations
      DatabaseService().setCurrentUserId('offline_user');
      print('🔥 AUTH_PROVIDER: Set offline user ID due to Firebase failure');

      notifyListeners();
    }
  }

  /// Trigger login-time auto-sync using InvoiceProvider with visible loading state
  Future<void> _checkAndSyncFirebaseData(User user) async {
    try {
      _logger.i(
          '🔄 LOGIN-SYNC: Starting login-time sync check for user: ${user.email}');

      // Check internet connectivity first
      final isOnline = await _isOnline();
      _logger.i('🔄 LOGIN-SYNC: Connectivity check result: $isOnline');

      if (!isOnline) {
        _logger.i('🔄 LOGIN-SYNC: Device offline, skipping auto-sync');
        return;
      }

      _logger.i(
          '🔄 LOGIN-SYNC: Online detected, starting login-time sync for user: ${user.email}');

      // Use InvoiceProvider's login-time sync if available
      if (_invoiceProvider != null) {
        _logger.i(
            '🔄 LOGIN-SYNC: InvoiceProvider available, calling performLoginTimeSync()');
        await _invoiceProvider!.performLoginTimeSync();
        _logger.i('✅ LOGIN-SYNC: Completed using InvoiceProvider');
      } else {
        _logger
            .w('⚠️ LOGIN-SYNC: InvoiceProvider not available, skipping sync');
      }
    } catch (e) {
      _logger.w('Login-time sync failed (will continue without sync): $e');
      // Don't throw - this is a background operation
    }
  }

  /// Perform background sync without blocking UI
  void _onAuthStateChanged(User? user) async {
    print(
        '🔥 AUTH_STATE_CHANGE: user=${user?.email ?? 'null'}, uid=${user?.uid ?? 'null'}');

    final previousUserId = _user?.uid;
    final newUserId = user?.uid;

    // NO DATA CLEARING - Keep data for all users separately
    // Just log the user switch for debugging
    if (previousUserId != newUserId && previousUserId != null) {
      _logger
          .i('User switched from $previousUserId to ${newUserId ?? 'logout'}');
    }

    _user = user;
    _isLoading = false; // Auth state determined, stop loading

    // Set current user ID in database service
    DatabaseService().setCurrentUserId(newUserId);

    // Auto-sync Firebase data on login scenarios
    if (user != null && newUserId != previousUserId && previousUserId == null) {
      _logger.i('🔐 FRESH LOGIN detected - triggering login-time sync');
      _hasLoggedOut = false;
      _checkAndSyncFirebaseData(user);
    } else if (user != null &&
        newUserId != previousUserId &&
        previousUserId != null) {
      _logger.i('👤 USER SWITCH detected - triggering login-time sync');
      _hasLoggedOut = false;
      _checkAndSyncFirebaseData(user);
    } else if (user != null && _hasLoggedOut) {
      // Same user logging back in after logout
      _logger
          .i('🔄 SAME USER RE-LOGIN after logout - triggering login-time sync');
      _hasLoggedOut = false;
      _checkAndSyncFirebaseData(user);
    } else if (user != null) {
      _logger.i('🔄 APP RESTART with existing user - skipping auto-sync');
    }

    _logger.i('Auth state changed: ${user?.email ?? 'Signed out'}');
    notifyListeners();
  }

  /// Sign in with email and password
  Future<bool> signIn(String email, String password) async {
    if (_auth == null || !_isFirebaseAvailable) {
      _error =
          'Authentication not available. Please check your internet connection and try again.';
      _logger.w('Sign in attempted but Firebase not available');
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      _logger.i('User signed in: ${result.user?.email}');
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getErrorMessage(e);
      _logger.e('Sign in error: $e');
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _logger.e('Unexpected sign in error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Register new user with email and password
  Future<bool> register(String email, String password) async {
    if (_auth == null || !_isFirebaseAvailable) {
      _error =
          'Registration not available. Please check your internet connection and try again.';
      _logger.w('Registration attempted but Firebase not available');
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _auth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      _logger.i('User registered: ${result.user?.email}');
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getErrorMessage(e);
      _logger.e('Registration error: $e');
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _logger.e('Unexpected registration error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      // DO NOT clear local data on logout - keep it for next login
      final userId = _user?.uid;
      if (userId != null) {
        _logger
            .i('User logging out: $userId (keeping local data for next login)');

        // Set logout flag so next login will trigger auto-sync
        _hasLoggedOut = true;
        _logger.i('🔓 Set logout flag - next login will trigger auto-sync');

        // Reset login sync flag so next login will trigger auto-sync
        if (_invoiceProvider != null) {
          _invoiceProvider!.resetLoginSyncFlag();
          _logger.i('🔓 Reset login sync flag for next login');
        }
      }

      if (_auth == null || !_isFirebaseAvailable) {
        // If Firebase not available, just clear local user state
        _user = null;
        DatabaseService().setCurrentUserId(null);
        _logger.i('Signed out locally (Firebase not available)');
        notifyListeners();
        return;
      }

      await _auth!.signOut();
      DatabaseService().setCurrentUserId(null);
      _logger.i('User signed out and local data cleared');
    } catch (e) {
      _logger.e('Sign out error: $e');
      _error = 'Failed to sign out';
      notifyListeners();
    }
  }

  /// Send password reset email
  Future<bool> resetPassword(String email) async {
    if (_auth == null || !_isFirebaseAvailable) {
      _error =
          'Password reset not available. Please check your internet connection and try again.';
      _logger.w('Password reset attempted but Firebase not available');
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _auth!.sendPasswordResetEmail(email: email.trim());
      _logger.i('Password reset email sent to: $email');
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getErrorMessage(e);
      _logger.e('Password reset error: $e');
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
      _logger.e('Unexpected password reset error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear current error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Convert Firebase Auth exceptions to user-friendly messages
  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password is too weak. Please choose a stronger password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  /// Check if device is online
  Future<bool> _isOnline() async {
    try {
      final connectivity = Connectivity();
      final results = await connectivity.checkConnectivity();

      // Check if any connection is available
      final hasConnection = results.isNotEmpty &&
          results.any((result) => result != ConnectivityResult.none);

      _logger
          .i('📶 Connectivity check: $hasConnection (${results.join(', ')})');
      return hasConnection;
    } catch (e) {
      _logger.w('Failed connectivity check, assuming offline: $e');
      return false;
    }
  }

  /// Update sync progress and notify listeners
  void _updateSyncProgress(double progress, String status, bool show) {
    _syncProgress = progress;
    _syncStatus = status;
    _showSyncProgress = show;
    _isSyncing = show && progress < 100.0;

    // Mark sync as completed when progress reaches 100%
    if (progress >= 100.0 && show) {
      _syncJustCompleted = true;
    }

    notifyListeners();
  }

  /// Reset sync completion flag (call this from UI after handling the completion)
  void clearSyncCompletedFlag() {
    _syncJustCompleted = false;
    notifyListeners();
  }

  /// Perform sync with detailed progress tracking
  Future<void> _performSyncWithProgress(String userEmail) async {
    try {
      _updateSyncProgress(0.0, 'Initializing sync...', true);

      // Initialize the DataService
      final dataService = DataService();

      _updateSyncProgress(10.0, 'Connecting to Firebase...', true);

      // Initialize Firebase user collections first
      await dataService.initializeUserCollections();

      _updateSyncProgress(20.0, 'Starting data synchronization...', true);

      // Perform the actual sync with progress callbacks
      await dataService.syncFromFirebaseToLocal(
        onProgress: (status) {
          // Update progress based on sync status
          if (status.contains('master data')) {
            _updateSyncProgress(40.0, status, true);
          } else if (status.contains('shipments')) {
            _updateSyncProgress(70.0, status, true);
          } else if (status.contains('drafts')) {
            _updateSyncProgress(85.0, status, true);
          } else if (status.contains('completed')) {
            _updateSyncProgress(100.0, status, true);
          } else if (status.contains('failed')) {
            _updateSyncProgress(0.0, status, true);
          } else {
            _updateSyncProgress(60.0, status, true);
          }
        },
      );

      _updateSyncProgress(100.0, 'Sync completed successfully!', true);

      // Hide progress after 2 seconds
      Future.delayed(Duration(seconds: 2), () {
        _updateSyncProgress(0.0, '', false);
      });

      _logger.i('✅ AUTO-SYNC: Sync completed successfully for: $userEmail');
    } catch (e) {
      _logger.w('❌ AUTO-SYNC: Sync failed for $userEmail: $e');
      _updateSyncProgress(0.0, 'Sync failed: ${e.toString()}', true);

      // Hide error after 3 seconds
      Future.delayed(Duration(seconds: 3), () {
        _updateSyncProgress(0.0, '', false);
      });
    }
  }
}
