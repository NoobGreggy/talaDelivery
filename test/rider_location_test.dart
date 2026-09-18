import 'package:flutter_test/flutter_test.dart';
import 'package:tala_delivery_rider/main.dart';

class _FakeLocationSource implements RiderLocationSource {
  _FakeLocationSource({
    this.serviceEnabled = true,
    this.permission = RiderLocationPermission.granted,
    this.nextPermissionRequest = RiderLocationPermission.granted,
    this.position = const RiderLatLng(14.5, 121.0),
  });

  bool serviceEnabled;
  RiderLocationPermission permission;
  RiderLocationPermission nextPermissionRequest;
  RiderLatLng? position;
  int permissionRequests = 0;

  @override
  Future<RiderLocationPermission> permissionStatus() async => permission;

  @override
  Future<RiderLocationPermission> requestPermission() async {
    permissionRequests += 1;
    permission = nextPermissionRequest;
    return permission;
  }

  @override
  Future<RiderLatLng?> currentPosition() async => position;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;
}

void main() {
  test('reports position when permission is granted', () async {
    final source = _FakeLocationSource();
    RiderLatLng? posted;
    final service = RiderLocationService(
      source: source,
      postLocation: (position) async {
        posted = position;
      },
    );

    final outcome = await service.reportOnce();

    expect(outcome, RiderLocationReport.posted);
    expect(posted!.latitude, 14.5);
    expect(posted!.longitude, 121.0);
  });

  test('requests permission once and reports denied when refused', () async {
    final source = _FakeLocationSource(
      permission: RiderLocationPermission.denied,
      nextPermissionRequest: RiderLocationPermission.denied,
    );
    final service = RiderLocationService(
      source: source,
      postLocation: (_) async {},
    );

    final outcome = await service.reportOnce();

    expect(source.permissionRequests, 1);
    expect(outcome, RiderLocationReport.permissionDenied);
  });

  test(
    'reports permanently denied when the user blocked location once',
    () async {
      final source = _FakeLocationSource(
        permission: RiderLocationPermission.denied,
        nextPermissionRequest: RiderLocationPermission.deniedForever,
      );
      final service = RiderLocationService(
        source: source,
        postLocation: (_) async {},
      );

      final outcome = await service.reportOnce();

      expect(outcome, RiderLocationReport.permissionPermanentlyDenied);
    },
  );

  test('reports unavailable when location services are disabled', () async {
    final service = RiderLocationService(
      source: _FakeLocationSource(serviceEnabled: false),
      postLocation: (_) async {},
    );

    expect(await service.reportOnce(), RiderLocationReport.locationUnavailable);
  });

  test('reports unavailable when the platform has no position yet', () async {
    final service = RiderLocationService(
      source: _FakeLocationSource(position: null),
      postLocation: (_) async {},
    );

    expect(await service.reportOnce(), RiderLocationReport.locationUnavailable);
  });

  test('reports failed when posting to the backend throws', () async {
    final service = RiderLocationService(
      source: _FakeLocationSource(),
      postLocation: (_) async => throw const RiderApiException('down'),
    );

    expect(await service.reportOnce(), RiderLocationReport.failed);
  });

  test('start reports immediately and periodically until stopped', () async {
    final source = _FakeLocationSource();
    var posts = 0;
    final service = RiderLocationService(
      source: source,
      interval: const Duration(milliseconds: 10),
      postLocation: (_) async {
        posts += 1;
      },
    );

    service.start();
    await Future<void>.delayed(const Duration(milliseconds: 45));
    service.stop();

    expect(service.isRunning, isFalse);
    expect(posts, greaterThanOrEqualTo(3));

    final later = posts;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(posts, later);
  });
}
