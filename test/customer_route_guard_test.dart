import 'package:flutter_test/flutter_test.dart';
import 'package:tala_delivery_customer/main.dart';

void main() {
  group('CustomerRouteController', () {
    test('protects authenticated customer routes', () {
      final routes = CustomerRouteController(
        CustomerSession(isRestoring: false),
      );

      expect(routes.guardLocation(CustomerRoutes.home), CustomerRoutes.login);

      routes.signInAsCustomer();
      expect(
        routes.guardLocation(CustomerRoutes.home),
        CustomerRoutes.addressSetup,
      );

      routes.completeAddressSetup();
      expect(routes.guardLocation(CustomerRoutes.home), CustomerRoutes.home);
    });

    test('restores the requested route after login and setup', () {
      final routes = CustomerRouteController(
        CustomerSession(isRestoring: false),
      );

      expect(
        routes.guardLocation(CustomerRoutes.notifications),
        CustomerRoutes.login,
      );

      routes.signInAsCustomer();
      expect(routes.destinationAfterSignIn().name, CustomerRoutes.addressSetup);

      routes.completeAddressSetup();
      expect(
        routes.destinationAfterAddressSetup().name,
        CustomerRoutes.notifications,
      );
    });

    test('blocks the wrong role and unknown routes', () {
      final routes = CustomerRouteController(
        CustomerSession(
          isRestoring: false,
          isAuthenticated: true,
          role: CustomerUserRole.rider,
          hasDeliveryAddress: true,
        ),
      );

      expect(
        routes.guardLocation(CustomerRoutes.home),
        CustomerRoutes.accessDenied,
      );
      expect(routes.guardLocation('/does-not-exist'), CustomerRoutes.notFound);
    });
  });
}
