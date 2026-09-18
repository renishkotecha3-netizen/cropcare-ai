import 'package:flutter/material.dart';
import 'services/api.dart';
import 'services/notifications.dart';

class AppState extends ChangeNotifier {
  final api = Api();
  final notifications = NotificationService();
  Map<String, dynamic>? user;
  bool loading = true;
  String? startupError;
  String? notificationError;
  bool signingOut = false;

  AppState() {
    api.onUnauthorized = () {
      signOut(remote: false);
    };
  }
  Future<void> init() async {
    loading = true;
    startupError = null;
    notifyListeners();
    try {
      if (!notifications.ready) {
        try {
          await notifications.init();
        } catch (_) {
          notificationError =
              'Phone notifications are unavailable. In-app reminders still work.';
        }
      }
      await api.restore();
      if (api.token != null)
        user = Map<String, dynamic>.from(await api.call('GET', 'profile/'));
    } catch (e) {
      startupError = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> authenticate(
    bool register,
    String email,
    String password,
    String name,
  ) async {
    final data = await api.call(
      'POST',
      register ? 'auth/register/' : 'auth/login/',
      {'email': email, 'password': password, if (register) 'full_name': name},
    );
    await api.saveToken(data['token']);
    user = Map<String, dynamic>.from(data['user']);
    startupError = null;
    notifyListeners();
    await syncReminders();
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    user = Map<String, dynamic>.from(await api.call('PATCH', 'profile/', data));
    notifyListeners();
  }

  Future<void> syncReminders() async {
    try {
      await notifications.sync(api);
      notificationError = null;
    } catch (_) {
      notificationError =
          'Your scan is saved. Open Alerts to check reminders; phone scheduling could not be updated.';
    }
    notifyListeners();
  }

  Future<void> signOut({bool remote = true}) async {
    if (signingOut) return;
    signingOut = true;
    try {
      if (remote && api.token != null)
        await api.call('POST', 'auth/logout/', {
          'device_token': notifications.deviceToken,
        });
    } catch (_) {
      /* Local sign-out still removes access from this phone. */
    }
    try {
      await notifications.clear();
    } catch (_) {
      /* OS notification service may be unavailable. */
    }
    await api.clear();
    user = null;
    startupError = null;
    signingOut = false;
    notifyListeners();
  }
}
