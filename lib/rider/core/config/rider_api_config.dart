class RiderApiConfig {
  RiderApiConfig({
    required String baseUrl,
    required this.apiKey,
    String? socketUrl,
    this.reverbKey,
  }) : baseUri = Uri.parse(_withTrailingSlash(baseUrl)),
       socketUri = Uri.parse(socketUrl ?? 'ws://localhost:8080');

  factory RiderApiConfig.fromEnvironment() => RiderApiConfig(
    baseUrl: const String.fromEnvironment(
      'TALA_API_BASE_URL',
      defaultValue: 'http://127.0.0.1:8000/api/v1/',
    ),
    apiKey: const String.fromEnvironment('TALA_API_KEY'),
    socketUrl: const String.fromEnvironment(
      'TALA_SOCKET_URL',
      defaultValue: 'ws://localhost:8080',
    ),
    reverbKey: const String.fromEnvironment('TALA_REVERB_KEY'),
  );

  final Uri baseUri;
  final String apiKey;
  final Uri socketUri;
  final String? reverbKey;

  /// The Laravel broadcasting auth endpoint used to sign private-channel
  /// subscriptions (POST /broadcasting/auth with bearer token).
  Uri get broadcastAuthUri => baseUri.replace(path: '/broadcasting/auth');

  static String _withTrailingSlash(String value) =>
      value.endsWith('/') ? value : '$value/';
}
