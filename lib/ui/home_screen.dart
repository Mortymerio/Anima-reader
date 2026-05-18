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
  bool _showHelp = false;

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
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Configura tu Biblioteca de Tinta",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Serif'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Conecta tu cuenta de GitHub para sincronizar tus libros y progreso de lectura.",
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 25),
          TextField(
            controller: _patController,
            decoration: const InputDecoration(
              labelText: "GitHub PAT (Token de Acceso)",
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2)),
              labelStyle: TextStyle(color: Colors.black),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _ownerController,
            decoration: const InputDecoration(
              labelText: "Usuario de GitHub (Owner)",
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2)),
              labelStyle: TextStyle(color: Colors.black),
            ),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _repoController,
            decoration: const InputDecoration(
              labelText: "Nombre del Repositorio",
              border: OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2)),
              labelStyle: TextStyle(color: Colors.black),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _fetchBooks,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              side: const BorderSide(color: Colors.black, width: 2),
            ),
            child: const Text("CONECTAR BIBLIOTECA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(height: 25),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _showHelp = !_showHelp;
              });
            },
            icon: Icon(_showHelp ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.black),
            label: Text(
              _showHelp ? "OCULTAR GUÍA DE AYUDA" : "¿CÓMO CONFIGURAR MI BIBLIOTECA?",
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.black, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
          ),
          if (_showHelp) ...[
            const SizedBox(height: 15),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
                color: Colors.white,
              ),
              padding: const EdgeInsets.all(16),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "PASO 1: Crear Repositorio",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Serif'),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Crea un repositorio en GitHub (ej: 'mis-libros'). Márcalo como PRIVADO e inicialízalo con un archivo README (casilla obligatoria).",
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "PASO 2: Generar tu Token (PAT)",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Serif'),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Ve a Settings -> Developer Settings -> Personal Access Tokens -> Tokens (classic).\nGenera un token nuevo con permisos de 'repo' y cópialo.",
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "PASO 3: Subir tus Libros",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Serif'),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Sube tus archivos .epub o .pdf directamente en la raíz (root) del repositorio. No los guardes dentro de carpetas.",
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  SizedBox(height: 12),
                  Text(
                    "PASO 4: Conectar",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Serif'),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Ingresa los datos arriba y presiona Conectar. El archivo 'sync.json' se creará de forma automática al empezar a leer.",
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
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
