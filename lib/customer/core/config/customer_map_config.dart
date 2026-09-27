class CustomerMapConfig {
  const CustomerMapConfig({required this.accessToken, required this.styleUrl});

  factory CustomerMapConfig.fromEnvironment() => const CustomerMapConfig(
    accessToken: String.fromEnvironment('TALA_MAPBOX_ACCESS_TOKEN'),
    styleUrl: String.fromEnvironment(
      'TALA_MAPBOX_STYLE_URL',
      defaultValue: 'mapbox://styles/mapbox/streets-v12',
    ),
  );

  final String accessToken;
  final String styleUrl;

  bool get isConfigured => accessToken.trim().isNotEmpty;
}
