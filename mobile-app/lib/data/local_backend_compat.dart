/// Compatibility types for legacy screens outside the local course demo.
/// The assessed flows use [CourseApiClient] and never call this adapter.
class LocalBackendClient {
  LocalBackendClient([String? url, String? key]);

  dynamic from(String table) => _unsupported();
  dynamic rpc(String function, {Map<String, dynamic>? params}) =>
      _unsupported();
  dynamic get storage => this;
  dynamic get functions => this;
  dynamic get auth => this;
  dynamic get currentSession => null;
  dynamic get currentUser => null;
  dynamic invoke(
    String function, {
    dynamic body,
    Map<String, String>? headers,
  }) => _unsupported();
  dynamic download(String path) => _unsupported();
  dynamic upload(String path, dynamic bytes, {dynamic fileOptions}) =>
      _unsupported();

  Never _unsupported() => throw UnsupportedError(
    'This legacy cloud workflow is outside the local course demo.',
  );
}

class BackendAuthException implements Exception {
  const BackendAuthException(this.message, {this.code});
  final String message;
  final String? code;
}

class BackendFunctionException implements Exception {
  const BackendFunctionException({this.details, this.status});
  final dynamic details;
  final int? status;
}

class FunctionResponse {
  const FunctionResponse(this.data);
  final dynamic data;
}

class PostgrestException implements Exception {
  const PostgrestException({required this.message, this.code});
  final String message;
  final String? code;
}

class StorageException implements Exception {
  const StorageException({required this.message, this.statusCode});
  final String message;
  final String? statusCode;
}
