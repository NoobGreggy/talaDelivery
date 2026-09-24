part of '../../app.dart';

class RiderAppDependencies {
  RiderAppDependencies(
    this.repository,
    this.controller, [
    http.Client? ownedClient,
    this.realtime,
    this.location,
  ]) : _ownedClient = ownedClient;

  factory RiderAppDependencies.transient({RiderApiConfig? config}) {
    final client = http.Client();
    final tokens = MemoryRiderTokenStore();
    final repository = ApiRiderRepository(
      RiderApiClient(
        client,
        config ?? RiderApiConfig.fromEnvironment(),
        tokens,
      ),
      tokens,
    );
    final controller = RiderAppController(repository);
    return RiderAppDependencies(repository, controller, client);
  }

  static Future<RiderAppDependencies> live({RiderApiConfig? config}) async {
    final client = http.Client();
    final preferences = await SharedPreferences.getInstance();
    final tokens = await SecureRiderTokenStore.createAndMigrate(
      legacy: preferences,
    );
    final apiConfig = config ?? RiderApiConfig.fromEnvironment();
    final apiClient = RiderApiClient(client, apiConfig, tokens);
    final repository = ApiRiderRepository(apiClient, tokens);
    final realtime = RiderRealtimeService(
      config: RiderRealtimeConfig(
        socketUrl: apiConfig.socketUri,
        appKey: apiConfig.reverbKey ?? '',
      ),
      authenticator: ApiRiderChannelAuthenticator(client, apiConfig, tokens),
    );
    final location = RiderLocationService(
      source: GeolocatorRiderLocationSource(),
      postLocation: (position) => repository.updateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      ),
      postTrackedLocation: (position, deliveryId) => repository
          .updateTrackedLocation(deliveryId: deliveryId, position: position),
    );
    final controller = RiderAppController(repository)
      ..attachRealtime(realtime)
      ..attachLocation(location);
    return RiderAppDependencies(
      repository,
      controller,
      client,
      realtime,
      location,
    );
  }

  final RiderRepository repository;
  final RiderAppController controller;
  final RiderRealtimeService? realtime;
  final RiderLocationService? location;
  final http.Client? _ownedClient;

  void dispose() {
    location?.stop();
    realtime?.dispose();
    controller.dispose();
    _ownedClient?.close();
  }
}

class RiderDependencyScope extends InheritedWidget {
  const RiderDependencyScope({
    super.key,
    required this.dependencies,
    required super.child,
  });
  final RiderAppDependencies dependencies;

  static RiderAppDependencies of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<RiderDependencyScope>();
    assert(scope != null, 'RiderDependencyScope is missing.');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(RiderDependencyScope oldWidget) =>
      dependencies != oldWidget.dependencies;
}
