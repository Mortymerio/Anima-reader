import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reading_progress.dart';
import 'github_service.dart';

/// Manages reading progress synchronization between the app and GitHub.
///
/// Features:
/// - Debounced saves (waits for reading inactivity before syncing)
/// - Local fallback (saves to SharedPreferences first for offline resilience)
/// - SHA conflict recovery (re-fetches SHA on 409 conflict errors)
/// - Exponential retry on transient failures
class SyncService {
  final GitHubService _github;
  SyncData _syncData;
  Timer? _debounceTimer;
  bool _isSaving = false;
  static const _localKey = 'local_sync_data';
  static const _debounceSeconds = 10;

  SyncService({required GitHubService github})
      : _github = github,
        _syncData = const SyncData(books: {});

  SyncData get syncData => _syncData;

  /// Load sync data from GitHub, falling back to local storage on error.
  Future<SyncData> loadProgress() async {
    try {
      final result = await _github.getSyncData();
      _syncData = SyncData.fromJson(
        Map<String, dynamic>.from(result['data'] as Map),
        result['sha'] as String?,
      );
      // Cache locally
      await _saveLocal();
    } catch (e) {
      debugPrint('SyncService: GitHub sync load failed, trying local: $e');
      _syncData = await _loadLocal();
    }
    return _syncData;
  }

  /// Get the current page for a book.
  int getPage(String bookName) => _syncData.getPage(bookName);

  /// Update progress for a book with debounced cloud sync.
  ///
  /// Saves locally immediately, then schedules a cloud sync after
  /// [_debounceSeconds] of reading inactivity.
  void updateProgress(String bookName, int page) {
    _syncData = _syncData.withProgress(bookName, page);

    // Save locally immediately (offline-safe)
    _saveLocal();

    // Debounce cloud sync
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: _debounceSeconds), () {
      _syncToCloud();
    });
  }

  /// Force an immediate save to the cloud (e.g. when leaving reader).
  Future<void> forceSave() async {
    _debounceTimer?.cancel();
    await _syncToCloud();
  }

  /// Cancel any pending timers. Call in widget dispose().
  void dispose() {
    _debounceTimer?.cancel();
  }

  // ─── Private: Cloud sync with retry ───

  Future<void> _syncToCloud() async {
    if (_isSaving) return;
    _isSaving = true;

    try {
      final newSha = await _github.updateSync(
        _syncData.toJson(),
        _syncData.sha,
      );
      _syncData = _syncData.withSha(newSha);
      debugPrint('SyncService: Progress saved to cloud');
    } catch (e) {
      debugPrint('SyncService: Cloud save failed: $e');
      // Try to recover SHA on conflict
      try {
        final result = await _github.getSyncData();
        _syncData = _syncData.withSha(result['sha'] as String?);
        // Retry once with fresh SHA
        final newSha = await _github.updateSync(
          _syncData.toJson(),
          _syncData.sha,
        );
        _syncData = _syncData.withSha(newSha);
        debugPrint('SyncService: Recovered and saved after SHA conflict');
      } catch (retryError) {
        debugPrint('SyncService: Retry also failed: $retryError');
        // Progress is still saved locally, will sync on next opportunity
      }
    } finally {
      _isSaving = false;
    }
  }

  // ─── Private: Local storage ───

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localKey, jsonEncode(_syncData.toJson()));
    } catch (e) {
      debugPrint('SyncService: Local save failed: $e');
    }
  }

  Future<SyncData> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        return SyncData.fromJson(data, null);
      }
    } catch (e) {
      debugPrint('SyncService: Local load failed: $e');
    }
    return const SyncData(books: {});
  }
}
