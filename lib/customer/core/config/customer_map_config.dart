class CustomerMapConfig {
  const CustomerMapConfig({required this.styleUrl});

  factory CustomerMapConfig.fromEnvironment() => const CustomerMapConfig(
    styleUrl: String.fromEnvironment(
      'TALA_MAP_STYLE_URL',
      defaultValue: 'https://tiles.openfreemap.org/styles/liberty',
    ),
  );

  final String styleUrl;
}
