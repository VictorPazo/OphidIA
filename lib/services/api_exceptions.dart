class ServerException implements Exception {
  final String message;
  ServerException(this.message);

  @override
  String toString() => 'ServerException: $message';
}

class ClientException implements Exception {
  final String message;
  ClientException(this.message);

  @override
  String toString() => 'ClientException: $message';
}