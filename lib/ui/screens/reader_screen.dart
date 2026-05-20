import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/strings.dart';
import '../../models/book.dart';
import '../../models/app_exception.dart';
import '../../services/github_service.dart';
import '../../services/book_parser.dart';
import '../../services/book_cache_service.dart';
import '../../services/sync_service.dart';
import '../../services/tts_service.dart';
import '../widgets/eink_flash.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/reading_progress_bar.dart';

/// The main book reading screen.
///
/// Supports PDF (text extraction + image fallback) and EPUB formats.
/// Features immersive mode, configurable font size, and E-ink optimizations.
class ReaderScreen extends StatefulWidget {
  final GitHubService githubService;
  final Book book;

  const ReaderScreen({
    super.key,
    required this.githubService,
    required this.book,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  // ─── Services ───
  late final BookParser _parser;
  late final SyncService _syncService;
  final BookCacheService _cache = const BookCacheService();

  // ─── Reading state ───
  int _currentPage = 1;
  int _pageChangesSinceRefresh = 0;
  bool _isFlashing = false;
  bool _isLoading = true;
  bool _forceOriginalPdfPage = false;
  double _fontSize = 18.0;
  int _refreshInterval = 10;
  double _margin = 8.0;

  // ─── TTS state ───
  final TtsService _ttsService = TtsService();
  bool _isTtsActive = false;
  bool _isTtsPlaying = false;
  double _ttsSpeed = 1.0;
  String _ttsLanguage = 'es-ES';
  int _currentTtsSentenceIndex = -1;

  // ─── UI state ───
  bool _showControls = true; // Immersive mode toggle
  List<Widget> _pageContent = [];
  String? _errorMessage;
  int _downloadReceived = 0;
  int _downloadTotal = 0;

  // ─── Controllers ───
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _parser = BookParser();
    _syncService = SyncService(github: widget.githubService);
    _loadPreferences();
    _setupTtsListeners();
    _loadBook();
  }

  @override
  void dispose() {
    _syncService.forceSave(); // Save progress before leaving
    _syncService.dispose();
    _parser.dispose(); // Properly closes both PDF document handles (fixes A4)
    _scrollController.dispose();
    _ttsService.stop();
    _ttsService.dispose();
    super.dispose();
  }

  // ─── Initialization ───

  void _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _fontSize = prefs.getDouble('font_size') ?? 18.0;
      _refreshInterval = prefs.getInt('eink_refresh_interval') ?? 10;
      _margin = prefs.getDouble('reader_margin') ?? 8.0;
      _ttsSpeed = prefs.getDouble('tts_speed') ?? 1.0;
      _ttsLanguage = prefs.getString('tts_language') ?? 'es-ES';
    });
  }

  void _saveFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('font_size', _fontSize);
  }

  void _loadBook() async {
    try {
      // 1. Load sync data
      await _syncService.loadProgress();
      _currentPage = _syncService.getPage(widget.book.name);

      // 2. Download (or load from cache) the book file
      final bytes = await _cache.getBookBytes(
        book: widget.book,
        github: widget.githubService,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _downloadReceived = received;
            _downloadTotal = total;
          });
        },
      );

      // 3. Parse the book
      await _parser.loadBook(bytes, widget.book.name);

      // 4. Extract first page
      _extractCurrentPage();
    } catch (e) {
      if (!mounted) return;
      final appError = AppException.from(e);
      setState(() {
        _errorMessage = '${S.errorLoadingBook}: ${appError.message}';
        _isLoading = false;
      });
    }
  }

  // ─── Content Extraction ───

  void _extractCurrentPage() {
    if (_parser.isPdfLoaded) {
      _extractPdfPage();
    } else if (_parser.isEpubLoaded) {
      _extractEpubPage();
    } else {
      if (!mounted) return;
      setState(() {
        _pageContent = [const Text(S.unsupportedFormat)];
        _isLoading = false;
      });
    }
  }

  void _extractPdfPage() async {
    try {
      if (_forceOriginalPdfPage) {
        // Render as image
        if (!mounted) return;
        setState(() {
          _pageContent = [];
          _isLoading = true;
        });

        final imageBytes = await _parser.renderPdfPageImage(_currentPage);
        if (!mounted) return;

        if (imageBytes != null) {
          setState(() {
            _pageContent = [Image.memory(imageBytes, fit: BoxFit.contain)];
            _isLoading = false;
          });
        } else {
          setState(() {
            _pageContent = [const Text(S.errorRenderingPage)];
            _isLoading = false;
          });
        }
        return;
      }

      // Try text extraction first
      final text = _parser.extractPdfText(_currentPage);
      if (text != null) {
        if (!mounted) return;
        setState(() {
          _pageContent = [
            Text(text, style: TextStyle(
              fontSize: _fontSize,
              fontFamily: 'Serif',
              height: 1.5,
            )),
          ];
          _isLoading = false;
        });
      } else {
        // Fallback to image rendering for scanned/image PDFs
        if (!mounted) return;
        setState(() => _isLoading = true);

        final imageBytes = await _parser.renderPdfPageImage(_currentPage);
        if (!mounted) return;

        setState(() {
          _pageContent = imageBytes != null
              ? [Image.memory(imageBytes, fit: BoxFit.contain)]
              : [const Text(S.errorRenderingPage)];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pageContent = [Text('${S.errorProcessingPage}: $e')];
        _isLoading = false;
      });
    }
  }

  void _extractEpubPage() {
    try {
      final widgets = _parser.extractEpubContent(_currentPage, _fontSize);
      if (!mounted) return;
      setState(() {
        _pageContent = widgets;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pageContent = [Text('${S.errorReadingEpub}: $e')];
        _isLoading = false;
      });
    }
  }

  // ─── Navigation ───

  void _handlePageChange(int delta, {bool autoStartTts = false}) {
    if (delta > 0) {
      // Try scrolling down first
      if (_scrollController.hasClients &&
          _scrollController.offset < _scrollController.position.maxScrollExtent - 10) {
        _scrollController.jumpTo(
          _scrollController.offset + MediaQuery.of(context).size.height * 0.7,
        );
        return;
      }
    } else {
      // Try scrolling up first
      if (_scrollController.hasClients && _scrollController.offset > 10) {
        _scrollController.jumpTo(
          _scrollController.offset - MediaQuery.of(context).size.height * 0.7,
        );
        return;
      }
    }

    // Change page/chapter
    final maxPages = _parser.totalPages;
    if (maxPages == 0) return;

    final newPage = (_currentPage + delta).clamp(1, maxPages);
    if (newPage == _currentPage) return;

    setState(() {
      _currentPage = newPage;
      _pageChangesSinceRefresh++;
    });

    _extractCurrentPage();

    // Reset scroll to top of new page
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    // Anti-ghosting flash
    if (_pageChangesSinceRefresh >= _refreshInterval) {
      _triggerFlash();
    }

    // Update sync progress
    _syncService.updateProgress(widget.book.name, _currentPage);

    if (autoStartTts || (_isTtsActive && _isTtsPlaying)) {
      _startTtsOnCurrentPage();
    }
  }

  void _triggerFlash() async {
    setState(() => _isFlashing = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() {
      _isFlashing = false;
      _pageChangesSinceRefresh = 0;
    });
  }

  // ─── Font Size ───

  void _increaseFontSize() {
    setState(() => _fontSize = (_fontSize + 2).clamp(12.0, 32.0));
    _saveFontSize();
    _extractCurrentPage();
  }

  void _decreaseFontSize() {
    setState(() => _fontSize = (_fontSize - 2).clamp(12.0, 32.0));
    _saveFontSize();
    _extractCurrentPage();
  }

  void _cycleMargin() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_margin == 0.0) {
        _margin = 8.0;
      } else if (_margin == 8.0) {
        _margin = 16.0;
      } else if (_margin == 16.0) {
        _margin = 24.0;
      } else {
        _margin = 0.0;
      }
    });
    await prefs.setDouble('reader_margin', _margin);
  }

  String _getMarginLabel() {
    if (_margin == 0.0) return 'None';
    if (_margin == 8.0) return 'Small';
    if (_margin == 16.0) return 'Medium';
    return 'Large';
  }

  void _setupTtsListeners() {
    _ttsService.onStateChanged = (state) {
      if (!mounted) return;
      setState(() {
        _isTtsPlaying = state == TtsState.playing;
      });
    };

    _ttsService.onSentenceChanged = (index, sentence) {
      if (!mounted) return;
      setState(() {
        _currentTtsSentenceIndex = index;
      });
    };

    _ttsService.onCompletion = () {
      if (!mounted) return;
      if (_currentPage < _parser.totalPages) {
        _handlePageChange(1, autoStartTts: true);
      } else {
        setState(() {
          _isTtsPlaying = false;
          _currentTtsSentenceIndex = -1;
        });
      }
    };
  }

  void _toggleTtsPlayback() async {
    if (_ttsService.isPlaying) {
      await _ttsService.pause();
    } else if (_ttsService.isPaused) {
      await _ttsService.resume();
    } else {
      _startTtsOnCurrentPage();
    }
  }

  void _startTtsOnCurrentPage() async {
    String? text;
    if (_parser.isPdfLoaded) {
      text = _parser.extractPdfText(_currentPage);
    } else if (_parser.isEpubLoaded) {
      text = _parser.extractEpubText(_currentPage);
    }

    if (text == null || text.trim().isEmpty) {
      return;
    }

    await _ttsService.setLanguage(_ttsLanguage);
    await _ttsService.setSpeed(_ttsSpeed);
    await _ttsService.start(text);
  }

  void _stopTts() async {
    await _ttsService.stop();
    setState(() {
      _isTtsActive = false;
      _currentTtsSentenceIndex = -1;
    });
  }

  void _cycleTtsSpeed() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_ttsSpeed == 1.0) {
        _ttsSpeed = 1.25;
      } else if (_ttsSpeed == 1.25) {
        _ttsSpeed = 1.5;
      } else if (_ttsSpeed == 1.5) {
        _ttsSpeed = 1.75;
      } else if (_ttsSpeed == 1.75) {
        _ttsSpeed = 2.0;
      } else {
        _ttsSpeed = 1.0;
      }
    });
    await _ttsService.setSpeed(_ttsSpeed);
    await prefs.setDouble('tts_speed', _ttsSpeed);
  }

  void _toggleTtsLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_ttsLanguage == 'es-ES') {
        _ttsLanguage = 'en-US';
      } else {
        _ttsLanguage = 'es-ES';
      }
    });
    await _ttsService.setLanguage(_ttsLanguage);
    await prefs.setString('tts_language', _ttsLanguage);
    if (_ttsService.isPlaying || _ttsService.isPaused) {
      _startTtsOnCurrentPage();
    }
  }

  // ─── Build ───

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
            _increaseFontSize();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _decreaseFontSize();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        appBar: _showControls ? _buildAppBar() : null,
        body: Stack(
          children: [
            _isLoading ? _buildLoadingState() : _buildReaderContent(),
            EinkFlash(visible: _isFlashing),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    final totalPages = _parser.totalPages;
    final pageLabel = _parser.isEpubLoaded
        ? '${S.chapterLabel} $_currentPage / $totalPages'
        : '${S.pageLabel} $_currentPage / $totalPages';

    return AppBar(
      title: Text(widget.book.name, overflow: TextOverflow.ellipsis),
      actions: [
        // PDF: toggle text/image mode
        if (_parser.isPdfLoaded)
          IconButton(
            icon: Icon(_forceOriginalPdfPage ? Icons.text_fields : Icons.image),
            onPressed: () {
              setState(() => _forceOriginalPdfPage = !_forceOriginalPdfPage);
              _extractCurrentPage();
            },
            tooltip: S.toggleViewTooltip,
          ),

        // Font size: discrete buttons instead of slider (fixes C4)
        IconButton(
          icon: const Icon(Icons.text_decrease, size: 20),
          onPressed: _fontSize > 12 ? _decreaseFontSize : null,
        ),
        Text(
          '${_fontSize.round()}',
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.text_increase, size: 20),
          onPressed: _fontSize < 32 ? _increaseFontSize : null,
        ),

        // Margin density selector
        IconButton(
          icon: const Icon(Icons.density_medium, size: 20),
          onPressed: _cycleMargin,
          tooltip: 'Margin: ${_getMarginLabel()}',
        ),

        // TTS toggle button
        IconButton(
          icon: Icon(
            _isTtsActive ? Icons.volume_up : Icons.volume_mute,
            size: 20,
            color: _isTtsActive ? theme.colorScheme.primary : null,
          ),
          onPressed: () {
            setState(() {
              _isTtsActive = !_isTtsActive;
            });
            if (_isTtsActive) {
              _startTtsOnCurrentPage();
            } else {
              _stopTts();
            }
          },
          tooltip: S.ttsTooltip,
        ),

        // Page indicator
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Center(
            child: Text(
              pageLabel,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    if (_downloadTotal > 0) {
      return LoadingIndicator(
        message: '${S.downloadingBook} ${widget.book.name}',
        bytesReceived: _downloadReceived,
        totalBytes: _downloadTotal,
      );
    }
    if (_errorMessage != null) {
      return _buildErrorState();
    }
    return const LoadingIndicator();
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _loadBook();
              },
              icon: const Icon(Icons.refresh),
              label: const Text(S.errorRetry),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface,
                side: BorderSide(color: theme.colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReaderContent() {
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTapUp: (details) {
              final width = MediaQuery.of(context).size.width;
              final tapX = details.globalPosition.dx;

              if (tapX > width * 0.7) {
                _handlePageChange(1);
              } else if (tapX < width * 0.3) {
                _handlePageChange(-1);
              } else {
                // Center tap: toggle immersive mode (fixes B4, B7)
                setState(() => _showControls = !_showControls);
              }
            },
            child: Container(
              color: theme.scaffoldBackgroundColor,
              width: double.infinity,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const ClampingScrollPhysics(),
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: _margin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _pageContent,
                ),
              ),
            ),
          ),
        ),

        // Reading progress bar (fixes B5)
        ReadingProgressBar(
          currentPage: _currentPage,
          totalPages: _parser.totalPages,
        ),

        // TTS Control Panel
        if (_isTtsActive)
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Stop/Close button
                IconButton(
                  icon: const Icon(Icons.stop, size: 20),
                  onPressed: _stopTts,
                  tooltip: S.ttsStop,
                ),
                // Play/Pause button
                IconButton(
                  icon: Icon(_isTtsPlaying ? Icons.pause : Icons.play_arrow, size: 24),
                  onPressed: _toggleTtsPlayback,
                  tooltip: _isTtsPlaying ? S.ttsPause : S.ttsPlay,
                ),
                // Language toggle: ES/EN
                TextButton(
                  onPressed: _toggleTtsLanguage,
                  child: Text(
                    _ttsLanguage == 'es-ES' ? 'ES' : 'EN',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                // Speed selection: 1.0x, 1.25x, etc.
                TextButton(
                  onPressed: _cycleTtsSpeed,
                  child: Text(
                    '${_ttsSpeed}x',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Bottom navigation bar
        if (_showControls)
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: () => _handlePageChange(-1),
                  icon: const Icon(Icons.arrow_back_ios, size: 20),
                ),
                Text(
                  '$_currentPage / ${_parser.totalPages}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                IconButton(
                  onPressed: () => _handlePageChange(1),
                  icon: const Icon(Icons.arrow_forward_ios, size: 20),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
