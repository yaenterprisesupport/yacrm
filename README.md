# YA CRM — Flutter mobile client

1. Install Flutter (3.27+).
2. In this folder: `flutter create --org in.co.yatech --project-name ya_crm .`  (adds android/ and ios/)
3. **Release builds:** add `<uses-permission android:name="android.permission.INTERNET"/>` to
   `android/app/src/main/AndroidManifest.xml` (inside `<manifest>`, above `<application>`).
4. `flutter pub get && flutter run`
5. APK: `flutter build apk --release`

Base URL is set in `lib/api.dart` (`kBaseUrl`).
Add a module by appending one `Module(...)` entry in `lib/modules.dart`.

## Get the APK without installing anything
Push this folder to a GitHub repo → Actions tab → "Build APK" → download the `ya-crm-apk` artifact
(`app-release.apk`). It is signed with the debug key, which is fine for sideloading; use your own
keystore before publishing to the Play Store.
