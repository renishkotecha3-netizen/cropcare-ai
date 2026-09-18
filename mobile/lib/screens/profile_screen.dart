import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../app_state.dart';
import '../widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  final AppState state;
  const ProfileScreen({super.key, required this.state});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      farm = TextEditingController(),
      village = TextEditingController(),
      lat = TextEditingController(),
      lon = TextEditingController();
  bool sharing = false, alerts = false, busy = false, locating = false;
  double radius = 5;
  @override
  void initState() {
    super.initState();
    final u = widget.state.user!;
    name.text = u['full_name'];
    farm.text = u['farm_name'];
    village.text = u['village'];
    lat.text = u['latitude']?.toString() ?? '';
    lon.text = u['longitude']?.toString() ?? '';
    sharing = u['share_reports'];
    alerts = u['nearby_alerts'];
    radius = (u['alert_radius_km'] as num).toDouble();
  }

  @override
  void dispose() {
    for (final c in [name, farm, village, lat, lon]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> locate() async {
    setState(() => locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled())
        throw Exception(
          'Turn on location services on your phone, or enter farm coordinates below.',
        );
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever)
        throw Exception(
          'Location access is disabled in Settings. You can still enter coordinates manually.',
        );
      if (permission == LocationPermission.denied)
        throw Exception('Location permission was not granted.');
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (mounted)
        setState(() {
          lat.text = p.latitude.toStringAsFixed(5);
          lon.text = p.longitude.toStringAsFixed(5);
        });
    } catch (e) {
      if (mounted) showMessage(context, e.toString());
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (lat.text.trim().isEmpty != lon.text.trim().isEmpty) {
      showMessage(context, 'Enter both coordinates, or clear both.');
      return;
    }
    setState(() => busy = true);
    try {
      await widget.state.updateProfile({
        'full_name': name.text.trim(),
        'farm_name': farm.text.trim(),
        'village': village.text.trim(),
        'latitude': lat.text.trim().isEmpty
            ? null
            : double.parse(lat.text.trim()),
        'longitude': lon.text.trim().isEmpty
            ? null
            : double.parse(lon.text.trim()),
        'share_reports': sharing,
        'nearby_alerts': alerts,
        'alert_radius_km': radius.round(),
      });
      if (mounted) showMessage(context, 'Your farm profile has been saved.');
    } catch (e) {
      if (mounted) showMessage(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String? coordinate(String? input, bool latitude) {
    if (input == null || input.trim().isEmpty) return null;
    final v = double.tryParse(input.trim());
    final max = latitude ? 90 : 180;
    return v == null || !v.isFinite || v.abs() > max
        ? 'Use a number from -$max to $max.'
        : null;
  }

  Future<void> passwordDialog() async {
    final current = TextEditingController(), next = TextEditingController();
    bool saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Change password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: current,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current password',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: next,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: saving
                  ? null
                  : () async {
                      update(() => saving = true);
                      try {
                        final result = await widget.state.api
                            .call('POST', 'auth/password/', {
                              'current_password': current.text,
                              'new_password': next.text,
                            });
                        await widget.state.api.saveToken(result['token']);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted)
                          showMessage(
                            context,
                            'Password changed. Other sessions have been signed out.',
                          );
                      } catch (e) {
                        if (ctx.mounted)
                          update(() {
                            saving = false;
                            error = e.toString();
                          });
                      }
                    },
              child: Text(saving ? 'Saving…' : 'Update'),
            ),
          ],
        ),
      ),
    );
    // Dispose after the dialog's closing animation has detached its fields.
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      current.dispose();
      next.dispose();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My farm & profile')),
    body: SafeArea(
      child: PageBody(
        children: [
          SectionCard(
            child: Form(
              key: form,
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 35,
                    backgroundColor: paleGreen,
                    child: Icon(Icons.person_outline, color: forest, size: 38),
                  ),
                  const SizedBox(height: 12),
                  Text(widget.state.user?['email'] ?? ''),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter your name.'
                        : null,
                    maxLength: 100,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: farm,
                    decoration: const InputDecoration(labelText: 'Farm name'),
                    maxLength: 120,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: village,
                    decoration: const InputDecoration(
                      labelText: 'Village / city',
                    ),
                    maxLength: 120,
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Farm location',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use your current location only when you are at the farm. You can enter farm coordinates manually. Rounded coordinates are sent to Open-Meteo for weather.',
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: locating ? null : locate,
                    icon: const Icon(Icons.my_location),
                    label: Text(
                      locating ? 'Finding location…' : 'Use my location',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: lat,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    validator: (v) => coordinate(v, true),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: lon,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    validator: (v) => coordinate(v, false),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      lat.clear();
                      lon.clear();
                    }),
                    child: const Text('Clear saved location (then Save)'),
                  ),
                  const Divider(height: 28),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Share anonymous crop reports'),
                    subtitle: const Text(
                      'New eligible scans can inform nearby farmers. Turning this off removes your past reports from nearby results.',
                    ),
                    value: sharing,
                    onChanged: (v) => setState(() => sharing = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Receive nearby alerts'),
                    subtitle: const Text(
                      'Get updates about possible cases near your saved farm.',
                    ),
                    value: alerts,
                    onChanged: (v) => setState(() => alerts = v),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Alert radius: ${radius.round()} km',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    min: 1,
                    max: 50,
                    divisions: 49,
                    label: '${radius.round()} km',
                    value: radius,
                    onChanged: (v) => setState(() => radius = v),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy ? null : save,
                    child: Text(busy ? 'Saving…' : 'Save farm profile'),
                  ),
                ],
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: passwordDialog,
            icon: const Icon(Icons.lock_outline),
            label: const Text('Change password'),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () async {
              await widget.state.signOut();
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
          const SizedBox(height: 14),
          const Text(
            'CropCare AI 1.0\nAI guidance complements local agricultural expertise. Seven days is a follow-up interval, not a promise of recovery.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
