# NewEra Flutter App

A Flutter app built with NewEra. Builds for web, Android (APK), and iOS (unsigned).

## Build targets

The NewEra workflow auto-detects `pubspec.yaml` and builds:

- **Web**: `flutter build web` → `build/web/` (deployable to Cloudflare/EdgeOne)
- **Android APK**: `flutter build apk` → `build/app/outputs/flutter-apk/app-release.apk`
- **iOS**: `flutter build ios --no-codesign` → `build/ios/iphoneos/Runner.app` (unsigned, needs macOS runner)

## Local development

```bash
flutter pub get
flutter run
```
