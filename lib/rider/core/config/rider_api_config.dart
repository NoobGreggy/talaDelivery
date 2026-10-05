class RiderApiConfig {
  RiderApiConfig({
    required String baseUrl,
    required this.apiKey,
    String? socketUrl,
  }) : baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
       socketUri = Uri.parse(socketUrl ?? 'https://realtime.tala-works.online');

  factory RiderApiConfig.fromEnvironment() => RiderApiConfig(
    baseUrl: const String.fromEnvironment(
      'TALA_API_BASE_URL',
      defaultValue: 'https://api.tala-works.online/api/v1/',
    ),
    apiKey: const String.fromEnvironment('TALA_API_KEY'),
    socketUrl: const String.fromEnvironment(
      'TALA_SOCKET_URL',
      defaultValue: 'https://realtime.tala-works.online',
    ),
  );
  final Uri baseUri;
  final String apiKey;
  final Uri socketUri;
}
