/// Represents a book file stored in the user's GitHub repository.
class Book {
  final String name;
  final String downloadUrl;
  final String sha;
  final int sizeBytes;

  const Book({
    required this.name,
    required this.downloadUrl,
    required this.sha,
    this.sizeBytes = 0,
  });

  /// File extension in lowercase without dot (e.g. "pdf", "epub").
  String get extension => name.split('.').last.toLowerCase();

  bool get isPdf => extension == 'pdf';
  bool get isEpub => extension == 'epub';
  bool get isSupported => isPdf || isEpub;

  /// Human-readable file size.
  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Create from GitHub API contents response item.
  factory Book.fromGitHub(Map<String, dynamic> json) {
    return Book(
      name: json['name'] as String,
      downloadUrl: json['download_url'] as String,
      sha: json['sha'] as String? ?? '',
      sizeBytes: json['size'] as int? ?? 0,
    );
  }

  @override
  String toString() => 'Book($name, $formattedSize)';
}
