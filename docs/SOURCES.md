# Implementation references

The app's exact model and label order come from your attachments, not an external model or a guessed class list.

- [Django 5.2 release notes](https://docs.djangoproject.com/en/5.2/releases/5.2/) — framework support and release line.
- [Django REST Framework](https://www.django-rest-framework.org/) — API serializers, views, authentication and throttling.
- [Flutter local notifications 19.5.0](https://pub.dev/packages/flutter_local_notifications/versions/19.5.0) — notification setup, Android desugaring, receivers and time-zone-aware schedules.
- [Open-Meteo API documentation](https://open-meteo.com/en/docs) — weather field names, units and provider attribution.
- [University of Minnesota Extension: late blight of tomato and potato](https://extension.umn.edu/agriculture/specialty-crops/vegetable-farming/disease-management/late-blight) — general wet-weather disease vigilance. This is not a pesticide recommendation for India or another jurisdiction.
- [Flutter Android deployment](https://docs.flutter.dev/deployment/android) — device builds and release signing.
- [Firebase Flutter messaging](https://firebase.google.com/docs/cloud-messaging/flutter/client) — configuring a project and device registration for optional remote notifications.

Weather thresholds and app confidence cutoffs are implementation choices. They are not quoted agronomic thresholds, proof of an outbreak, or a validated forecast.
