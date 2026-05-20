import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/book.dart';

/// Handles all communication with the GitHub REST API v3.
///
/// Provides methods to:
/// - Fetch the list of books (PDF/EPUB files) from a repository
/// - Download book files with progress tracking
/// - Read and update the sync.json progress file
class GitHubService {
  final String pat;
  final String owner;
  final String repo;
  final Dio _dio = Dio();

  GitHubService({required this.pat, required this.owner, required this.repo}) {
    _dio.options.baseUrl = 'https://api.github.com';
    _dio.options.headers = {
      'Authorization': 'token $pat',
      'Accept': 'application/vnd.github.v3+json',
    };
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
  }

  /// Fetch all supported book files (.pdf, .epub) from the repository root.
  Future<List<Book>> fetchBooks() async {
    final response = await _dio.get('/repos/$owner/$repo/contents');
    return (response.data as List)
        .map((e) => Book.fromGitHub(e as Map<String, dynamic>))
        .where((book) => book.isSupported)
        .toList();
  }

  /// Get the sync.json file contents and SHA.
  /// Returns {'data': Map, 'sha': String?} or {'data': {}, 'sha': null} if not found.
  Future<Map<String, dynamic>> getSyncData() async {
    try {
      final response = await _dio.get('/repos/$owner/$repo/contents/sync.json');
      final content = utf8.decode(
        base64.decode(response.data['content'].replaceAll('\n', '')),
      );
      return {
        'data': jsonDecode(content),
        'sha': response.data['sha'],
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return {'data': {}, 'sha': null};
      }
      rethrow;
    }
  }

  /// Update or create the sync.json file. Returns the new SHA.
  Future<String?> updateSync(Map<String, dynamic> data, String? sha) async {
    final content = base64.encode(utf8.encode(jsonEncode(data)));
    final response = await _dio.put(
      '/repos/$owner/$repo/contents/sync.json',
      data: {
        'message': 'Update reading progress [Anima]',
        'content': content,
        if (sha != null) 'sha': sha,
      },
    );
    return response.data['content']['sha'];
  }

  /// Download a file from its raw URL with optional progress tracking.
  Future<List<int>> downloadFile(
    String url, {
    void Function(int received, int total)? onProgress,
  }) async {
    final response = await _dio.get(
      url,
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: onProgress,
    );
    return response.data;
  }
}
