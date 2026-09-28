# Deployment

The Flutter web app is configured for Firebase Hosting. The default
`render.yaml` targets a $0 hobby deployment using Render's free API service
and a free Aiven MySQL database.

## Free backend setup

1. Create an Aiven MySQL service on its free plan and wait until it is running.
   From its **Overview / Connection information**, copy the MySQL URI and
   download its CA certificate. Use Aiven's database name (often `defaultdb`),
   or create `kabadiwala_db` from the Aiven **Databases** page.
2. The Git repository must be available to your Render account. If you do not
   own the source repository, fork it to your GitHub account first. In Render,
   create a Blueprint from your fork using `render.yaml`.
3. Set `KABADIWALA_DATABASE_URL` to the Aiven connection URI. It can use
   `mysql://` or `mysql+aiomysql://`; include `?ssl=true` if Aiven's URI does
   not already include an SSL option. Set `KABADIWALA_DB_SSL_CA` to the PEM
   contents of Aiven's CA certificate so the connection verifies the server.
   If Render's environment editor removes line breaks, base64-encode the PEM
   and set the variable to that single-line value instead.
   The application converts the URL to `mysql+aiomysql` and enables TLS. Keep
   both values in Render's environment settings; do not put credentials in
   source code. URL-encode special characters in the username or password.
4. Wait for the API service to deploy, then copy its HTTPS URL. The app creates
   its tables on startup. Local MySQL records are not copied automatically.

Free-tier limits apply: Render spins its free web service down after 15 minutes
without traffic (the next request may take about a minute to wake it). Aiven's
free MySQL service includes 1 GB RAM and 1 GB storage, and may be powered off
after a period without activity. The Render free configuration disables image
classification because the model's memory needs are not a reliable fit for the
free service. [Render free limits](https://render.com/docs/free) ·
[Aiven MySQL free tier](https://aiven.io/docs/products/mysql/concepts/mysql-free-tier)

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

The API allows the project's default `web.app` and `firebaseapp.com` domains,
Firebase preview channels, and localhost Flutter web development. If the site
uses a custom domain, set `CORS_ALLOW_ORIGINS` in Render to include its exact
origin (scheme and hostname, no trailing slash); separate multiple origins
with commas.

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
