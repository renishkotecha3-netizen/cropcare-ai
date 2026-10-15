import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../app_state.dart';
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

  String crop = 'Auto';
  final notes = TextEditingController();

  bool busy = false;
  String? error;
  String progress = 'Analyzing your leaf…';

  static const crops = ['Auto', 'Tomato', 'Potato'];

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
      // Lost-image recovery is not supported on every platform.
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
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    if (shouldOpen != true || !mounted) return;

    final opened = appSettings
        ? await Geolocator.openAppSettings()
        : await Geolocator.openLocationSettings();

    if (!opened && mounted) {
      setState(() {
        error =
            'Open your phone Settings manually and enable Location '
            'and location permission for CropCare AI.';
      });
    }
  }

  Future<bool> requireLocationForAnalysis() async {
    // First check the phone's Location/GPS switch.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!mounted) return false;

    if (!serviceEnabled) {
      setState(() {
        error = 'Location must be turned on before analyzing a leaf.';
      });

      await showLocationSettings(
        message:
            'Turn on Location in your phone settings. '
            'Then return to CropCare AI and tap Analyze leaf again.',
        appSettings: false,
      );

      return false;
    }

    // Then check the app's location permission.
    var permission = await Geolocator.checkPermission();

    if (!mounted) return false;

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (!mounted) return false;

    final permissionGranted =
        permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;

    if (!permissionGranted) {
      setState(() {
        error =
            'Location permission is required. '
            'Allow location while using this app to continue.';
      });

      await showLocationSettings(
        message:
            'CropCare AI needs your location before analyzing a leaf. '
            'In app permissions, allow Location while using the app. '
            'Then return and tap Analyze leaf again.',
        appSettings: true,
      );

      return false;
    }

    setState(() {
      progress = 'Getting your location…';
    });

    // Require a current position. Do not use an old saved location.
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
        'Move to an open area and tap Analyze leaf again. '
        'Your image has not been uploaded.',
      );
    }

    if (!mounted) return false;

    setState(() {
      progress = 'Saving your location…';
    });

    // Your Django backend copies profile coordinates into each scan.
    // Keep nearby-sharing preferences unchanged.
    await widget.state.updateProfile({
      'latitude': position.latitude,
      'longitude': position.longitude,
    });

    if (!mounted) return false;

    // Recheck before starting the image upload.
    final stillEnabled = await Geolocator.isLocationServiceEnabled();
    final currentPermission = await Geolocator.checkPermission();

    if (!mounted) return false;

    if (!stillEnabled) {
      setState(() {
        error = 'Location was turned off. Turn it on and try again.';
      });

      await showLocationSettings(
        message:
            'Location was turned off before analysis started. '
            'Enable it, return to the app, and tap Analyze leaf again.',
        appSettings: false,
      );

      return false;
    }

    if (currentPermission != LocationPermission.whileInUse &&
        currentPermission != LocationPermission.always) {
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

      // No image upload happens unless all location checks pass.
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
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
      });
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
          side: const BorderSide(
            color: Color(0xFFBBD8B9),
          ),
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
    final body = PageBody(
      children: [
        if (widget.parent == null)
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.only(bottom: 28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  forest,
                  Color(0xFF48A346),
                ],
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
                        'Welcome, ${widget.state.user?['full_name']?.toString().split(' ').first ?? 'Farmer'}!',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Give your crops a little care.\nCheck a leaf with AI.',
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
                decoration: const InputDecoration(
                  labelText: 'Crop',
                ),
                items: crops.map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item == 'Auto' ? 'Detect crop automatically' : item,
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
                style: TextStyle(
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
        const SectionCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on,
                color: forest,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Location is required before analysis. '
                  'Your current location will update your profile and '
                  'be saved with the report for local crop information. '
                  'Nearby sharing remains your choice in Profile.',
                  style: TextStyle(
                    height: 1.45,
                  ),
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
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(
            busy ? progress : 'Analyze leaf',
          ),
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
            body: SafeArea(
              child: body,
            ),
          );
  }
}
