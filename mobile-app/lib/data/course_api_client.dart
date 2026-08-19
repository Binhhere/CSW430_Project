import 'dart:convert';

import 'package:http/http.dart' as http;

class CourseApiException implements Exception {
  const CourseApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  @override
  String toString() => 'CourseApiException($statusCode): $message';
}

class CourseApiClient {
  static String? localAccessToken;

  CourseApiClient(this._baseUrl);

  final String _baseUrl;

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _send('POST', path, body: body);

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) =>
      _send('PUT', path, body: body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final base = Uri.parse(_baseUrl);
    final uri = base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/$'), '')}$path',
      queryParameters: query,
    );
    final token = localAccessToken;
    final headers = <String, String>{'content-type': 'application/json'};
    if (token != null) headers['authorization'] = 'Bearer $token';
    final request = http.Request(method, uri)
      ..headers.addAll(headers)
      ..body = body == null ? '' : jsonEncode(body);
    final response = await http.Client()
        .send(request)
        .then(http.Response.fromStream);
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true) {
      throw CourseApiException(
        response.statusCode,
        decoded['message'] as String? ?? 'Request failed',
      );
    }
    return decoded['data'];
  }
}
