# Deployment

The Flutter web app is configured for Firebase Hosting. The default
`render.yaml` targets a $0 hobby deployment using Render's free API service and
a free Supabase PostgreSQL database. A prior paid Render + MySQL design is no
longer the default.

## Free backend setup

1. Create a free Supabase project. In its **Connect** panel, select the
   **Session pooler** connection string for IPv4 and copy the PostgreSQL URI.
2. Push this repository to GitHub, then create a Render Blueprint using
   `render.yaml`. Supply the Supabase URI when Render prompts for
   `KABADIWALA_DATABASE_URL`.
3. Wait for the API service to deploy, then copy its HTTPS URL.
4. Supabase runs the app's SQLAlchemy schema creation on startup. Import any
   local records you want hosted separately; local records are not copied.

Free-tier limits apply: Render spins its free web service down after 15 minutes
without traffic (the next request may take about a minute to wake it), and
Supabase's free database may pause after a week without activity and has a
500 MB database limit. The Render free configuration disables image
classification because the model's memory needs are not a reliable fit for the
free service. [Render free limits](https://render.com/docs/free) ·
[Supabase free limits](https://supabase.com/pricing)

### Demo sign-in with Firebase test numbers

The login screen currently expects an Indian mobile number: it adds `+91` to
the 10 digits entered in the app. For a demo, configure a Firebase test number
so Firebase returns a fixed code without sending an SMS:

1. In Firebase Console, open **Authentication → Sign-in method** and enable
   **Phone**.
2. In **Phone numbers for testing**, add a fictional test number in `+91`
   format and choose a six-digit test code. Do not use a real person's number.
3. In the app, enter the same number's 10 digits (without `+91`), then enter
   the fixed code you configured.

Only numbers configured in that list can use the fixed demo code. Keep the
number and code private, and remove them when the demo ends. Real phone
verification uses SMS and may require a billing account. [Firebase phone-auth
testing](https://firebase.google.com/docs/auth/flutter/phone-auth) ·
[Firebase billing and phone-auth requirements](https://firebase.google.com/docs/auth/faq-and-troubleshooting)

## Firebase Hosting

From the repository root, build the web app with the deployed API URL and then
deploy the static output. Firebase Hosting has a no-cost Spark option within
its published quotas.

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

The hosted database starts empty. Import only the records you want available
in the hosted app after the database is running; local database credentials
and data are not copied by the Blueprint.
