import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/github_service.dart';
import 'reader_screen.dart';

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
  List<Map<String, dynamic>> _books = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  void _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
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
    await prefs.setString('gh_pat', _patController.text);
    await prefs.setString('gh_owner', _ownerController.text);
    await prefs.setString('gh_repo', _repoController.text);

    setState(() => _isLoading = true);
    try {
      final service = GitHubService(
        pat: _patController.text,
        owner: _ownerController.text,
        repo: _repoController.text,
      );
      final books = await service.fetchBooks();
      setState(() {
        _githubService = service;
        _books = books;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Anima Library")),
      body: _githubService == null ? _buildSetup() : _buildBookList(),
    );
  }

  Widget _buildSetup() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          TextField(controller: _patController, decoration: const InputDecoration(labelText: "GitHub PAT")),
          TextField(controller: _ownerController, decoration: const InputDecoration(labelText: "Owner")),
          TextField(controller: _repoController, decoration: const InputDecoration(labelText: "Repo Name")),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _fetchBooks,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
            child: const Text("Connect"),
          ),
        ],
      ),
    );
  }

  Widget _buildBookList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.black));
    
    return ListView.separated(
      itemCount: _books.length,
      separatorBuilder: (_, __) => const Divider(color: Colors.black, height: 1),
      itemBuilder: (context, index) {
        final book = _books[index];
        return ListTile(
          title: Text(book['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, _, __) => ReaderScreen(
                  githubService: _githubService!,
                  bookName: book['name'],
                  downloadUrl: book['download_url'],
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
