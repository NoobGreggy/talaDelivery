// Opt-in local integration check. Reads existing rider state only.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tala_delivery_rider/main.dart';

void main() {
  test(
    'native Flutter rider client connects to live Nest API and Socket.IO',
    () async {
      final client = http.Client(), tokens = MemoryRiderTokenStore();
      final config = RiderApiConfig.fromEnvironment();
      final api = RiderApiClient(client, config, tokens);
      final repository = ApiRiderRepository(api, tokens);
      final realtime = RiderRealtimeService(
        config: RiderRealtimeConfig(socketUrl: config.socketUri),
        readToken: api.accessToken,
      );
      try {
        final user = await repository.login(
          email: 'rider_1790708522081@test.com',
          password: 'Rider@123456',
        );
        final profile = await repository.profile();
        expect(profile.user.id, user.id);
        final deliveries = await repository.deliveries();
        expect(deliveries, isNotEmpty);
        expect(deliveries.first.order?.number, isNotEmpty);
        expect(deliveries.first.order?.items, isNotEmpty);
        expect(deliveries.first.store, isNotNull);
        await repository.offers();
        await repository.notifications();
        await repository.earningsSummary();
        final connected = realtime.events.firstWhere(
          (e) => e.name == 'realtime.connected',
        );
        await realtime.start(userId: user.id);
        await connected.timeout(const Duration(seconds: 12));
        expect(realtime.state, RiderRealtimeState.connected);
        final reconnected = realtime.events.firstWhere(
          (e) => e.name == 'realtime.connected',
        );
        await realtime.reconnect();
        await reconnected.timeout(const Duration(seconds: 12));
        expect(realtime.state, RiderRealtimeState.connected);
      } finally {
        await realtime.stop();
        realtime.dispose();
        client.close();
      }
    },
    skip: !const bool.fromEnvironment('TALA_RUN_LIVE_RIDER_TEST'),
    timeout: const Timeout(Duration(seconds: 40)),
  );
}
