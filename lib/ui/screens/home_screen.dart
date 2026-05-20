import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/strings.dart';
import '../../models/book.dart';
import '../../models/app_exception.dart';
import '../../services/github_service.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/empty_library.dart';
import 'reader_screen.dart';
import 'settings_screen.dart';

/// Main screen showing the setup form or the book library list.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _patController = TextEditingController();
  final _ownerController = TextEditingController();
  final _repoController = TextEditingController();

  GitHubService? _githubService;
  List<Book> _books = [];
  bool _isLoading = false;
  bool _showHelp = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  @override
  void dispose() {
    _patController.dispose();
    _ownerController.dispose();
    _repoController.dispose();
    super.dispose();
  }

  void _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _patController.text = prefs.getString('gh_pat') ?? '';
      _ownerController.text = prefs.getString('gh_owner') ?? '';
      _repoController.text = prefs.getString('gh_repo') ?? '';
    });
    if (_patController.text.isNotEmpty) {
      _fetchBooks();
    }
  }

  void _fetchBooks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gh_pat', _patController.text.trim());
    await prefs.setString('gh_owner', _ownerController.text.trim());
    await prefs.setString('gh_repo', _repoController.text.trim());

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = GitHubService(
        pat: _patController.text.trim(),
        owner: _ownerController.text.trim(),
        repo: _repoController.text.trim(),
      );
      final books = await service.fetchBooks();
      if (!mounted) return;
      setState(() {
        _githubService = service;
        _books = books;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final appError = AppException.from(e);
      setState(() {
        _isLoading = false;
        _errorMessage = appError.message;
      });
    }
  }

  void _disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gh_pat');
    await prefs.remove('gh_owner');
    await prefs.remove('gh_repo');
    if (!mounted) return;
    setState(() {
      _githubService = null;
      _books = [];
      _patController.clear();
      _ownerController.clear();
      _repoController.clear();
    });
  }

  void _openSettings() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, _, __) => SettingsScreen(onDisconnect: _disconnect),
        transitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(S.libraryTitle),
        actions: [
          if (_githubService != null)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: _openSettings,
              tooltip: S.settingsTitle,
            ),
        ],
      ),
      body: _githubService == null ? _buildSetup() : _buildBookList(),
    );
  }

  // ─── Setup Form ───

  Widget _buildSetup() {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            S.setupTitle,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Serif',
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            S.setupSubtitle,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 25),
          _buildTextField(_patController, S.fieldPat, theme),
          const SizedBox(height: 15),
          _buildTextField(_ownerController, S.fieldOwner, theme),
          const SizedBox(height: 15),
          _buildTextField(_repoController, S.fieldRepo, theme),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.error, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _fetchBooks,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.onSurface,
              foregroundColor: theme.colorScheme.surface,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              side: BorderSide(color: theme.colorScheme.onSurface, width: 2),
            ),
            child: _isLoading
                ? const Text(S.loadingBook, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))
                : const Text(S.buttonConnect, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(height: 25),
          OutlinedButton.icon(
            onPressed: () => setState(() => _showHelp = !_showHelp),
            icon: Icon(
              _showHelp ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: theme.colorScheme.onSurface,
            ),
            label: Text(
              _showHelp ? S.buttonHideHelp : S.buttonShowHelp,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.colorScheme.onSurface, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
          ),
          if (_showHelp) ...[
            const SizedBox(height: 15),
            _buildHelpBox(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, ThemeData theme) {
    return TextField(
      controller: controller,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.onSurface, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
        ),
        labelStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
      ),
    );
  }

  Widget _buildHelpBox(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.onSurface, width: 2),
        color: theme.colorScheme.surface,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHelpStep(S.helpStep1Title, S.helpStep1Body, theme),
          const SizedBox(height: 12),
          _buildHelpStep(S.helpStep2Title, S.helpStep2Body, theme),
          const SizedBox(height: 12),
          _buildHelpStep(S.helpStep3Title, S.helpStep3Body, theme),
          const SizedBox(height: 12),
          _buildHelpStep(S.helpStep4Title, S.helpStep4Body, theme),
        ],
      ),
    );
  }

  Widget _buildHelpStep(String title, String body, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            fontFamily: 'Serif',
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  // ─── Book List ───

  Widget _buildBookList() {
    if (_isLoading) {
      return const LoadingIndicator();
    }

    if (_books.isEmpty) {
      return EmptyLibrary(onRefresh: _fetchBooks);
    }

    return ListView.separated(
      physics: const ClampingScrollPhysics(),
      itemCount: _books.length,
      separatorBuilder: (_, __) => Divider(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
        height: 1,
      ),
      itemBuilder: (context, index) {
        final book = _books[index];
        return ListTile(
          title: Text(book.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
            '${book.extension.toUpperCase()} · ${book.formattedSize}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, _, __) => ReaderScreen(
                  githubService: _githubService!,
                  book: book,
                ),
                transitionDuration: Duration.zero,
              ),
            );
          },
        );
      },
    );
  }
}
