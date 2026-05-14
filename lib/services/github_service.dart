import 'dart:convert';
import 'package:dio/dio.dart';

class GitHubService {
  final String pat;
  final String owner;
  final String repo;
  final Dio _dio = Dio();

  GitHubService({required this.pat, required this.owner, required this.repo}) {
    _dio.options.baseUrl = "https://api.github.com";
    _dio.options.headers = {
      'Authorization': 'token $pat',
      'Accept': 'application/vnd.github.v3+json',
    };
  }

  Future<List<Map<String, dynamic>>> fetchBooks() async {
    try {
      final response = await _dio.get("/repos/$owner/$repo/contents");
      return (response.data as List).where((file) {
        final name = file['name'].toString().toLowerCase();
        return name.endsWith('.pdf') || name.endsWith('.epub') || name.endsWith('.mobi');
      }).map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getSyncData() async {
    try {
      final response = await _dio.get("/repos/$owner/$repo/contents/sync.json");
      final content = utf8.decode(base64.decode(response.data['content'].replaceAll('\n', '')));
      return {
        'data': jsonDecode(content),
        'sha': response.data['sha'],
      };
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        return {'data': {}, 'sha': null};
      }
      rethrow;
    }
  }

  Future<String?> updateSync(Map<String, dynamic> data, String? sha) async {
    final content = base64.encode(utf8.encode(jsonEncode(data)));
    final response = await _dio.put("/repos/$owner/$repo/contents/sync.json", data: {
      "message": "Update reading progress [Anima]",
      "content": content,
      if (sha != null) "sha": sha,
    });
    return response.data['content']['sha'];
  }

  Future<List<int>> downloadFile(String url) async {
    final response = await _dio.get(url, options: Options(responseType: ResponseType.bytes));
    return response.data;
  }
}
