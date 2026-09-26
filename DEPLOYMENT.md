# Deployment

The Flutter web app is configured for Firebase Hosting. The API and MySQL are
defined as a Render Blueprint in `render.yaml`.

## Render

1. Push this repository to GitHub and create a Render Blueprint from it.
2. Review the Blueprint before applying it. It creates an API service, a
   private MySQL service, and a 10 GB persistent MySQL disk.
3. Wait for both services to deploy. Render generates separate MySQL passwords
   and wires them to the API as environment variables.
4. Copy the API service's HTTPS URL for the Flutter build below.

The API uses a 2 GB service because it loads the image-classification models.
Render currently lists that service size at $25/month. The MySQL service uses a
512 MB plan listed at $7/month, plus $0.25/GB/month for its 10 GB persistent
disk (about $2.50/month). This is about $34.50/month before bandwidth or other
usage. Confirm current prices in Render before applying the Blueprint.

## Firebase Hosting

From the repository root, build the web app with the deployed API URL and then
deploy the static output:

```powershell
flutter build web --dart-define=API_BASE_URL=https://YOUR-API.onrender.com
firebase deploy --only hosting
```

The API's `CORS_ALLOW_ORIGINS` is set to the Firebase `web.app` origin. If the
Firebase Hosting site uses a different origin or a custom domain, update that
environment variable in Render to include the exact browser origin(s),
comma-separated.

## Android and other platforms

Builds that call the hosted API must use its HTTPS URL with
`--dart-define=API_BASE_URL=...`.

- **Android private install:** `flutter build apk --release`. The current
  Android release configuration uses the debug signing key, so this is for
  private testing only and is not suitable for Google Play.
- **Google Play:** set a permanent, unique Android application ID, register
  that ID in Firebase, create and securely store an upload keystore, configure
  release signing, and build with `flutter build appbundle`. The current ID is
  still `com.example.kabadiwala_connect`.
- **iOS and macOS:** build and sign on macOS with Xcode and the corresponding
  Apple Developer account.
- **Windows and Linux:** build on the matching operating system; each platform
  uses its own installer or package format.

Flutter's official platform deployment guides cover the build and signing
steps for [Android](https://docs.flutter.dev/deployment/android),
[iOS](https://docs.flutter.dev/deployment/ios),
[web](https://docs.flutter.dev/deployment/web), and
[desktop](https://docs.flutter.dev/deployment).

## Database data

The Render MySQL service starts empty. Import only the records you want
available in the hosted app after the database is running; local database
credentials and data are not copied by the Blueprint.
