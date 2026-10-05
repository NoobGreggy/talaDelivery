# tala_delivery

A new Flutter project.

## API and realtime

The default API is `https://api.tala-works.online/api/v1/` and Socket.IO is
`https://realtime.tala-works.online` (namespace `/realtime`, path `/socket.io`).
Copy `config/local.example.json` to the ignored `config/local.json` and set your
private `TALA_API_KEY`; keep keys and Mapbox tokens out of Git.

```sh
flutter run --dart-define-from-file=config/local.json
flutter build apk --dart-define-from-file=config/local.json
```

Rebuild/reinstall existing mobile builds to use the new endpoints.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
