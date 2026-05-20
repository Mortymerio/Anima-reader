import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, paused, stopped }

/// Service to handle Text-to-Speech playback with sentence-by-sentence tracking.
class TtsService {
  final FlutterTts _flutterTts = FlutterTts();

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
    _initTts();
  }

  void _initTts() {
    _flutterTts.setStartHandler(() {
      _updateState(TtsState.playing);
    });

    _flutterTts.setCompletionHandler(() {
      _onSentenceComplete();
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint("TTS Error: $msg");
      _updateState(TtsState.stopped);
    });

    _flutterTts.setCancelHandler(() {
      _updateState(TtsState.stopped);
    });

    _flutterTts.setContinueHandler(() {
      _updateState(TtsState.playing);
    });

    _flutterTts.setPauseHandler(() {
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

  /// Sets the TTS language (e.g. 'es-ES', 'en-US').
  Future<void> setLanguage(String locale) async {
    _currentLanguage = locale;
    await _flutterTts.setLanguage(locale);
  }

  /// Sets the speech rate (speed). Windows and Android handle this scale slightly differently.
  /// Standard rate is typically 0.5 for flutter_tts (range 0.0 to 1.0).
  /// We map speed values (1.0x, 1.25x, 1.5x) to native values.
  Future<void> setSpeed(double rate) async {
    _currentSpeed = rate;
    // Map rate (e.g. 1.0, 1.25, 1.5) to flutter_tts rate scale (typically 0.5 is default speed)
    final double mappedRate = (rate * 0.5).clamp(0.0, 1.0);
    await _flutterTts.setSpeechRate(mappedRate);
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
    if (_state == TtsState.playing) {
      await _flutterTts.pause();
      _updateState(TtsState.paused);
    }
  }

  /// Stops playback and resets state.
  Future<void> stop() async {
    await _flutterTts.stop();
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
    await _flutterTts.speak(sentence);
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
    // Split by punctuation marks followed by whitespace, making sure to avoid empty strings
    return text
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Cleans up resource listeners.
  void dispose() {
    _flutterTts.stop();
  }
}
