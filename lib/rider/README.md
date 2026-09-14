# Rider module

The rider experience is isolated in this directory.

- `app.dart` owns the rider app theme, root widget, and navigation shell.
- `core/` is reserved for rider API, authentication, storage, notifications,
  location, and configuration infrastructure.
- `features/` contains the actual rider screens, grouped by product domain.
- `shared/` contains rider widgets, delivery state models, and theme primitives.

Backend-only folders are intentionally empty while the project is UI-only.
