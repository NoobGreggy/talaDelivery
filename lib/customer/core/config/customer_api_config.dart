class CustomerApiConfig {
  CustomerApiConfig({required String baseUrl, required this.apiKey})
    : baseUri = Uri.parse(_withTrailingSlash(baseUrl));

  factory CustomerApiConfig.fromEnvironment() => CustomerApiConfig(
    baseUrl: const String.fromEnvironment(
      'TALA_API_BASE_URL',
      defaultValue: 'https://api.tala-works.online/api/v1/',
    ),
    apiKey: const String.fromEnvironment('TALA_API_KEY'),
  );

  final Uri baseUri;
  final String apiKey;

  static String _withTrailingSlash(String value) =>
      value.endsWith('/') ? value : '$value/';
}
