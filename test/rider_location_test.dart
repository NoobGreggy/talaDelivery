import 'dart:async';

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
  test(
    'continuous stream uses active foreground service and stops after delivery',
    () async {
      final source = _StreamingSource();
      final tracked = <int>[];
      final service =
          RiderLocationService(
              source: source,
              postLocation: (_) async {},
              postTrackedLocation: (_, id) async => tracked.add(id),
            )
            ..setActiveDelivery(22)
            ..start();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(source.backgroundModes, [true]);
      service.setForeground(false);
      source.push(const RiderLatLng(16.95, 121.77));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(service.position.value?.latitude, 16.95);
      expect(tracked, [22, 22]);
      service.stop();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(source.cancellations, 1);
      final count = tracked.length;
      source.push(const RiderLatLng(16.96, 121.78));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(tracked.length, count);
      service.dispose();
      await source.samples.close();
    },
  );
  test(
    'active delivery upgrades availability stream and completion downgrades',
    () async {
      final source = _StreamingSource();
      final service = RiderLocationService(
        source: source,
        postLocation: (_) async {},
      )..start();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      service.setActiveDelivery(22);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      service.setActiveDelivery(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(source.backgroundModes, [false, true, false]);
      service.dispose();
      await source.samples.close();
    },
  );
  test(
    'does not ask for permission in the background or post invalid/stale GPS',
    () async {
      final source = _FakeLocationSource(
        permission: RiderLocationPermission.denied,
      );
      final service = RiderLocationService(
        source: source,
        postLocation: (_) async => fail('Unexpected report'),
      );
      service.setForeground(false);
      expect(await service.reportOnce(), RiderLocationReport.permissionDenied);
      expect(source.permissionRequests, 0);
      source.permission = RiderLocationPermission.granted;
      source.position = const RiderLatLng(91, 121);
      expect(
        await service.reportOnce(),
        RiderLocationReport.locationUnavailable,
      );
      source.position = RiderLatLng(
        16.94,
        121.76,
        recordedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      );
      expect(
        await service.reportOnce(),
        RiderLocationReport.locationUnavailable,
      );
      service.dispose();
    },
  );
  test('stop during GPS lookup prevents a late report', () async {
    final source = _DelayedSource();
    final service = RiderLocationService(
      source: source,
      postLocation: (_) async => fail('Late report'),
    );
    final pending = service.reportOnce();
    await Future<void>.delayed(Duration.zero);
    service.stop();
    source.result.complete(const RiderLatLng(16.94, 121.76));
    expect(await pending, RiderLocationReport.unchanged);
    service.dispose();
  });
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
      minimumDistanceMeters: 0,
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

  test('active delivery uses tracked location callback', () async {
    final source = _FakeLocationSource(
      position: RiderLatLng(14.5, 121, accuracy: 7, recordedAt: DateTime.now()),
    );
    var idlePosts = 0;
    RiderLatLng? tracked;
    int? trackedDeliveryId;
    final service = RiderLocationService(
      source: source,
      postLocation: (_) async => idlePosts += 1,
      postTrackedLocation: (position, deliveryId) async {
        tracked = position;
        trackedDeliveryId = deliveryId;
      },
    )..setActiveDelivery(42);

    expect(await service.reportOnce(), RiderLocationReport.posted);
    expect(idlePosts, 0);
    expect(trackedDeliveryId, 42);
    expect(tracked?.accuracy, 7);
  });

  test('does not post duplicate coordinates inside ten meters', () async {
    final source = _FakeLocationSource(
      position: const RiderLatLng(14.5, 121, accuracy: 8),
    );
    var posts = 0;
    final service = RiderLocationService(
      source: source,
      postLocation: (_) async => posts += 1,
    );

    expect(await service.reportOnce(), RiderLocationReport.posted);
    source.position = const RiderLatLng(14.50001, 121, accuracy: 8);
    expect(await service.reportOnce(), RiderLocationReport.unchanged);
    expect(posts, 1);
  });

  test('rejects a very inaccurate GPS reading', () async {
    var posts = 0;
    final service = RiderLocationService(
      source: _FakeLocationSource(
        position: const RiderLatLng(14.5, 121, accuracy: 250),
      ),
      postLocation: (_) async => posts += 1,
    );

    expect(await service.reportOnce(), RiderLocationReport.lowAccuracy);
    expect(posts, 0);
  });
}

class _StreamingSource extends _FakeLocationSource
    implements RiderStreamingLocationSource {
  final samples = StreamController<RiderLatLng>.broadcast(sync: true);
  final backgroundModes = <bool>[];
  int cancellations = 0;
  @override
  Stream<RiderLatLng> positions({required bool background}) {
    backgroundModes.add(background);
    return samples.stream
        .transform(
          StreamTransformer<RiderLatLng, RiderLatLng>.fromHandlers(
            handleDone: (sink) => sink.close(),
          ),
        )
        .asBroadcastStream(
          onCancel: (subscription) {
            cancellations++;
            subscription.cancel();
          },
        );
  }

  void push(RiderLatLng point) {
    position = point;
    samples.add(point);
  }
}

class _DelayedSource extends _FakeLocationSource {
  final result = Completer<RiderLatLng?>();
  @override
  Future<RiderLatLng?> currentPosition() => result.future;
}
