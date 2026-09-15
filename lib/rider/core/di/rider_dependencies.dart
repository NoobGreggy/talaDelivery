part of '../../app.dart';

class RiderAppDependencies {
  RiderAppDependencies(this.repository, this.controller, [this._ownedClient]);

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
    return RiderAppDependencies(
      repository,
      RiderAppController(repository),
      client,
    );
  }

  static Future<RiderAppDependencies> live({RiderApiConfig? config}) async {
    final client = http.Client();
    final preferences = await SharedPreferences.getInstance();
    final tokens = PreferencesRiderTokenStore(preferences);
    final repository = ApiRiderRepository(
      RiderApiClient(
        client,
        config ?? RiderApiConfig.fromEnvironment(),
        tokens,
      ),
      tokens,
    );
    return RiderAppDependencies(
      repository,
      RiderAppController(repository),
      client,
    );
  }

  final RiderRepository repository;
  final RiderAppController controller;
  final http.Client? _ownedClient;

  void dispose() {
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
