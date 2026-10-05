# flutter_application_1

A new Flutter project.

## Public NestJS API and realtime

Configure the public endpoints in `config/local.json` (ignored by Git):
`TALA_API_BASE_URL=https://api.tala-works.online/api/v1/` and
`TALA_SOCKET_IO_URL=https://realtime.tala-works.online`. Set `TALA_API_KEY` to the
backend's `APP_API_KEY`; preserve the Mapbox token settings.

```powershell
C:\php\flutter\bin\flutter.bat build apk --debug --dart-define-from-file=config/local.json
```

Rebuild and install `build/app/outputs/flutter-apk/app-debug.apk` on an Android
phone. Sign in to the new API, save a geocoded address inside an active
delivery zone, and order from the store open in the merchant console on your PC.
The public HTTPS endpoints work without sharing the PC's LAN/Wi-Fi.

Platform categories come from `/store-categories`; the admin-selected stable
`icon` keys map to constant Flutter Material icons. Merchant product categories
come from `/stores/:id/categories` and are separate from platform store tags.
Orders use Nest camelCase request/response fields. Live updates use authenticated
Socket.IO `/realtime`, including Engine.IO ping/pong and user-room acknowledgements.

See the workspace `RUNNING.md` for the full local testing workflow.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
