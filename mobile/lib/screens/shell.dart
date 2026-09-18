import 'package:flutter/material.dart';
import '../app_state.dart';
import 'scan_screen.dart';
import 'history_screen.dart';
import 'insight_screens.dart';
import 'profile_screen.dart';
import 'result_screen.dart';
import '../widgets/common.dart';

class Shell extends StatefulWidget {
  final AppState state;
  const Shell({super.key, required this.state});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int index = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.state.addListener(onStateChanged);
    widget.state.notifications.onOpen = openNotification;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.state.syncReminders();
      final pending = widget.state.notifications.pendingOpen;
      if (pending != null) {
        widget.state.notifications.pendingOpen = null;
        openNotification(pending == 'inbox' ? null : pending);
      }
    });
  }

  void onStateChanged() {
    if (widget.state.user == null && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void openNotification(String? id) {
    if (!mounted) return;
    setState(() => index = 4);
    if (id != null)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(state: widget.state, scanId: id),
        ),
      );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.state.user != null)
      widget.state.syncReminders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.state.removeListener(onStateChanged);
    widget.state.notifications.onOpen = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CropCare AI',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 26),
          ),
          Text(
            'Smart Crop Disease Assistant',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Profile and settings',
          icon: const Icon(Icons.account_circle_outlined, size: 28),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(state: widget.state),
              ),
            );
            if (mounted) setState(() {});
          },
        ),
      ],
    ),
    body: SafeArea(
      top: false,
      child: [
        ScanScreen(state: widget.state),
        HistoryScreen(state: widget.state),
        NearbyScreen(state: widget.state),
        WeatherScreen(state: widget.state),
        AlertsScreen(state: widget.state),
      ][index],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (value) => setState(() => index = value),
      backgroundColor: Colors.white,
      indicatorColor: paleGreen,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.eco_outlined),
          selectedIcon: Icon(Icons.eco),
          label: 'Scan',
        ),
        NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        NavigationDestination(icon: Icon(Icons.radar), label: 'Nearby'),
        NavigationDestination(
          icon: Icon(Icons.wb_sunny_outlined),
          label: 'Weather',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_none),
          label: 'Alerts',
        ),
      ],
    ),
  );
}
