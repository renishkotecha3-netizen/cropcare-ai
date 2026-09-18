# CropCare AI

A Flutter mobile app and Django REST API built around your supplied 33-class EfficientNet model. The green home and result screens follow your two reference screenshots.

**Start here: [Windows / Android setup](docs/SETUP_WINDOWS.md).** Your model and the newly supplied labels are already included; you do not need to train again.

## Included features

- Registration, login, secure device session storage, logout and password changes.
- Camera/gallery leaf analysis for tomato, potato and bell pepper model classes.
- Confidence display, inconclusive results, top three suggestions and cautious care guidance.
- Private photo history, search, status filters, pagination, deletion and treatment notes.
- Farm location from GPS or manual coordinates; separate opt-in controls for sharing and receiving alerts.
- Nearby report summaries within 1–50 km, using recent eligible shared reports. No other farmer's identity, photo or exact location is exposed.
- Open-Meteo current weather, three-day outlook and rule-based crop care advice.
- Seven-day phone reminders, persistent in-app notifications, and linked follow-up photos with farmer-reported progress.
- Optional Firebase delivery of nearby alerts while the app is closed.
- Django administration and database migrations. SQLite is included as the local-development database; no XAMPP required.

## Folders

| Folder | Contents |
| --- | --- |
| `mobile/` | Flutter application, dependencies and Android native project files |
| `backend/` | Django API, model, supplied labels, migrations and tests |
| `scripts/` | Windows setup/start helpers and native permission configuration |
| `docs/` | Setup, API, notification configuration, architecture and verification |
| `reference/` | Original prediction/training scripts and UI screenshots |

## Run overview

1. Install Python 3.12 and Flutter with Android Studio.
2. Run `scripts/setup_backend.bat`, then `scripts/start_backend.bat`.
3. Run `scripts/setup_mobile.bat`.
4. Start an Android emulator, open a terminal in `mobile`, and run:

```sh
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

5. Register, set your farm location in Profile, enable phone reminders in Alerts, and analyze a leaf.

For a physical phone, use your computer's LAN address and add it to the backend's allowed hosts; see the detailed guide. Run `scripts/start_worker.bat` for proactive reminder creation and optional nearby push delivery.

## Important behaviour

- The original `crop_model_33.keras` and `labels.txt` are included unchanged. Input is RGB 224×224 with values 0–255; EfficientNet already contains rescaling.
- A score below 60%, or a mismatch with the selected crop, gives an inconclusive result. Scores below 80% are labelled low confidence. These are app rules, not calibrated guarantees or a reliable non-leaf detector.
- Nearby alerts are possible AI-reported cases, not verified outbreaks. Nutrition deficiencies, healthy results, inconclusive results, low-confidence results and follow-up duplicates do not trigger nearby broadcasts.
- Care advice is conservative and does not tell farmers to copy a neighbour's pesticide or dose. Weather advice is a transparent rule system, not a validated disease forecast.
- Seven days is a check-in date, not a promise that the plant will recover. Phone delivery requires notification permission and is subject to OS power controls. In-app reminders remain available when the app next connects.
- Firebase is optional. Without Firebase configuration, nearby alerts still appear in the Alerts tab; closed-app nearby push messages are not enabled.

See [verification](docs/VERIFICATION.md) for exactly what was tested and [sources](docs/SOURCES.md) for implementation references.
