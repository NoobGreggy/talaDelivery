import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tala_delivery_rider/main.dart';

const MethodChannel _storageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secure = <String, String>{};
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storageChannel, (call) async {
          final arguments =
              (call.arguments as Map?)?.map<String, dynamic>(
                (key, value) => MapEntry(key.toString(), value),
              ) ??
              {};
          switch (call.method) {
            case 'read':
              return secure[arguments['key']];
            case 'write':
              secure[arguments['key'] as String] = arguments['value'] as String;
              return null;
            case 'delete':
              secure.remove(arguments['key']);
              return null;
            case 'containsKey':
              return secure.containsKey(arguments['key']);
            default:
              return null;
          }
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_storageChannel, null);
  });

  test('save/read/clear round-trips through secure storage', () async {
    final store = SecureRiderTokenStore(const FlutterSecureStorage());

    await store.save('bearer-token');
    expect(await store.read(), 'bearer-token');

    await store.clear();
    expect(await store.read(), isNull);
  });

  test(
    'migrates a legacy SharedPreferences token into secure storage',
    () async {
      SharedPreferences.setMockInitialValues({
        'rider_auth_token': 'legacy-token',
      });
      final preferences = await SharedPreferences.getInstance();

      final store = await SecureRiderTokenStore.createAndMigrate(
        legacy: preferences,
      );

      expect(await store.read(), 'legacy-token');
      expect(preferences.getString('rider_auth_token'), isNull);
    },
  );

  test(
    'does not overwrite an existing secure token during migration',
    () async {
      secure['rider_auth_token'] = 'newer-token';
      SharedPreferences.setMockInitialValues({
        'rider_auth_token': 'legacy-token',
      });
      final preferences = await SharedPreferences.getInstance();

      final store = await SecureRiderTokenStore.createAndMigrate(
        legacy: preferences,
      );

      expect(await store.read(), 'newer-token');
      expect(preferences.getString('rider_auth_token'), 'legacy-token');
    },
  );
}
