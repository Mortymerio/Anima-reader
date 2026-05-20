import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, paused, stopped }

/// Service to handle Text-to-Speech playback.
///
/// Strategy:
///   • Windows (SAPI): sends the entire page text in a single speak() call.
///     SAPI natively handles sentence pacing, punctuation pauses, etc.
///     This avoids the race condition where SAPI briefly reports "still speaking"
///     between two consecutive speak() calls and silently drops the second one.
///   • Mobile (Google TTS / AVSpeech): speaks sentence-by-sentence so we can
///     track progress and highlight the current sentence.
class TtsService {
  final FlutterTts _tts = FlutterTts();

  /// On Windows use SAPI's single-utterance mode; elsewhere speak per sentence.
  final bool _singleUtteranceMode = !kIsWeb && Platform.isWindows;

  TtsState _state = TtsState.stopped;

  // Full text for single-utterance mode (Windows)
  String _fullText = '';

  // Sentence list for per-sentence mode (mobile)
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
    _initTts();
  }

  void _initTts() {
    _tts.setStartHandler(() {
      _updateState(TtsState.playing);
    });

    _tts.setCompletionHandler(() {
      if (_singleUtteranceMode) {
        // Whole page done — advance to next page
        _updateState(TtsState.stopped);
        onCompletion?.call();
      } else {
        _onSentenceComplete();
      }
    });

    _tts.setErrorHandler((msg) {
      debugPrint('TTS Error: $msg');
      _updateState(TtsState.stopped);
    });

    _tts.setCancelHandler(() {
      _updateState(TtsState.stopped);
    });

    _tts.setContinueHandler(() {
      _updateState(TtsState.playing);
    });

    _tts.setPauseHandler(() {
      _updateState(TtsState.paused);
    });

    setLanguage(_currentLanguage);
    setSpeed(_currentSpeed);
  }

  void _updateState(TtsState newState) {
    _state = newState;
    onStateChanged?.call(_state);
  }

  /// Sets the TTS language and selects the best matching installed voice.
  Future<void> setLanguage(String locale) async {
    _currentLanguage = locale;
    await _tts.setLanguage(locale);

    try {
      final voices = await _tts.getVoices;
      if (voices == null) return;

      debugPrint('Available TTS voices on this device:');
      for (final voice in voices) {
        if (voice is Map) {
          debugPrint(' - Name: ${voice['name']}, Locale: ${voice['locale']}');
        }
      }

      final languageCode = locale.split('-')[0].toLowerCase();
      Map<String, String>? matchingVoice;

      for (final voice in voices) {
        if (voice is Map) {
          final voiceLocale = (voice['locale'] ?? '').toString().toLowerCase();
          final voiceName = (voice['name'] ?? '').toString().toLowerCase();

          if (voiceLocale.startsWith(languageCode) ||
              voiceLocale.contains(languageCode) ||
              (languageCode == 'es' &&
                  (voiceLocale.contains('spa') ||
                      voiceName.contains('spanish') ||
                      voiceName.contains('español'))) ||
              (languageCode == 'en' &&
                  (voiceLocale.contains('eng') ||
                      voiceName.contains('english')))) {
            matchingVoice = {
              'name': voice['name']?.toString() ?? '',
              'locale': voice['locale']?.toString() ?? '',
            };
            break;
          }
        }
      }

      if (matchingVoice != null) {
        await _tts.setVoice(matchingVoice);
        debugPrint(
            'Selected TTS voice: ${matchingVoice['name']} for language $locale');
      } else {
        debugPrint(
            'No matching native voice found for $locale. The OS default voice will be used.');
      }
    } catch (e) {
      debugPrint('Error setting voice for locale $locale: $e');
    }
  }

  /// Sets the speech rate. SAPI and mobile TTS use different scales.
  Future<void> setSpeed(double rate) async {
    _currentSpeed = rate;
    final double mappedRate = (rate * 0.5).clamp(0.0, 1.0);
    await _tts.setSpeechRate(mappedRate);
  }

  /// Begins speaking the given text from the beginning.
  Future<void> start(String text) async {
    await stop();
    _fullText = text.trim();
    _sentences = _splitIntoSentences(_fullText);
    _currentSentenceIndex = 0;

    if (_fullText.isEmpty) {
      onCompletion?.call();
      return;
    }

    if (_singleUtteranceMode) {
      // Windows: hand the full page to SAPI in one call
      _updateState(TtsState.playing);
      await _tts.speak(_fullText);
    } else {
      // Mobile: sentence by sentence
      _speakCurrent();
    }
  }

  /// Resumes paused playback.
  Future<void> resume() async {
    if (_state != TtsState.paused) return;

    if (_singleUtteranceMode) {
      // On SAPI, calling speak() when isPaused==true triggers Resume() internally
      await _tts.speak(_fullText);
    } else if (_sentences.isNotEmpty) {
      _speakCurrent();
    }
  }

  /// Pauses playback.
  Future<void> pause() async {
    if (_state == TtsState.playing) {
      await _tts.pause();
      _updateState(TtsState.paused);
    }
  }

  /// Stops playback and resets state.
  Future<void> stop() async {
    await _tts.stop();
    _sentences = [];
    _currentSentenceIndex = 0;
    _fullText = '';
    _updateState(TtsState.stopped);
  }

  // ─── Per-sentence mode (mobile) ───────────────────────────────────────────

  Future<void> _speakCurrent() async {
    if (_currentSentenceIndex >= _sentences.length) {
      _updateState(TtsState.stopped);
      onCompletion?.call();
      return;
    }

    final sentence = _sentences[_currentSentenceIndex];
    onSentenceChanged?.call(_currentSentenceIndex, sentence);
    _updateState(TtsState.playing);
    await _tts.speak(sentence);
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

  /// Releases resources.
  void dispose() {
    _tts.stop();
  }
}
