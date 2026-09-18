import 'package:flutter/material.dart';
import '../app_state.dart';
import '../widgets/common.dart';
import 'scan_screen.dart';

class ResultScreen extends StatefulWidget {
  final AppState state;
  final Map<String, dynamic>? initial;
  final String? scanId;
  const ResultScreen({
    super.key,
    required this.state,
    this.initial,
    this.scanId,
  });
  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Map<String, dynamic>? scan, previous;
  String? error;
  bool saving = false;
  final notes = TextEditingController();
  String outcome = 'open';
  @override
  void initState() {
    super.initState();
    scan = widget.initial;
    load();
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final value = Map<String, dynamic>.from(
        await widget.state.api.call(
          'GET',
          'scans/${scan?['id'] ?? widget.scanId}/',
        ),
      );
      Map<String, dynamic>? parent;
      if (value['parent_id'] != null)
        parent = Map<String, dynamic>.from(
          await widget.state.api.call('GET', 'scans/${value['parent_id']}/'),
        );
      if (mounted)
        setState(() {
          scan = value;
          previous = parent;
          error = null;
          notes.text = value['notes'] ?? '';
          outcome = value['outcome'];
        });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await widget.state.api.call('PATCH', 'scans/${scan!['id']}/', {
        'outcome': outcome,
        'notes': notes.text,
      });
      await widget.state.syncReminders();
      await load();
      if (mounted) showMessage(context, 'Your progress has been saved.');
    } catch (e) {
      if (mounted) showMessage(context, e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> remove() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this crop check?'),
        content: const Text(
          'The photo and this history entry will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await widget.state.api.call('DELETE', 'scans/${scan!['id']}/');
      await widget.state.syncReminders();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showMessage(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = scan;
    final low =
        s != null &&
        ((s['confidence'] as num) < 80 || s['status'] == 'uncertain');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop analysis'),
        actions: [
          if (s != null)
            IconButton(
              tooltip: 'Delete check',
              onPressed: remove,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: s == null
            ? (error == null
                  ? const Center(child: CircularProgressIndicator())
                  : PageBody(children: [ErrorPanel(error!, retry: load)]))
            : PageBody(
                children: [
                  if (error != null) ErrorPanel(error!, retry: load),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Image.network(
                      s['image_url'],
                      headers: widget.state.api.headers,
                      height: 260,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, st) => const SizedBox(
                        height: 180,
                        child: Center(
                          child: Text(
                            'Photo unavailable. Pull back and try again.',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 27,
                              backgroundColor: paleGreen,
                              child: Icon(
                                low ? Icons.help_outline : Icons.verified,
                                color: forest,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Analysis Complete',
                                    style: TextStyle(
                                      fontSize: 23,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'AI prediction result',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'Suggested condition',
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s['condition'],
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Model confidence',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${(s['confidence'] as num).toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: low ? Colors.red : forest,
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (s['confidence'] as num) / 100,
                            minHeight: 11,
                            color: low ? Colors.red : forest,
                            backgroundColor: Colors.black12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          low
                              ? 'Low confidence — please confirm'
                              : 'AI suggestion — confirm before treatment',
                          style: TextStyle(
                            color: low ? Colors.red : forest,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SectionCard(
                          color: paleGreen,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.medical_services_outlined,
                                    color: forest,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Recommended action',
                                      style: TextStyle(
                                        color: forest,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              for (final tip in s['recommendations'])
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    '• $tip',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          'Checked ${dateLabel(s['created_at'])}',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'This score is not a calibrated probability of disease. For serious crop problems, consult an agricultural expert.',
                          style: TextStyle(color: Colors.black54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (previous != null)
                    SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your follow-up comparison',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('Earlier: ${previous!['condition']}'),
                          Text('Now: ${s['condition']}'),
                          const SizedBox(height: 8),
                          const Text(
                            'Compare visible symptoms and record your own observation below. A change in confidence does not measure recovery.',
                            style: TextStyle(color: Colors.black54),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ResultScreen(
                                  state: widget.state,
                                  scanId: previous!['id'],
                                ),
                              ),
                            ),
                            child: const Text('View earlier photo'),
                          ),
                        ],
                      ),
                    ),
                  if (s['follow_up_due'] != null &&
                      s['follow_up_done'] == false)
                    SectionCard(
                      color: paleGreen,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Seven-day plant check',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: forest,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Reminder: ${dateLabel(s['follow_up_due'])}'),
                          const Text(
                            'Is the problem better, the same or worse? Take a new photo to follow its progress.',
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ScanScreen(
                                    state: widget.state,
                                    parent: s,
                                  ),
                                ),
                              );
                              await load();
                            },
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: const Text('Take a follow-up photo'),
                          ),
                        ],
                      ),
                    ),
                  if (widget.state.notificationError != null)
                    Text(
                      widget.state.notificationError!,
                      style: const TextStyle(color: Colors.deepOrange),
                    ),
                  SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My plant progress',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          key: ValueKey(outcome),
                          initialValue: outcome,
                          decoration: const InputDecoration(
                            labelText: 'Your observation',
                          ),
                          items:
                              const [
                                    'open',
                                    'improved',
                                    'unchanged',
                                    'worse',
                                    'resolved',
                                  ]
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(
                                        e[0].toUpperCase() + e.substring(1),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => setState(() => outcome = v!),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: notes,
                          maxLines: 3,
                          maxLength: 2000,
                          decoration: const InputDecoration(
                            labelText: 'Treatment / observation notes',
                          ),
                        ),
                        FilledButton(
                          onPressed: saving ? null : save,
                          child: Text(saving ? 'Saving…' : 'Save progress'),
                        ),
                      ],
                    ),
                  ),
                  ExpansionTile(
                    title: const Text('Other model suggestions'),
                    children: [
                      for (final item in s['alternatives'])
                        ListTile(
                          title: Text(item['condition']),
                          trailing: Text('${item['confidence']}%'),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
