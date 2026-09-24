class RiderApiConfig {
  RiderApiConfig({
    required String baseUrl,
    required this.apiKey,
    String? socketUrl,
    this.reverbKey,
  }) : baseUri = Uri.parse(_withTrailingSlash(baseUrl)),
       socketUri = Uri.parse(socketUrl ?? 'ws://127.0.0.1:6001');

  factory RiderApiConfig.fromEnvironment() {
    const socketUrl = String.fromEnvironment('TALA_REVERB_WS_URL');
    const legacySocketUrl = String.fromEnvironment(
      'TALA_SOCKET_URL',
      defaultValue: 'ws://127.0.0.1:6001',
    );
    const reverbKey = String.fromEnvironment('TALA_REVERB_APP_KEY');
    const legacyReverbKey = String.fromEnvironment('TALA_REVERB_KEY');
    return RiderApiConfig(
      baseUrl: const String.fromEnvironment(
        'TALA_API_BASE_URL',
        defaultValue: 'http://127.0.0.1:8000/api/v1/',
      ),
      apiKey: const String.fromEnvironment('TALA_API_KEY'),
      socketUrl: socketUrl.isEmpty ? legacySocketUrl : socketUrl,
      reverbKey: reverbKey.isEmpty ? legacyReverbKey : reverbKey,
    );
  }

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
