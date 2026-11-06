# LifeVerse Flutter app

See the [LifeVerse project README](../README.md) for setup, API configuration, release status, and known feature limits.

## Run locally

Start the backend and MySQL first, then run:

```powershell
flutter pub get
flutter run -d chrome
```

The local API default is `http://localhost:3000/api` for web/desktop and `http://10.0.2.2:3000/api` for Android Emulator. Release builds require an explicit HTTPS API URL:

```powershell
flutter build apk --dart-define=API_BASE_URL=https://your-api-host/api
```
