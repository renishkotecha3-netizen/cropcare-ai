# Verification record

## Passed here

- **23 Django tests** passed, including account registration/login, password validation, session revocation, ownership of photos and history, file validation, missing-model failure handling, consent/radius matching, anonymous nearby responses, confidence/category exclusions, notification deduplication, reminder boundaries, follow-up ownership/linking, resolution, valid zero coordinates, invalid/nonfinite coordinates, weather outages/caching and weather advice scoped to the correct farmer.
- Django system check reported no issues. Database migrations were generated and applied by the test runner to an isolated database.
- The **real supplied Keras model** loaded with TensorFlow CPU 2.21.0 and Keras 3.15.1 on Python 3.12. It accepted a synthetic RGB tensor and produced 33 finite softmax values. This verifies runtime compatibility, not disease accuracy.
- `labels.txt` contains 33 unique names, used in the supplied order.
- The packaged model and labels were byte-compared with the uploaded files. Model SHA-256: `323bf39fee1f1e60190f4a977cb2a80cdcaab36e58dd6bd7f52ba8bf13c0fa06`.
- Offline Dart formatting/parser checks passed for application source and the included widget test. Android XML files and Python source were checked locally.
- TensorFlow 2.21.0 and NumPy 2.5.3 Windows/Python 3.12 wheels were available. The Windows runtime itself was not executed here.

## Not verified here

- Flutter dependency resolution, static type analysis, widget test execution and Android APK compilation did **not** complete. Automatic approval review blocked Flutter tool setup because it attempted to contact a cloud instance-metadata endpoint, which could expose environment credentials. The blocked operation was not retried. Offline Dart parsing is not a substitute for a Flutter build.
- Native Android files were assembled from the official Flutter 3.35.4 templates and configured without running Flutter. The local setup script completes the Gradle wrapper and creates the iOS scaffold.
- Camera, gallery, GPS, secure-storage behaviour and seven-day OS notifications need real-device testing. The optional Firebase integration needs the user's Firebase project and end-to-end delivery testing.
- Weather responses were tested with controlled provider payloads and failures; live weather availability depends on the backend's internet access.
- No held-out leaf dataset or confirmed ground-truth images were supplied. No accuracy, calibration, field reliability or treatment-effectiveness claim is made.

## Reproduce the checks locally

After backend setup:

```bat
cd backend
.venv\Scripts\activate
python manage.py test crop_api
python manage.py check_model
```

After Flutter setup:

```bat
cd mobile
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

Then verify on your intended phone: registration/login, a real leaf upload, history reopening, permission denial, saved farm location, two-account nearby alerts, reminder scheduling, follow-up upload, resolution and sign-out. Firebase background delivery and release signing are deployment checks.
