import 'customer/app.dart' as customer;

export 'customer/app.dart' hide main;

/// Optional customer-only development entry point.
Future<void> main() => customer.main();
