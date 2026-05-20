import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';
import 'github_service.dart';

/// Caches downloaded book files locally to avoid re-downloading on every open.
///
/// Files are stored in the app's documents directory under a `book_cache/` folder.
/// Each file is named by its SHA hash to detect when a book has been updated
/// in the remote repository.
class BookCacheService {
  static const _cacheDir = 'book_cache';

  const BookCacheService();

  /// Get cached book bytes, or download and cache if not available.
  ///
  /// [onProgress] callback receives (bytesReceived, totalBytes) for download progress.
  Future<List<int>> getBookBytes({
    required Book book,
    required GitHubService github,
    void Function(int received, int total)? onProgress,
  }) async {
    // Check if already cached with matching SHA
    final cachedBytes = await _readFromCache(book);
    if (cachedBytes != null) {
      debugPrint('BookCache: Using cached version of ${book.name}');
      return cachedBytes;
    }

    // Download and cache
    debugPrint('BookCache: Downloading ${book.name} (${book.formattedSize})');
    final bytes = await github.downloadFile(
      book.downloadUrl,
      onProgress: onProgress,
    );
    await _writeToCache(book, bytes);
    return bytes;
  }

  /// Clear the entire book cache.
  Future<void> clearCache() async {
    final dir = await _getCacheDirectory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Get total cache size in bytes.
  Future<int> getCacheSize() async {
    final dir = await _getCacheDirectory();
    if (!await dir.exists()) return 0;
    int total = 0;
    await for (final entity in dir.list()) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  // ─── Private ───

  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/$_cacheDir');
  }

  String _cacheFileName(Book book) {
    // Use SHA as filename to auto-invalidate when file changes on GitHub
    return '${book.sha}_${book.name}';
  }

  Future<Uint8List?> _readFromCache(Book book) async {
    if (book.sha.isEmpty) return null; // Can't verify without SHA
    final dir = await _getCacheDirectory();
    final file = File('${dir.path}/${_cacheFileName(book)}');
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  Future<void> _writeToCache(Book book, List<int> bytes) async {
    try {
      final dir = await _getCacheDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File('${dir.path}/${_cacheFileName(book)}');
      await file.writeAsBytes(bytes);
    } catch (e) {
      debugPrint('BookCache: Failed to cache ${book.name}: $e');
    }
  }
}
