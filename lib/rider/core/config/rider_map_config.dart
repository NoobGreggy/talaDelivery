class RiderMapConfig {
  const RiderMapConfig({required this.styleUrl});

  factory RiderMapConfig.fromEnvironment() => const RiderMapConfig(
    styleUrl: String.fromEnvironment(
      'TALA_MAP_STYLE_URL',
      defaultValue: 'https://tiles.openfreemap.org/styles/liberty',
    ),
  );

  final String styleUrl;
}
