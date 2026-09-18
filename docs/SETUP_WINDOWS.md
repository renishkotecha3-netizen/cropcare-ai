# Run CropCare AI on Windows and Android

## 1. Install the tools

- Python **3.12, 64-bit**, with the Python launcher (`py`). The dependency versions in this project were tested with Python 3.12.
- Flutter **3.35.4 or newer compatible stable SDK**, with Flutter's `bin` directory on PATH.
- Android Studio with Android SDK, SDK command-line tools and an Android emulator. Use Android SDK 35 or higher and Java 17 or the Java runtime bundled with a compatible Android Studio.
- An internet connection for initial package installation and live weather. Analysis itself runs on your Django computer/server, not on the phone.

Check installation in Command Prompt:

```bat
py -3.12 --version
flutter --version
flutter doctor
flutter doctor --android-licenses
```

Extract the ZIP to a short location such as `C:\CropCare_AI`. Do not put it inside another project's virtual environment. This project uses Django and SQLite; Apache/XAMPP is not required.

## 2. Set up the backend

Double-click `scripts\setup_backend.bat`. It creates a virtual environment, installs dependencies, creates `.env` with a random secret, applies database migrations, and loads the real model for a compatibility check. TensorFlow is a large download.

Equivalent manual commands from the project folder:

```bat
cd backend
py -3.12 -m venv .venv
.venv\Scripts\activate
python -m pip install -r requirements.txt
copy .env.example .env
python manage.py migrate
python manage.py check_model
```

For manual setup, replace the example secret in `.env` with a random value. Keep `DJANGO_DEBUG=true` for local development only.

The files already present are:

```text
backend/crop_api/ai_model/crop_model_33.keras
backend/crop_api/ai_model/labels.txt
```

Do not rename or reorder the 33 labels. Do not divide image pixels by 255 again. The supplied model contains that rescaling operation.

Start the server with `scripts\start_backend.bat`, or:

```bat
python manage.py runserver 0.0.0.0:8000
```

Open `http://127.0.0.1:8000/api/health/` on your computer. It should return `{"status":"ok","service":"CropCare AI API"}`. Keep this terminal open.

## 3. Start the notification worker

In a second terminal, run `scripts\start_worker.bat`. It checks once per minute. Run **one worker** per database.

```bat
cd backend
.venv\Scripts\activate
python manage.py process_notifications --watch
```

The worker creates due in-app reminders and sends optional Firebase nearby alerts. The phone also schedules its own seven-day reminders. Without the worker, overdue in-app reminders are created when the user next opens Alerts or syncs reminders.

## 4. Set up Flutter

Run `scripts\setup_mobile.bat`. The archive contains application source and Android native files. The setup script completes native scaffolding (including the Gradle wrapper and iOS project), applies notification/location/photo configuration, and installs Flutter packages.

Manual equivalent (first generate the native scaffolding as shown next):

```bat
cd mobile
flutter pub get
py -3.12 ..\scripts\configure_mobile.py
```

Run this once to complete the native scaffolding and Gradle wrapper before the configuration script:

```bat
flutter create --platforms=android,ios --org com.cropcare --project-name cropcare_ai .
py -3.12 ..\scripts\configure_mobile.py
```

## 5A. Android emulator

Start an emulator in Android Studio. Then, from `mobile`:

```bat
flutter devices
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

`10.0.2.2` points from the standard Android emulator to your Windows computer. Do not use `localhost` inside the Android app for a server running on Windows.

## 5B. Physical Android phone

1. Put the phone and computer on the same Wi-Fi.
2. Enable developer options and USB debugging on the phone; connect it to the computer.
3. Run `ipconfig` on the computer. Find the Wi-Fi IPv4 address, for example `192.168.1.10`.
4. Add that address to `backend\.env`:

```dotenv
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,10.0.2.2,192.168.1.10
```

5. Restart Django. Allow Python through Windows Firewall on your private network if prompted.
6. In the phone's browser, check `http://192.168.1.10:8000/api/health/`.
7. From `mobile`, run:

```bat
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000/api
```

Use your real IPv4 address in both places. If it changes, update the address and run Flutter again.

## 6. Use the application

1. Create an account; passwords need at least eight characters and must pass the server's strength checks.
2. Open the profile icon. Save your name, farm, village, location and alert radius.
3. Enable anonymous report sharing and/or nearby alerts if you want those features. They are separate choices.
4. Open Alerts → **Enable phone reminders** and allow notifications.
5. On Scan, choose a crop, take/select a leaf photo, add notes, and tap **Analyze leaf**.
6. Review the result. Every successful analysis is saved in History.
7. When a seven-day reminder is due, open the plant check and add a follow-up photo. Record whether the plant improved, stayed the same, worsened or was resolved.

For a nearby-alert demonstration, register a second account on another emulator/phone, save a nearby farm location and enable nearby alerts. The first account must opt into sharing. A new qualifying result (issue, at least 80% confidence, not nutrition/unknown) creates an alert for the second account. Real model results are never replaced with demonstration predictions in the app.

## 7. Django administration

```bat
cd backend
.venv\Scripts\activate
python manage.py createsuperuser
```

Open `http://127.0.0.1:8000/admin/`. Use the superuser credentials you created. No preset admin password is shipped.

## 8. Android APK

For local testing on the same Wi-Fi:

```bat
cd mobile
flutter build apk --debug --dart-define=API_BASE_URL=http://192.168.1.10:8000/api
```

The APK will be at `mobile\build\app\outputs\flutter-apk\app-debug.apk`. Debug/profile builds permit local HTTP. A release build should point to your deployed HTTPS API and use your own signing key:

```bat
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR-SERVER/api
```

Configure signing for distribution following Flutter's official Android deployment guide. This package is source code; it does not provide your server, signing key or Firebase account.

## iOS

The setup script generates an iOS project and applies permissions. Building/signing requires macOS and Xcode. Set your team/bundle ID, install pods, use an HTTPS API, and grant photo, camera and location permissions. Firebase remote push also requires APNs setup. iOS push delivery needs device verification; Android is the primary setup path for this project.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| Cannot reach server | Verify `/api/health/` from the phone, LAN/emulator address, firewall, Django process and allowed hosts. |
| `DisallowedHost` | Add the computer's LAN IP to `.env`, restart Django. |
| Model unavailable | Run `python manage.py check_model`; verify Python 3.12, installed requirements, model and ordered labels. |
| Low confidence | Retake a sharp, well-lit leaf photo; select the correct supported crop. Do not treat based on score alone. |
| No nearby reports | Check consent, radius, 14-day window and qualifying confidence/category. Absence of reports is not absence of disease. |
| No phone reminder | Enable notifications in app/OS, open the app to sync and check OS battery restrictions. In-app reminders remain accessible. |
| No nearby push when closed | Configure Firebase on both sides; see `NOTIFICATIONS.md`; keep the worker running. |
| Weather unavailable | Save farm coordinates and ensure the backend can reach Open-Meteo. No fake forecast is substituted. |
| Android Gradle error | Run `flutter doctor`, use compatible Java/SDK versions, and run `configure_mobile.py` after regenerating native projects. |

## Before a public deployment

Use an HTTPS reverse proxy and a production WSGI server; do not expose Django `runserver`. Set a private random secret, `DJANGO_DEBUG=false`, correct allowed hosts and an appropriate database (for example PostgreSQL). Configure backups for the database and private photo directory. Keep model and Firebase credentials on the server, apply dependency security updates, and run a single supervised notification worker. Multi-instance services need a shared cache for throttling and weather caching, plus a coordinated notification worker. Complete real-device, model-accuracy and local agronomy validation before public use.
