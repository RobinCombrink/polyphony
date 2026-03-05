import "package:http/http.dart" as http;

final class AuthenticatedHttpClient extends http.BaseClient {
  AuthenticatedHttpClient({
    required http.Client innerClient,
    required String bearerToken,
  })  : _innerClient = innerClient,
        _bearerToken = bearerToken;

  final http.Client _innerClient;
  final String _bearerToken;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.putIfAbsent(
      "Authorization",
      () => "Bearer $_bearerToken",
    );

    return _innerClient.send(request);
  }

  @override
  void close() {
    _innerClient.close();
  }
}
