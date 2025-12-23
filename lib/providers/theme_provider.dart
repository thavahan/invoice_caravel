import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool _isDisposed = false;
  static const String _themeKey = 'theme_preference';

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  /// Override notifyListeners to prevent notifications after disposal
  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  /// Dispose method to mark the provider as disposed
  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// Initialize theme from saved preferences
  Future<void> initTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_themeKey) ?? false;
      notifyListeners();
    } catch (e) {
      print('🎨 THEME_PROVIDER: Failed to load theme preference: $e');
      _isDarkMode = false; // Default to light theme
    }
  }

  /// Toggle theme and save preference
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    await _saveThemePreference();
  }

  /// Set theme and save preference
  Future<void> setTheme(bool isDark) async {
    _isDarkMode = isDark;
    notifyListeners();
    await _saveThemePreference();
  }

  /// Save theme preference to persistent storage
  Future<void> _saveThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, _isDarkMode);
      print(
          '🎨 THEME_PROVIDER: Theme preference saved: ${_isDarkMode ? 'dark' : 'light'}');
    } catch (e) {
      print('🎨 THEME_PROVIDER: Failed to save theme preference: $e');
    }
  }

  // Gmail-like Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primarySwatch: Colors.blue,
      primaryColor: Colors.blue[600],
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shadowColor: Colors.grey.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: Colors.black87,
        iconColor: Color(0xFF757575), // Proper grey for light theme
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Color(0xFF757575), // Consistent grey
        elevation: 8,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5F5), // Proper light grey fill
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: Color(0xFFE0E0E0)), // Proper border
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue[600]!),
        ),
      ),
      colorScheme: ColorScheme.light(
        primary: Colors.blue[600]!,
        secondary: Colors.blue[100]!,
        surface: Colors.white, // Consistent light grey
        error: Colors.red[600]!,
      ),
    );
  }

  // Gmail-like Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primarySwatch: Colors.blue,
      primaryColor: Colors.blue[400],
      scaffoldBackgroundColor: const Color(0xFF121212), // Gmail dark background
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E), // Gmail app bar
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Color(0xFF1E1E1E),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E), // Gmail card background
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: Colors.white,
        iconColor: Color(0xFFB3B3B3), // Gmail secondary text
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1E1E1E),
        selectedItemColor: Colors.blue,
        unselectedItemColor: Color(0xFFB3B3B3),
        elevation: 8,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Colors.blue[400],
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2D2D2D), // Gmail input background
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: Color(0xFF424242)), // Gmail border
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF424242)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue[400]!),
        ),
        labelStyle: const TextStyle(color: Colors.white),
        hintStyle: const TextStyle(color: Color(0xFFB3B3B3)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1E1E1E),
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: const Color(0xFF424242), // Gmail divider
      iconTheme: const IconThemeData(
        color: Color(0xFFB3B3B3),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: Colors.white),
        displayMedium: TextStyle(color: Colors.white),
        displaySmall: TextStyle(color: Colors.white),
        headlineLarge: TextStyle(color: Colors.white),
        headlineMedium: TextStyle(color: Colors.white),
        headlineSmall: TextStyle(color: Colors.white),
        titleLarge: TextStyle(color: Colors.white),
        titleMedium: TextStyle(color: Colors.white),
        titleSmall: TextStyle(color: Colors.white),
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: Color(0xFFB3B3B3)),
        labelLarge: TextStyle(color: Colors.white),
        labelMedium: TextStyle(color: Colors.white),
        labelSmall: TextStyle(color: Color(0xFFB3B3B3)),
      ),
      colorScheme: ColorScheme.dark(
        primary: Colors.blue[400]!,
        secondary: Colors.blue[200]!,
        surface: const Color(0xFF1E1E1E),
        error: Colors.red[400]!,
        onPrimary: Colors.white,
        onSecondary: const Color(0xFF121212),
        onSurface: Colors.white,
        onError: Colors.white,
        primaryContainer: const Color(0xFF1E3A5F), // Dark blue container
        secondaryContainer: const Color(0xFF2D2D2D), // Dark gray container
        surfaceContainerHighest: const Color(0xFF2D2D2D), // Highest surface
        errorContainer: const Color(0xFF5C2B2B), // Dark red container
        onErrorContainer: Colors.white,
        onPrimaryContainer: Colors.white,
        onSecondaryContainer: Colors.white,
        onSurfaceVariant: const Color(0xFFB3B3B3),
        outline: const Color(0xFF424242),
        outlineVariant: const Color(0xFF424242),
        scrim: Colors.black.withOpacity(0.32),
        shadow: Colors.black,
        surfaceTint: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(backgroundColor: const Color(0xFF1E1E1E)),
    );
  }
}
