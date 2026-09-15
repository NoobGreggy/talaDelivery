import 'package:flutter_test/flutter_test.dart';
import 'package:tala_delivery_rider/main.dart';

void main() {
  group('RiderRouteController', () {
    test('protects authenticated rider routes', () {
      final routes = RiderRouteController(RiderSession(isRestoring: false));

      expect(routes.guardLocation(RiderRoutes.dashboard), RiderRoutes.login);

      routes.signInAsRider();
      expect(
        routes.guardLocation(RiderRoutes.dashboard),
        RiderRoutes.dashboard,
      );
    });

    test('requires online and active delivery states', () {
      final routes = RiderRouteController(
        RiderSession(
          isRestoring: false,
          isAuthenticated: true,
          role: RiderUserRole.rider,
        ),
      );

      expect(routes.guardLocation(RiderRoutes.offer), RiderRoutes.dashboard);

      routes.setOnline(true);
      expect(routes.guardLocation(RiderRoutes.offer), RiderRoutes.offer);
      expect(
        routes.guardLocation(RiderRoutes.activeDelivery),
        RiderRoutes.dashboard,
      );

      routes.startDelivery();
      expect(
        routes.guardLocation(RiderRoutes.activeDelivery),
        RiderRoutes.activeDelivery,
      );
      expect(
        routes.guardLocation(RiderRoutes.deliveryComplete),
        RiderRoutes.activeDelivery,
      );

      routes.completeDelivery();
      expect(
        routes.guardLocation(RiderRoutes.deliveryComplete),
        RiderRoutes.deliveryComplete,
      );
    });

    test('blocks the wrong role and unknown routes', () {
      final routes = RiderRouteController(
        RiderSession(
          isRestoring: false,
          isAuthenticated: true,
          role: RiderUserRole.customer,
        ),
      );

      expect(
        routes.guardLocation(RiderRoutes.dashboard),
        RiderRoutes.accessDenied,
      );
      expect(routes.guardLocation('/does-not-exist'), RiderRoutes.notFound);
    });
  });
}
