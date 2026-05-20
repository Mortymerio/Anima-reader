/// Represents the reading progress for a single book.
class ReadingProgress {
  final int page;
  final DateTime timestamp;

  const ReadingProgress({
    required this.page,
    required this.timestamp,
  });

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      page: json['page'] as int? ?? 1,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'page': page,
        'timestamp': timestamp.toIso8601String(),
      };

  ReadingProgress copyWith({int? page}) {
    return ReadingProgress(
      page: page ?? this.page,
      timestamp: DateTime.now(),
    );
  }
}

/// Container for all sync data from the sync.json file.
class SyncData {
  final Map<String, ReadingProgress> books;
  final String? sha;

  const SyncData({required this.books, this.sha});

  factory SyncData.fromJson(Map<String, dynamic> json, String? sha) {
    final books = <String, ReadingProgress>{};
    for (final entry in json.entries) {
      if (entry.value is Map<String, dynamic>) {
        books[entry.key] = ReadingProgress.fromJson(entry.value as Map<String, dynamic>);
      }
    }
    return SyncData(books: books, sha: sha);
  }

  Map<String, dynamic> toJson() {
    return books.map((key, value) => MapEntry(key, value.toJson()));
  }

  /// Get progress for a specific book, defaulting to page 1.
  int getPage(String bookName) {
    return books[bookName]?.page ?? 1;
  }

  /// Return a new SyncData with updated progress for one book.
  SyncData withProgress(String bookName, int page) {
    final updated = Map<String, ReadingProgress>.from(books);
    updated[bookName] = ReadingProgress(page: page, timestamp: DateTime.now());
    return SyncData(books: updated, sha: sha);
  }

  /// Return a new SyncData with an updated SHA.
  SyncData withSha(String? newSha) {
    return SyncData(books: books, sha: newSha);
  }
}
