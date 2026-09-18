# Notification delivery

## What works without Firebase

- Django creates a seven-day due date whenever a scan has an `issue` result.
- After a successful scan and on app resume, Flutter fetches upcoming reminders and schedules local phone notifications.
- Android uses **inexact** alarms, so no exact-alarm permission is requested. Delivery may be delayed by the phone's power policy. Reboot receivers restore scheduled reminders.
- Reminder times are stored in UTC and scheduled as absolute instants. The UI displays the phone's local time.
- The server creates a persistent in-app notification when due. An event key prevents duplicate database notifications.
- Marking a scan resolved, deleting it, or submitting its linked follow-up cancels its outstanding local reminder at the next sync. Signing out clears local schedules on that phone.
- Nearby reports create persistent in-app notifications for opted-in farmers within their saved radius. They appear when the app refreshes Alerts.

Grant notification permission through **Alerts → Enable phone reminders**. Scheduled notifications do not survive app uninstall. The in-app journal remains on the server.

## Optional Firebase: nearby alerts while the app is closed

Use a Firebase project that you own. No project or keys are preconfigured.

1. Add an Android app to Firebase with the exact `applicationId` from `mobile/android/app/build.gradle.kts` (normally `com.cropcare.cropcare_ai`). Register a separate iOS app if needed.
2. Copy `mobile/dart_defines.example.json` to `mobile/dart_defines.json`.
3. Set `ENABLE_PUSH` to `true` and fill `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_SENDER_ID`, and `FIREBASE_PROJECT_ID` with the app's Firebase options. Set your real API URL. Flutter initializes Firebase explicitly with these options; no fabricated Firebase config is included.
4. Install the server push dependency:

```bat
cd backend
.venv\Scripts\activate
pip install -r requirements-push.txt
```

5. Download your Firebase Admin service account to a private location outside the project. Set in `backend/.env`:

```dotenv
FCM_ENABLED=true
GOOGLE_APPLICATION_CREDENTIALS=C:/private/cropcare-firebase-admin.json
```

6. Restart Django and run `python manage.py process_notifications --watch` in another terminal.
7. From `mobile`, run:

```bat
flutter run --dart-define-from-file=dart_defines.json
```

8. Sign in, save the farm location, enable nearby alerts in Profile, and tap **Enable phone reminders** in Alerts. This registers the device token with the account. Repeat on any new installation or after signing into a different account.

Foreground messages use the local notification channel. Background/closed-app notification payloads are displayed by Firebase/Android. Opening one takes the user to Alerts. Firebase does not guarantee delivery when Android has force-stopped an app.

Seven-day checks use local scheduling even with Firebase enabled to avoid sending a second reminder banner. Server-side reminder records persist independently. The worker's nearby push transport is at-least-once: transient failures are retried, and clients use the notification ID to deduplicate foreground banners.

For iOS, configure APNs credentials in Firebase, Push Notifications capability, signing, and the corresponding iOS Firebase app options. Verify delivery on a physical device. Never copy the Admin service-account file into Flutter assets or distribute it in an APK.

## Radius, report eligibility and privacy

- Reports are eligible for 14 days and must have at least 80% confidence, issue status, stored approximate coordinates and current sharing consent.
- Nutrition/unknown categories, healthy/inconclusive scans and linked follow-ups do not broadcast. Resolved reports no longer appear in nearby summaries.
- Distances use the Haversine formula. Scan coordinates are rounded to two decimal places, so boundary distances are approximate.
- Recipients use their saved farm location; the app does not track movement in the background.
- At most one alert for the same predicted class, recipient and UTC day is created. Nearby summaries can show multiple reports.
- Turning off sharing removes existing reports from future nearby summaries. Notifications already delivered cannot be recalled. Turning off receipt stops new notifications and marks existing unread nearby entries read.
- Weather requests use rounded coordinates with Open-Meteo. Nearby users never receive exact coordinates, farmer names, photos or scan identifiers.
