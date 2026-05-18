import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:epubx/epubx.dart' as epub;
import 'package:archive/archive.dart';
import '../services/github_service.dart';
import 'widgets/eink_flash.dart';

class ReaderScreen extends StatefulWidget {
  final GitHubService githubService;
  final String bookName;
  final String downloadUrl;

  const ReaderScreen({
    super.key,
    required this.githubService,
    required this.bookName,
    required this.downloadUrl,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  int _currentPage = 1;
  int _pageChangesSinceRefresh = 0;
  bool _isFlashing = false;
  bool _isLoading = true;
  String? _syncSha;
  Map<String, dynamic> _fullSyncData = {};
  String _extractedText = "Cargando contenido...";
  PdfDocument? _pdfDocument;
  epub.EpubBook? _epubBook;
  List<epub.EpubChapter> _flatChapters = [];
  Timer? _debounceTimer;
  bool _isSaving = false;
  double _fontSize = 18.0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _loadPreferences();
  }

  void _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontSize = prefs.getDouble('font_size') ?? 18.0;
    });
  }

  void _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size', _fontSize);
  }

  List<int> _sanitizeEpubBytes(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final newArchive = Archive();
      bool modified = false;

      for (final file in archive) {
        if (file.isFile && (file.name.endsWith('.opf') || file.name.endsWith('.ncx'))) {
          final contentBytes = file.content as List<int>;
          final contentString = utf8.decode(contentBytes);

          final decodedContent = contentString.replaceAllMapped(
            RegExp(r'(href|src)="([^"]+)"'),
            (match) {
              final attr = match.group(1);
              final val = match.group(2)!;
              try {
                final decodedVal = Uri.decodeFull(val);
                return '$attr="$decodedVal"';
              } catch (_) {
                return match.group(0)!;
              }
            },
          );

          if (decodedContent != contentString) {
            final newContentBytes = utf8.encode(decodedContent);
            final newFile = ArchiveFile(
              file.name,
              newContentBytes.length,
              newContentBytes,
            );
            newArchive.addFile(newFile);
            modified = true;
          } else {
            newArchive.addFile(file);
          }
        } else {
          newArchive.addFile(file);
        }
      }

      if (modified) {
        final encodedBytes = ZipEncoder().encode(newArchive);
        if (encodedBytes != null) {
          return encodedBytes;
        }
      }
    } catch (e) {
      debugPrint("Error sanitizing EPUB bytes: $e");
    }
    return bytes;
  }

  List<epub.EpubChapter> _flattenChapters(List<epub.EpubChapter> chapters) {
    final list = <epub.EpubChapter>[];
    for (final chapter in chapters) {
      list.add(chapter);
      if (chapter.SubChapters != null && chapter.SubChapters!.isNotEmpty) {
        list.addAll(_flattenChapters(chapter.SubChapters!));
      }
    }
    return list;
  }

  void _loadProgress() async {
    try {
      // 1. Cargar progreso
      final syncResult = await widget.githubService.getSyncData();
      _fullSyncData = Map<String, dynamic>.from(syncResult['data']);
      _syncSha = syncResult['sha'];
      
      if (_fullSyncData.containsKey(widget.bookName)) {
        _currentPage = _fullSyncData[widget.bookName]['page'] ?? 1;
      }

      // 2. Descargar y procesar según extensión
      final bytes = await widget.githubService.downloadFile(widget.downloadUrl);
      final fileName = widget.bookName.toLowerCase();

      if (fileName.endsWith(".pdf")) {
        _pdfDocument = PdfDocument(inputBytes: bytes);
        _extractPageText();
      } else if (fileName.endsWith(".epub")) {
        final sanitizedBytes = _sanitizeEpubBytes(bytes);
        _epubBook = await epub.EpubReader.readBook(sanitizedBytes);
        _flatChapters = _flattenChapters(_epubBook!.Chapters ?? []);
        _extractEpubText();
      } else if (fileName.endsWith(".mobi")) {
        _extractedText = "El formato MOBI es antiguo. Por favor, convierte este archivo a EPUB o PDF para usar Reflow en Anima.";
      } else {
        _extractedText = "Formato no soportado para Reflow aún.";
      }
    } catch (e) {
      debugPrint("Sync error: $e");
      _extractedText = "Error al cargar el libro: $e";
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _extractPageText() {
    if (_pdfDocument == null) return;
    try {
      // Validar rangos de página
      int pageIndex = (_currentPage - 1).clamp(0, _pdfDocument!.pages.count - 1);
      _extractedText = PdfTextExtractor(_pdfDocument!).extractText(
        startPageIndex: pageIndex,
        endPageIndex: pageIndex,
      );
      if (_extractedText.trim().isEmpty) {
        _extractedText = "Página sin texto extraíble (posible imagen).";
      }
    } catch (e) {
      _extractedText = "Error al extraer texto: $e";
    }
  }

  void _extractEpubText() {
    if (_epubBook == null || _flatChapters.isEmpty) return;
    try {
      // Usamos la página como índice de capítulo
      int chapterIndex = (_currentPage - 1).clamp(0, _flatChapters.length - 1);
      final chapter = _flatChapters[chapterIndex];
      // Limpiamos tags HTML básicos
      _extractedText = (chapter.HtmlContent ?? '')
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&nbsp;', ' ')
          .trim();
      
      if (_extractedText.isEmpty) {
        _extractedText = "Capítulo sin texto o con formato complejo.";
      }
    } catch (e) {
      _extractedText = "Error al leer EPUB: $e";
    }
  }

  @override
  void dispose() {
    _pdfDocument?.dispose();
    _debounceTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _saveProgress() async {
    if (_isSaving) return; // Evitar llamadas concurrentes
    _isSaving = true;
    
    _fullSyncData[widget.bookName] = {
      'page': _currentPage,
      'timestamp': DateTime.now().toIso8601String(),
    };
    try {
      final newSha = await widget.githubService.updateSync(_fullSyncData, _syncSha);
      _syncSha = newSha;
      debugPrint("Progreso guardado: Página $_currentPage");
    } catch (e) {
      debugPrint("Save error: $e");
      // Re-sincronizar SHA en caso de error
      final syncResult = await widget.githubService.getSyncData();
      _syncSha = syncResult['sha'];
    } finally {
      _isSaving = false;
    }
  }

  void _handlePageChange(int delta) {
    if (delta > 0) {
      // Intentar scroll hacia abajo primero
      if (_scrollController.hasClients && 
          _scrollController.offset < _scrollController.position.maxScrollExtent - 10) {
        _scrollController.jumpTo(
          _scrollController.offset + MediaQuery.of(context).size.height * 0.7,
        );
        return;
      }
    } else {
      // Intentar scroll hacia arriba primero
      if (_scrollController.hasClients && _scrollController.offset > 10) {
        _scrollController.jumpTo(
          _scrollController.offset - MediaQuery.of(context).size.height * 0.7,
        );
        return;
      }
    }

    // Si llegamos al borde, cambiamos de página/capítulo
    setState(() {
      int maxPages = 9999;
      if (_pdfDocument != null) maxPages = _pdfDocument!.pages.count;
      if (_epubBook != null) maxPages = _flatChapters.length;

      _currentPage = (_currentPage + delta).clamp(1, maxPages);
      _pageChangesSinceRefresh++;
      
      if (_pdfDocument != null) _extractPageText();
      if (_epubBook != null) _extractEpubText();
      
      // Resetear scroll al inicio de la nueva página
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }

      if (_pageChangesSinceRefresh >= 10) {
        _triggerFlash();
      }
    });

    // Debouncer: Esperar 10 segundos de inactividad antes de guardar
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 10), () {
      _saveProgress();
    });
  }

  void _triggerFlash() async {
    setState(() => _isFlashing = true);
    await Future.delayed(const Duration(milliseconds: 200));
    setState(() {
      _isFlashing = false;
      _pageChangesSinceRefresh = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookName, overflow: TextOverflow.ellipsis),
        actions: [
          // Selector de tamaño de fuente
          const Icon(Icons.format_size, size: 16),
          SizedBox(
            width: 100,
            child: Slider(
              value: _fontSize,
              min: 12.0,
              max: 32.0,
              divisions: 10,
              activeColor: Colors.black,
              inactiveColor: Colors.grey[300],
              onChanged: (value) {
                setState(() => _fontSize = value);
                _savePreferences();
              },
            ),
          ),
          Center(child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text("P. $_currentPage"),
          ))
        ],
      ),
      body: Stack(
        children: [
          _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.black))
            : _buildReaderContent(),
          EinkFlash(visible: _isFlashing),
        ],
      ),
    );
  }

  Widget _buildReaderContent() {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTapUp: (details) {
              final width = MediaQuery.of(context).size.width;
              if (details.globalPosition.dx > width * 0.7) {
                _handlePageChange(1);
              } else if (details.globalPosition.dx < width * 0.3) {
                _handlePageChange(-1);
              }
            },
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const ClampingScrollPhysics(), // Mejor para E-ink
                child: Text(
                  _extractedText,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: _fontSize,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Barra de navegación inferior estática
        Container(
          height: 60,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Colors.black)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(onPressed: () => _handlePageChange(-1), icon: const Icon(Icons.arrow_back_ios)),
              Text("$_currentPage / ..."),
              IconButton(onPressed: () => _handlePageChange(1), icon: const Icon(Icons.arrow_forward_ios)),
            ],
          ),
        )
      ],
    );
  }
}
