import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ui/theme.dart';
import 'ui/screens/home_screen.dart';

void main() {
  runApp(const AnimaApp());
}

class AnimaApp extends StatefulWidget {
  const AnimaApp({super.key});

  /// Provides access to the app state from anywhere in the widget tree.
  static AnimaAppState of(BuildContext context) {
    return context.findAncestorStateOfType<AnimaAppState>()!;
  }

  @override
  State<AnimaApp> createState() => AnimaAppState();
}

class AnimaAppState extends State<AnimaApp> {
  AppThemeMode _themeMode = AppThemeMode.normal;

  AppThemeMode get themeMode => _themeMode;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  void setThemeMode(AppThemeMode mode) {
    setState(() => _themeMode = mode);
    _saveThemePreference(mode);
  }

  void _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('theme_mode');
    if (stored != null) {
      final mode = AppThemeMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => AppThemeMode.normal,
      );
      setState(() => _themeMode = mode);
    }
  }

  void _saveThemePreference(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anima Reader',
      theme: AppTheme.forMode(_themeMode),
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
