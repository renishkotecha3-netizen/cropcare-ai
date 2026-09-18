import 'package:flutter/material.dart';
import '../app_state.dart';
import '../widgets/common.dart';
import 'profile_screen.dart';
import 'result_screen.dart';

class ApiPanel extends StatefulWidget {
  final AppState state;
  final String endpoint;
  final Widget Function(
    BuildContext,
    Map<String, dynamic>,
    Future<void> Function(),
  )
  builder;
  const ApiPanel({
    super.key,
    required this.state,
    required this.endpoint,
    required this.builder,
  });
  @override
  State<ApiPanel> createState() => _ApiPanelState();
}

class _ApiPanelState extends State<ApiPanel> {
  Map<String, dynamic>? data;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant ApiPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endpoint != widget.endpoint) {
      data = null;
      load();
    }
  }

  Future<void> load() async {
    try {
      final value = await widget.state.api.call('GET', widget.endpoint);
      if (mounted)
        setState(() {
          data = Map<String, dynamic>.from(value);
          error = null;
        });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: load,
    child: error != null
        ? PageBody(children: [ErrorPanel(error!, retry: load)])
        : data == null
        ? const SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: 350,
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        : widget.builder(context, data!, load),
  );
}

Future<void> openProfile(
  BuildContext context,
  AppState state,
  Future<void> Function() reload,
) async {
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ProfileScreen(state: state)),
  );
  await reload();
}

class NearbyScreen extends StatelessWidget {
  final AppState state;
  const NearbyScreen({super.key, required this.state});
  @override
  Widget build(BuildContext context) => ApiPanel(
    state: state,
    endpoint: 'nearby/',
    builder: (context, data, reload) => PageBody(
      children: [
        Text(
          'Around your farm',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'A community heads-up for healthier crops.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 24),
        if (data['status'] == 'location_required') ...[
          const EmptyPanel(
            icon: Icons.location_on_outlined,
            title: 'Add your farm location',
            message:
                'Use your saved farm location to find recent crop reports in your area.',
          ),
          FilledButton.icon(
            onPressed: () => openProfile(context, state, reload),
            icon: const Icon(Icons.my_location),
            label: const Text('Set farm location'),
          ),
        ] else ...[
          SectionCard(
            color: paleGreen,
            child: Row(
              children: [
                const Icon(Icons.radar, color: forest, size: 38),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Within ${data['radius_km']} km',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: forest,
                        ),
                      ),
                      Text('Reports from the last ${data['window_days']} days'),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => openProfile(context, state, reload),
                  tooltip: 'Change radius',
                  icon: const Icon(Icons.tune, color: forest),
                ),
              ],
            ),
          ),
          if ((data['results'] as List).isEmpty)
            const EmptyPanel(
              icon: Icons.verified_user_outlined,
              title: 'No recent shared reports',
              message:
                  'No matching reports are available nearby. This does not mean your area is free of disease.',
            ),
          for (final report in data['results'])
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.deepOrange,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          report['condition'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${report['reports']} shared report(s) · ${report['crop']}',
                    style: const TextStyle(
                      color: forest,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Latest: ${dateLabel(report['last_reported'])}',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Inspect your own plants. If symptoms are present, analyze a leaf and get local advice before applying treatment.',
                  ),
                ],
              ),
            ),
          Text(
            data['notice'],
            style: const TextStyle(color: Colors.black54, fontSize: 13),
          ),
          const SizedBox(height: 14),
          const Text(
            'Names, photos and exact farm coordinates are never included in nearby reports.',
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
        ],
      ],
    ),
  );
}

class WeatherScreen extends StatelessWidget {
  final AppState state;
  const WeatherScreen({super.key, required this.state});
  @override
  Widget build(BuildContext context) => ApiPanel(
    state: state,
    endpoint: 'weather/',
    builder: (context, data, reload) {
      final current = data['current'];
      final daily = data['daily'];
      return PageBody(
        children: [
          Text(
            'Weather & crop care',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Local conditions. Practical steps for today.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          if (data['status'] == 'location_required') ...[
            EmptyPanel(
              icon: Icons.location_on_outlined,
              title: 'Where is your farm?',
              message: data['detail'],
            ),
            FilledButton(
              onPressed: () => openProfile(context, state, reload),
              child: const Text('Set farm location'),
            ),
          ] else if (data['status'] != 'available')
            ErrorPanel(data['detail'] ?? 'Weather unavailable.', retry: reload)
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(26),
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF246C59), Color(0xFF56A777)],
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.wb_sunny_outlined,
                        color: Colors.white,
                        size: 34,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'At your farm',
                        style: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${current['temperature_2m']}°C',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      Text(
                        'Humidity ${current['relative_humidity_2m']}%',
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        'Wind ${current['wind_speed_10m']} km/h',
                        style: const TextStyle(color: Colors.white),
                      ),
                      Text(
                        'Rain ${current['precipitation']} mm',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Weather time: ${current['time']} UTC',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (data['crop_context'] != null)
              SectionCard(
                color: paleGreen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'For a recent crop issue',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: forest,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      data['crop_context']['condition'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data['crop_context']['advice'],
                      style: const TextStyle(height: 1.5),
                    ),
                  ],
                ),
              ),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your weather advisory',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  for (final tip in data['advice'])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.eco_outlined,
                            color: forest,
                            size: 21,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tip,
                              style: const TextStyle(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Three-day outlook',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  for (var i = 0; i < (daily['time'] as List).length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(child: Text(daily['time'][i])),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${daily['temperature_2m_min'][i]}° / ${daily['temperature_2m_max'][i]}°C',
                              ),
                              Text(
                                'Rain ${daily['precipitation_probability_max'][i]}% · ${daily['precipitation_sum'][i]} mm',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Text(
              data['attribution'],
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            Text(
              'Retrieved ${dateLabel(data['fetched_at'])}. Pull down to refresh.',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ],
      );
    },
  );
}

class AlertsScreen extends StatefulWidget {
  final AppState state;
  const AlertsScreen({super.key, required this.state});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  int page = 1;
  bool enabling = false;
  @override
  Widget build(BuildContext context) => ApiPanel(
    state: widget.state,
    endpoint: 'notifications/?page=$page',
    builder: (context, data, reload) => PageBody(
      children: [
        Text(
          'Your crop updates',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Follow-up reminders and nearby crop alerts.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 24),
        SectionCard(
          color: paleGreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Keep in touch with your plants',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: forest,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enable phone reminders for your seven-day plant checks. You can always find due checks here.',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: enabling
                    ? null
                    : () async {
                        setState(() => enabling = true);
                        try {
                          await widget.state.notifications.enable(
                            widget.state.api,
                          );
                          if (context.mounted)
                            showMessage(
                              context,
                              widget.state.notifications.pushReady
                                  ? 'Phone reminders and remote alerts enabled.'
                                  : 'Phone reminders enabled. Nearby updates appear in this tab.',
                            );
                        } catch (e) {
                          if (context.mounted)
                            showMessage(context, e.toString());
                        } finally {
                          if (mounted) setState(() => enabling = false);
                        }
                      },
                icon: const Icon(Icons.notifications_active_outlined),
                label: Text(enabling ? 'Enabling…' : 'Enable phone reminders'),
              ),
            ],
          ),
        ),
        if ((data['results'] as List).isEmpty)
          const EmptyPanel(
            icon: Icons.notifications_none,
            title: 'You’re all caught up',
            message:
                'Seven-day checks appear when due. Nearby reports appear when alerts are enabled in Profile.',
          ),
        for (final n in data['results'])
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      n['kind'] == 'followup'
                          ? Icons.camera_alt_outlined
                          : Icons.radar,
                      color: forest,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        n['title'],
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (n['read_at'] == null)
                      const Icon(Icons.circle, color: forest, size: 9),
                  ],
                ),
                const SizedBox(height: 12),
                Text(n['body'], style: const TextStyle(height: 1.5)),
                const SizedBox(height: 8),
                Text(
                  dateLabel(n['created_at']),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await widget.state.api.call(
                        'POST',
                        'notifications/${n['id']}/read/',
                      );
                      if (n['scan_id'] != null && context.mounted)
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ResultScreen(
                              state: widget.state,
                              scanId: n['scan_id'],
                            ),
                          ),
                        );
                      await reload();
                    } catch (e) {
                      if (context.mounted) showMessage(context, e.toString());
                    }
                  },
                  child: Text(
                    n['scan_id'] != null
                        ? 'Open plant check'
                        : (n['read_at'] == null ? 'Mark as read' : 'Read'),
                  ),
                ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: page > 1 ? () => setState(() => page--) : null,
              child: const Text('Previous'),
            ),
            Text('Page $page'),
            TextButton(
              onPressed: data['next'] != null
                  ? () => setState(() => page++)
                  : null,
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    ),
  );
}
