import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
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
  List<Widget> _pageContent = [const Text("Cargando contenido...")];
  PdfDocument? _pdfDocument;
  pdfx.PdfDocument? _pdfxDocument;
  bool _forceOriginalPdfPage = false;
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
        _pdfxDocument = await pdfx.PdfDocument.openData(Uint8List.fromList(bytes));
        _extractPageText();
      } else if (fileName.endsWith(".epub")) {
        final sanitizedBytes = _sanitizeEpubBytes(bytes);
        _epubBook = await epub.EpubReader.readBook(sanitizedBytes);
        _flatChapters = _flattenChapters(_epubBook!.Chapters ?? []);
        _extractEpubText();
      } else if (fileName.endsWith(".mobi")) {
        _pageContent = [const Text("El formato MOBI es antiguo. Por favor, convierte este archivo a EPUB o PDF para usar Reflow en Anima.")];
      } else {
        _pageContent = [const Text("Formato no soportado para Reflow aún.")];
      }
    } catch (e) {
      debugPrint("Sync error: $e");
      _pageContent = [Text("Error al cargar el libro: $e")];
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _extractPageText() async {
    if (_pdfDocument == null) return;
    try {
      // Validar rangos de página
      int pageIndex = (_currentPage - 1).clamp(0, _pdfDocument!.pages.count - 1);
      String text = PdfTextExtractor(_pdfDocument!).extractText(
        startPageIndex: pageIndex,
        endPageIndex: pageIndex,
      );
      
      bool renderAsImage = _forceOriginalPdfPage || text.trim().isEmpty;
      
      if (renderAsImage && _pdfxDocument != null) {
        setState(() {
          _pageContent = [const Padding(
            padding: EdgeInsets.all(40.0),
            child: Center(child: CircularProgressIndicator(color: Colors.black)),
          )];
        });
        
        final page = await _pdfxDocument!.getPage(pageIndex + 1); // pdfx usa índice base 1
        final pageImage = await page.render(
          width: page.width * 2.0, // 2x para resolución óptima
          height: page.height * 2.0,
          format: pdfx.PdfPageImageFormat.jpeg,
        );
        await page.close();
        
        if (pageImage != null) {
          setState(() {
            _pageContent = [
              Image.memory(
                pageImage.bytes,
                fit: BoxFit.contain,
              )
            ];
          });
        } else {
          setState(() {
            _pageContent = [const Text("Error al renderizar la imagen de la página.")];
          });
        }
      } else {
        setState(() {
          _pageContent = [
            Text(text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: _fontSize))
          ];
        });
      }
    } catch (e) {
      setState(() {
        _pageContent = [Text("Error al procesar página: $e")];
      });
    }
  }

  void _extractEpubText() {
    if (_epubBook == null || _flatChapters.isEmpty) return;
    try {
      // Usamos la página como índice de capítulo
      int chapterIndex = (_currentPage - 1).clamp(0, _flatChapters.length - 1);
      final chapter = _flatChapters[chapterIndex];
      final html = chapter.HtmlContent ?? '';
      
      List<Widget> widgets = [];

      // Si es la página 1, intentamos mostrar la portada primero
      if (_currentPage == 1 && _epubBook!.Content?.Images != null) {
        epub.EpubByteContentFile? coverFile;
        // Buscamos un archivo que parezca la portada
        _epubBook!.Content!.Images!.forEach((key, value) {
          if (key.toLowerCase().contains('cover')) {
            coverFile = value;
          }
        });
        if (coverFile != null && coverFile!.Content != null) {
          widgets.add(Image.memory(
            Uint8List.fromList(coverFile!.Content!),
            fit: BoxFit.contain,
          ));
          widgets.add(const SizedBox(height: 24));
        }
      }
      
      // Expresión regular para encontrar etiquetas <img>
      final imgRegex = RegExp(r'<img[^>]+src="([^"]+)"[^>]*>', caseSensitive: false);
      final matches = imgRegex.allMatches(html);
      
      int lastIndex = 0;
      for (final match in matches) {
        // Texto antes de la imagen
        final textBefore = html.substring(lastIndex, match.start)
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .replaceAll('&nbsp;', ' ')
            .trim();
            
        if (textBefore.isNotEmpty) {
          widgets.add(Text(textBefore, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: _fontSize)));
          widgets.add(const SizedBox(height: 16));
        }
        
        // Imagen
        final src = match.group(1)!;
        final imageName = src.split('/').last; // Nombre del archivo de imagen
        
        epub.EpubByteContentFile? imageFile;
        _epubBook!.Content?.Images?.forEach((key, value) {
          if (key.endsWith(imageName) || imageName.endsWith(key)) {
            imageFile = value;
          }
        });
        
        if (imageFile != null && imageFile!.Content != null) {
           widgets.add(Image.memory(
             Uint8List.fromList(imageFile!.Content!),
             fit: BoxFit.contain,
           ));
           widgets.add(const SizedBox(height: 16));
        }
        
        lastIndex = match.end;
      }
      
      // Texto restante después de la última imagen
      final textAfter = html.substring(lastIndex)
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&nbsp;', ' ')
          .trim();
          
      if (textAfter.isNotEmpty) {
        widgets.add(Text(textAfter, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: _fontSize)));
      }
      
      if (widgets.isEmpty) {
        widgets.add(Text("Capítulo sin texto o con formato complejo.", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: _fontSize)));
      }

      setState(() {
        _pageContent = widgets;
      });
    } catch (e) {
      setState(() {
        _pageContent = [Text("Error al leer EPUB: $e")];
      });
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

  void _changeFontSize(double amount, {bool isAbsolute = false}) {
    setState(() {
      _fontSize = isAbsolute ? amount : (_fontSize + amount).clamp(12.0, 32.0);
    });
    _savePreferences();
    if (_pdfDocument != null) {
      _extractPageText();
    } else if (_epubBook != null) {
      _extractEpubText();
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
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _handlePageChange(1);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _handlePageChange(-1);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _changeFontSize(2.0);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _changeFontSize(-2.0);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        appBar: AppBar(
        title: Text(widget.bookName, overflow: TextOverflow.ellipsis),
        actions: [
          if (_pdfDocument != null)
            IconButton(
              icon: Icon(_forceOriginalPdfPage ? Icons.text_fields : Icons.image),
              onPressed: () {
                setState(() {
                  _forceOriginalPdfPage = !_forceOriginalPdfPage;
                });
                _extractPageText();
              },
              tooltip: "Alternar vista original/texto",
            ),
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
                _changeFontSize(value, isAbsolute: true);
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _pageContent,
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
