class RiderApiConfig {
  RiderApiConfig({
    required String baseUrl,
    required this.apiKey,
    String? socketUrl,
  }) : baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
       socketUri = Uri.parse(socketUrl ?? 'http://127.0.0.1:3008');

  factory RiderApiConfig.fromEnvironment() => RiderApiConfig(
    baseUrl: const String.fromEnvironment(
      'TALA_API_BASE_URL',
      defaultValue: 'http://127.0.0.1:3000/api/v1/',
    ),
    apiKey: const String.fromEnvironment('TALA_API_KEY'),
    socketUrl: const String.fromEnvironment(
      'TALA_SOCKET_URL',
      defaultValue: 'http://127.0.0.1:3008',
    ),
  );
  final Uri baseUri;
  final String apiKey;
  final Uri socketUri;
}
