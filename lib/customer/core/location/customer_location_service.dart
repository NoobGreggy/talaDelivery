part of '../../app.dart';

enum CustomerLocationStatus {
  available,
  permissionDenied,
  permissionPermanentlyDenied,
  servicesDisabled,
  unavailable,
}

class CustomerLocationResult {
  const CustomerLocationResult(
    this.status, {
    this.point,
    this.isApproximate = false,
    this.accuracyMeters,
  });

  final CustomerLocationStatus status;
  final CustomerMapPoint? point;
  final bool isApproximate;
  final double? accuracyMeters;
}

abstract class CustomerLocationService {
  Future<CustomerLocationResult> currentLocation();
}

class GeolocatorCustomerLocationService implements CustomerLocationService {
  const GeolocatorCustomerLocationService();

  @override
  Future<CustomerLocationResult> currentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const CustomerLocationResult(
          CustomerLocationStatus.servicesDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const CustomerLocationResult(
          CustomerLocationStatus.permissionPermanentlyDenied,
        );
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return const CustomerLocationResult(
          CustomerLocationStatus.permissionDenied,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      var isApproximate = position.accuracy > 100;
      try {
        isApproximate =
            isApproximate ||
            await Geolocator.getLocationAccuracy() ==
                LocationAccuracyStatus.reduced;
      } catch (_) {
        // Accuracy authorization is not reported on every platform.
      }

      return CustomerLocationResult(
        CustomerLocationStatus.available,
        point: CustomerMapPoint(position.latitude, position.longitude),
        isApproximate: isApproximate,
        accuracyMeters: position.accuracy,
      );
    } catch (_) {
      return const CustomerLocationResult(CustomerLocationStatus.unavailable);
    }
  }
}
