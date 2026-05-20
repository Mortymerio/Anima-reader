import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/strings.dart';
import '../../main.dart';
import '../theme.dart';

/// Settings screen for theme selection, E-ink tuning, and account management.
class SettingsScreen extends StatefulWidget {
  final VoidCallback onDisconnect;

  const SettingsScreen({super.key, required this.onDisconnect});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _refreshInterval = 10;
  double _margin = 8.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _refreshInterval = prefs.getInt('eink_refresh_interval') ?? 10;
      _margin = prefs.getDouble('reader_margin') ?? 8.0;
    });
  }

  void _saveRefreshInterval(int value) async {
    setState(() => _refreshInterval = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('eink_refresh_interval', value);
  }

  void _saveMargin(double value) async {
    setState(() => _margin = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('reader_margin', value);
  }

  void _showDisconnectDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text(S.settingsDisconnect, style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Text(
          S.settingsDisconnectConfirm,
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.buttonCancel, style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDisconnect();
              Navigator.pop(context);
            },
            child: Text(
              S.buttonDisconnect,
              style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = AnimaApp.of(context);
    final currentTheme = appState.themeMode;

    return Scaffold(
      appBar: AppBar(title: const Text(S.settingsTitle)),
      body: ListView(
        physics: const ClampingScrollPhysics(),
        children: [
          // ─── Theme Selection ───
          _buildSectionHeader(S.settingsTheme, theme),
          _buildThemeOption(
            S.settingsThemeNormal,
            Icons.wb_sunny_outlined,
            AppThemeMode.normal,
            currentTheme,
            appState,
            theme,
          ),
          _buildThemeOption(
            S.settingsThemeDark,
            Icons.dark_mode_outlined,
            AppThemeMode.dark,
            currentTheme,
            appState,
            theme,
          ),
          _buildThemeOption(
            S.settingsThemeWarm,
            Icons.remove_red_eye_outlined,
            AppThemeMode.warm,
            currentTheme,
            appState,
            theme,
          ),

          Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),

          // ─── E-ink Refresh Interval ───
          _buildSectionHeader(S.settingsRefreshInterval, theme),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '$_refreshInterval ${S.settingsRefreshPages}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _refreshInterval > 3
                      ? () => _saveRefreshInterval(_refreshInterval - 1)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _refreshInterval < 30
                      ? () => _saveRefreshInterval(_refreshInterval + 1)
                      : null,
                ),
              ],
            ),
          ),

          Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),

          // ─── Default Reading Margin ───
          _buildSectionHeader(S.settingsDefaultMargin, theme),
          _buildMarginOption(S.settingsMarginNone, 0.0, _margin, theme),
          _buildMarginOption(S.settingsMarginSmall, 8.0, _margin, theme),
          _buildMarginOption(S.settingsMarginMedium, 16.0, _margin, theme),
          _buildMarginOption(S.settingsMarginLarge, 24.0, _margin, theme),

          Divider(color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),

          // ─── Disconnect ───
          ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text(
              S.settingsDisconnect,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: _showDisconnectDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    String label,
    IconData icon,
    AppThemeMode mode,
    AppThemeMode currentMode,
    AnimaAppState appState,
    ThemeData theme,
  ) {
    final isSelected = mode == currentMode;
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: isSelected
          ? Icon(Icons.check, color: theme.colorScheme.onSurface)
          : null,
      selected: isSelected,
      onTap: () => appState.setThemeMode(mode),
    );
  }

  Widget _buildMarginOption(
    String label,
    double value,
    double currentValue,
    ThemeData theme,
  ) {
    final isSelected = value == currentValue;
    return ListTile(
      title: Text(label),
      trailing: isSelected
          ? Icon(Icons.check, color: theme.colorScheme.onSurface)
          : null,
      selected: isSelected,
      onTap: () => _saveMargin(value),
    );
  }
}
