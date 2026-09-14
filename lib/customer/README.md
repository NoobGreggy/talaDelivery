# Customer module

The customer experience is isolated in this directory.

- `app.dart` owns the customer app theme, root widget, and navigation shell.
- `core/` is reserved for customer API, authentication, storage,
  notifications, location, and configuration infrastructure. The notification
  UI currently lives here because it maps directly to that service boundary.
- `features/` contains the actual customer screens, grouped by product domain.
- `shared/` contains customer widgets, catalog models, and theme primitives.

Backend-only folders are intentionally empty while the project is UI-only.
