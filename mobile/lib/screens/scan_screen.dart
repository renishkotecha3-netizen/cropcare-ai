import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
import '../services/api.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

class ScanScreen extends StatefulWidget {
  final AppState state;
  final Map<String, dynamic>? parent;

  const ScanScreen({
    super.key,
    required this.state,
    this.parent,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  XFile? selected;
  Uint8List? preview;

  final notes = TextEditingController();
  static const crops = ['Auto', 'Tomato', 'Potato'];

  String crop = 'Auto';
  String progress = 'Checking location…';
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();

    final previousCrop = widget.parent?['crop']?.toString();
    crop = crops.contains(previousCrop) ? previousCrop! : 'Auto';

    recoverImage();
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<void> recoverImage() async {
    try {
      final lost = await ImagePicker().retrieveLostData();

      if (lost.files?.isNotEmpty ?? false) {
        await setImage(lost.files!.first);
      }
    } catch (_) {
      // Lost-image recovery is unavailable on some platforms.
    }
  }

  Future<void> setImage(XFile file) async {
    final data = await file.readAsBytes();

    if (data.length > 8 * 1024 * 1024) {
      throw Exception('Choose an image smaller than 8 MB.');
    }

    if (!mounted) return;

    setState(() {
      selected = file;
      preview = data;
      error = null;
    });
  }

  Future<void> pick(ImageSource source) async {
    if (busy) return;

    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 94,
      );

      if (photo != null) {
        await setImage(photo);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error =
            'Could not open the photo. Check camera/photo permission '
            'in your phone settings. $e';
      });
    }
  }

  bool locationPermissionGranted(LocationPermission permission) {
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<void> showLocationSettings({
    required String message,
    required bool appSettings,
  }) async {
    if (!mounted) return;

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Location required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    if (shouldOpen != true || !mounted) return;

    try {
      final opened = appSettings
          ? await Geolocator.openAppSettings()
          : await Geolocator.openLocationSettings();

      if (!opened && mounted) {
        setState(() {
          error =
              'Open phone Settings manually. Turn on Location and '
              'allow location permission for CropCare AI.';
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        error =
            'Open phone Settings manually. Turn on Location and '
            'allow location permission for CropCare AI.';
      });
    }
  }

  Future<bool> requireLocationForAnalysis() async {
    // Location/GPS must be switched on.
    final enabled = await Geolocator.isLocationServiceEnabled();

    if (!mounted) return false;

    if (!enabled) {
      setState(() {
        error = 'Turn on Location/GPS before analyzing your leaf.';
      });

      await showLocationSettings(
        message:
            'Phone Location/GPS must be ON to analyze a leaf. '
            'Turn it on, return to this app, and tap Analyze leaf again.',
        appSettings: false,
      );

      return false;
    }

    // Request permission if it has not been granted.
    var permission = await Geolocator.checkPermission();

    if (!mounted) return false;

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (!mounted) return false;

    if (!locationPermissionGranted(permission)) {
      setState(() {
        error = 'Location permission is required to analyze your leaf.';
      });

      await showLocationSettings(
        message:
            'Allow Location while using CropCare AI. '
            'Then return to the app and tap Analyze leaf again.',
        appSettings: true,
      );

      return false;
    }

    setState(() {
      progress = 'Getting your location…';
    });

    // Obtain a current position instead of using saved coordinates.
    late final Position position;

    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 30),
        ),
      );
    } on TimeoutException {
      throw Exception(
        'Could not get your current location. '
        'Move to an open area and try again. '
        'Your image has not been uploaded.',
      );
    }

    if (!mounted) return false;

    setState(() {
      progress = 'Saving your location…';
    });

    // The existing Django backend copies profile coordinates
    // into the new scan. Sharing preferences are not changed.
    await widget.state.updateProfile({
      'latitude': position.latitude,
      'longitude': position.longitude,
    });

    if (!mounted) return false;

    // Check again immediately before allowing the image upload.
    final stillEnabled = await Geolocator.isLocationServiceEnabled();
    final latestPermission = await Geolocator.checkPermission();

    if (!mounted) return false;

    if (!stillEnabled) {
      setState(() {
        error = 'Location was turned off. Enable it and try again.';
      });

      await showLocationSettings(
        message:
            'Location was turned off before analysis started. '
            'Turn it on, return, and tap Analyze leaf again.',
        appSettings: false,
      );

      return false;
    }

    if (!locationPermissionGranted(latestPermission)) {
      setState(() {
        error = 'Location permission was removed. Allow it and try again.';
      });

      await showLocationSettings(
        message:
            'Allow Location while using CropCare AI, '
            'then return and tap Analyze leaf again.',
        appSettings: true,
      );

      return false;
    }

    return true;
  }

  Future<void> analyze() async {
    if (selected == null || busy) return;

    setState(() {
      busy = true;
      error = null;
      progress = 'Checking location…';
    });

    try {
      final locationReady = await requireLocationForAnalysis();

      // Stop here if GPS, permission, or current location is unavailable.
      if (!locationReady || !mounted) return;

      setState(() {
        progress = 'Analyzing your leaf…';
      });

      final scan = await widget.state.api.analyze(
        selected!,
        crop,
        notes.text,
        parentId: widget.parent?['id'],
      );

      await widget.state.syncReminders();

      if (!mounted) return;

      await widget.state.api.requireAnalysisLocation();
      if (!mounted) return;

      if (widget.parent != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              state: widget.state,
              initial: scan,
            ),
          ),
        );
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              state: widget.state,
              initial: scan,
            ),
          ),
        );

        if (!mounted) return;

        setState(() {
          selected = null;
          preview = null;
          notes.clear();
        });
      }
    } on AnalysisLocationException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message);
      await showLocationSettings(
        message: '${e.message} If an upload already started, check History before trying again.',
        appSettings: e.openAppSettings,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  Widget action(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback callback,
    bool primary,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: primary ? forest : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFFBBD8B9)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: busy ? null : callback,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primary ? Colors.white24 : paleGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icon,
                    color: primary ? Colors.white : forest,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: primary ? Colors.white : forest,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: primary ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: primary ? Colors.white : forest,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullName =
        widget.state.user?['full_name']?.toString().trim() ?? '';
    final firstName =
        fullName.isEmpty ? 'Farmer' : fullName.split(' ').first;

    final body = PageBody(
      children: [
        if (widget.parent == null)
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.only(bottom: 28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [forest, Color(0xFF48A346)],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 35,
                  backgroundColor: Colors.white24,
                  child: Icon(
                    Icons.eco,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, $firstName!',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Give your crops a little care.\n'
                        'Check a leaf with AI.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Text(
          widget.parent == null
              ? 'Analyze Your Crop'
              : 'Check your plant again',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 10),
        Text(
          widget.parent == null
              ? 'Take a clear photo of one crop leaf or select one from your gallery.'
              : 'Use a new photo from the same plant. This check will be linked to your earlier result.',
          style: const TextStyle(
            fontSize: 17,
            color: Colors.black54,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 22),
        if (preview == null)
          const EmptyPanel(
            icon: Icons.image_search_rounded,
            title: 'No image selected',
            message: 'Add a crop leaf image to begin',
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(
                children: [
                  Image.memory(
                    preview!,
                    height: 270,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton.filled(
                      onPressed: busy
                          ? null
                          : () {
                              setState(() {
                                selected = null;
                                preview = null;
                              });
                            },
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),
          ),
        action(
          Icons.camera_alt,
          'Take a Photo',
          'Use your camera',
          () => pick(ImageSource.camera),
          true,
        ),
        action(
          Icons.photo_library,
          'Choose from Gallery',
          'Select an existing image',
          () => pick(ImageSource.gallery),
          false,
        ),
        SectionCard(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: crop,
                decoration: const InputDecoration(labelText: 'Crop'),
                items: crops.map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item == 'Auto'
                          ? 'Detect crop automatically'
                          : item,
                    ),
                  );
                }).toList(),
                onChanged: busy || widget.parent != null
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            crop = value;
                          });
                        }
                      },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notes,
                maxLines: 3,
                maxLength: 2000,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Symptoms / treatment notes',
                  hintText:
                      'When did you notice it? What have you tried?',
                ),
              ),
              const Text(
                'Choose a tomato or potato leaf for analysis.',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
        SectionCard(
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on, color: forest),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Location/GPS must be ON to analyze a leaf. '
                  'Your current location updates your profile and '
                  'is saved with your report. Analyze at your farm '
                  'so the location represents your farm.',
                  style: TextStyle(height: 1.45),
                ),
              ),
            ],
          ),
        ),
        if (error != null) ErrorPanel(error!),
        FilledButton.icon(
          onPressed: selected == null || busy ? null : analyze,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(busy ? progress : 'Analyze leaf'),
        ),
        const SizedBox(height: 16),
        Text(
          widget.state.user?['share_reports'] == true
              ? 'Nearby sharing is on. Eligible reports contribute to anonymous local alerts.'
              : 'Your report is private. You can enable anonymous nearby sharing in Profile.',
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'AI results are suggestions, not a confirmed diagnosis. '
          'A high score cannot guarantee that an image is a supported leaf.',
          style: TextStyle(
            color: Colors.black54,
            fontSize: 12,
          ),
        ),
      ],
    );

    return widget.parent == null
        ? body
        : Scaffold(
            appBar: AppBar(
              title: const Text('Follow-up photo'),
            ),
            body: SafeArea(child: body),
          );
  }
}
