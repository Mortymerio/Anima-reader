import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, paused, stopped }

/// Service to handle Text-to-Speech playback with sentence-by-sentence tracking.
/// Uses a simulated mock playback on Windows to bypass the flutter_tts native threading bug.
class TtsService {
  final FlutterTts? _flutterTts = FlutterTts();
  final bool _useMock = false;

  // Mock state
  Timer? _mockTimer;

  // State
  TtsState _state = TtsState.stopped;
  List<String> _sentences = [];
  int _currentSentenceIndex = 0;
  String _currentLanguage = 'es-ES';
  double _currentSpeed = 1.0;

  // Callbacks
  VoidCallback? onCompletion;
  void Function(int index, String sentence)? onSentenceChanged;
  void Function(TtsState state)? onStateChanged;

  TtsState get state => _state;
  bool get isPlaying => _state == TtsState.playing;
  bool get isPaused => _state == TtsState.paused;
  bool get isStopped => _state == TtsState.stopped;
  int get currentSentenceIndex => _currentSentenceIndex;
  List<String> get sentences => _sentences;

  TtsService() {
    if (!_useMock) {
      _initTts();
    }
  }

  void _initTts() {
    _flutterTts!.setStartHandler(() {
      _updateState(TtsState.playing);
    });

    _flutterTts!.setCompletionHandler(() {
      _onSentenceComplete();
    });

    _flutterTts!.setErrorHandler((msg) {
      debugPrint("TTS Error: $msg");
      _updateState(TtsState.stopped);
    });

    _flutterTts!.setCancelHandler(() {
      _updateState(TtsState.stopped);
    });

    _flutterTts!.setContinueHandler(() {
      _updateState(TtsState.playing);
    });

    _flutterTts!.setPauseHandler(() {
      _updateState(TtsState.paused);
    });

    // Apply defaults
    setLanguage(_currentLanguage);
    setSpeed(_currentSpeed);
  }

  void _updateState(TtsState newState) {
    _state = newState;
    onStateChanged?.call(_state);
  }

  /// Sets the TTS language (e.g. 'es-ES', 'en-US') and attempts to select a matching voice.
  Future<void> setLanguage(String locale) async {
    _currentLanguage = locale;
    if (_useMock) return;

    await _flutterTts!.setLanguage(locale);

    try {
      final voices = await _flutterTts!.getVoices;
      if (voices != null) {
        debugPrint("Available TTS voices on this device:");
        for (var voice in voices) {
          if (voice is Map) {
            debugPrint(" - Name: ${voice['name']}, Locale: ${voice['locale']}");
          }
        }

        final languageCode = locale.split('-')[0].toLowerCase(); // e.g. 'es'
        Map<String, String>? matchingVoice;

        for (var voice in voices) {
          if (voice is Map) {
            final voiceLocale = (voice['locale'] ?? '').toString().toLowerCase();
            final voiceName = (voice['name'] ?? '').toString().toLowerCase();

            // Match if locale contains language code (e.g., 'es-ES', 'es-MX', 'es') or name contains 'spanish'/'español'
            if (voiceLocale.startsWith(languageCode) ||
                voiceLocale.contains(languageCode) ||
                (languageCode == 'es' && (voiceLocale.contains('spa') || voiceName.contains('spanish') || voiceName.contains('español'))) ||
                (languageCode == 'en' && (voiceLocale.contains('eng') || voiceName.contains('english')))) {
              matchingVoice = {
                'name': voice['name']?.toString() ?? '',
                'locale': voice['locale']?.toString() ?? '',
              };
              break;
            }
          }
        }

        if (matchingVoice != null) {
          await _flutterTts!.setVoice(matchingVoice);
          debugPrint("Selected TTS voice: ${matchingVoice['name']} for language $locale");
        } else {
          debugPrint("No matching native voice found for $locale. The OS default voice will be used.");
        }
      }
    } catch (e) {
      debugPrint("Error setting voice for locale $locale: $e");
    }
  }

  /// Sets the speech rate (speed). Windows and Android handle this scale slightly differently.
  Future<void> setSpeed(double rate) async {
    _currentSpeed = rate;
    if (_useMock) return;

    final double mappedRate = (rate * 0.5).clamp(0.0, 1.0);
    await _flutterTts!.setSpeechRate(mappedRate);
  }

  /// Splits a block of text into sentences, resets progress, and begins playback.
  Future<void> start(String text) async {
    await stop();
    _sentences = _splitIntoSentences(text);
    _currentSentenceIndex = 0;

    if (_sentences.isEmpty) {
      onCompletion?.call();
      return;
    }

    _speakCurrent();
  }

  /// Resumes playback of the current sentence.
  Future<void> resume() async {
    if (_state == TtsState.paused && _sentences.isNotEmpty) {
      _speakCurrent();
    }
  }

  /// Pauses speaking.
  Future<void> pause() async {
    if (_useMock) {
      if (_state == TtsState.playing) {
        _mockTimer?.cancel();
        _updateState(TtsState.paused);
      }
      return;
    }

    if (_state == TtsState.playing) {
      await _flutterTts!.pause();
      _updateState(TtsState.paused);
    }
  }

  /// Stops playback and resets state.
  Future<void> stop() async {
    if (_useMock) {
      _mockTimer?.cancel();
      _sentences = [];
      _currentSentenceIndex = 0;
      _updateState(TtsState.stopped);
      return;
    }

    await _flutterTts!.stop();
    _sentences = [];
    _currentSentenceIndex = 0;
    _updateState(TtsState.stopped);
  }

  Future<void> _speakCurrent() async {
    if (_currentSentenceIndex >= _sentences.length) {
      _updateState(TtsState.stopped);
      onCompletion?.call();
      return;
    }

    final sentence = _sentences[_currentSentenceIndex];
    onSentenceChanged?.call(_currentSentenceIndex, sentence);
    _updateState(TtsState.playing);

    if (_useMock) {
      debugPrint("[TTS Mock Speak]: $sentence");
      // Simulate speaking time based on sentence length (e.g. 80ms per character, min 1.2s, max 4s)
      final durationMs = (sentence.length * 80 / _currentSpeed)
          .clamp(1200.0, 4000.0)
          .toInt();
      _mockTimer?.cancel();
      _mockTimer = Timer(Duration(milliseconds: durationMs), () {
        _onSentenceComplete();
      });
      return;
    }

    await _flutterTts!.speak(sentence);
  }

  void _onSentenceComplete() {
    if (_state != TtsState.playing) return;
    _currentSentenceIndex++;
    if (_currentSentenceIndex < _sentences.length) {
      _speakCurrent();
    } else {
      stop();
      onCompletion?.call();
    }
  }

  List<String> _splitIntoSentences(String text) {
    if (text.trim().isEmpty) return [];
    return text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Cleans up resource listeners.
  void dispose() {
    _mockTimer?.cancel();
    if (!_useMock) {
      _flutterTts!.stop();
    }
  }
}
