import 'package:flutter/material.dart';
import '../app_state.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

class HistoryScreen extends StatefulWidget {
  final AppState state;
  const HistoryScreen({super.key, required this.state});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final search = TextEditingController();
  List<Map<String, dynamic>> scans = [];
  String filter = '', error = '';
  int page = 1, total = 0;
  bool loading = true, hasMore = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    setState(() => loading = true);
    try {
      final nextPage = more ? page + 1 : 1;
      final data = await widget.state.api.call(
        'GET',
        'scans/?page=$nextPage&status=$filter&search=${Uri.encodeQueryComponent(search.text)}',
      );
      if (mounted)
        setState(() {
          final values = List<Map<String, dynamic>>.from(data['results']);
          scans = more ? [...scans, ...values] : values;
          page = nextPage;
          total = data['count'];
          hasMore = data['next'] != null;
          error = '';
        });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: load,
    child: PageBody(
      children: [
        Text(
          'Your crop journal',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Past photos, results and recovery checks.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: search,
          onSubmitted: (_) => load(),
          decoration: InputDecoration(
            hintText: 'Search a condition',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed: load,
              icon: const Icon(Icons.arrow_forward),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final f in ['', 'issue', 'healthy', 'uncertain'])
              ChoiceChip(
                label: Text(
                  f.isEmpty ? 'All' : f[0].toUpperCase() + f.substring(1),
                ),
                selected: filter == f,
                onSelected: loading
                    ? null
                    : (_) {
                        setState(() => filter = f);
                        load();
                      },
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (error.isNotEmpty) ErrorPanel(error, retry: load),
        if (loading && scans.isEmpty)
          const Center(child: CircularProgressIndicator()),
        if (!loading && scans.isEmpty && error.isEmpty)
          const EmptyPanel(
            icon: Icons.history,
            title: 'Your journal starts here',
            message: 'Analyze a leaf to save your first crop check.',
          ),
        if (scans.isNotEmpty)
          Text(
            '$total crop checks',
            style: const TextStyle(color: Colors.black54),
          ),
        const SizedBox(height: 12),
        for (final s in scans)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ResultScreen(state: widget.state, initial: s),
                    ),
                  );
                  await load();
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          s['image_url'],
                          headers: widget.state.api.headers,
                          width: 66,
                          height: 78,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, st) =>
                              const Icon(Icons.eco, size: 50, color: forest),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s['condition'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              '${s['confidence']}% · ${s['outcome']}',
                              style: const TextStyle(color: forest),
                            ),
                            Text(
                              dateLabel(s['created_at']),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            if (s['parent_id'] != null)
                              const Text(
                                'Follow-up photo',
                                style: TextStyle(fontSize: 12, color: forest),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: forest),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (hasMore)
          OutlinedButton(
            onPressed: loading ? null : () => load(more: true),
            child: Text(loading ? 'Loading…' : 'Load more'),
          ),
      ],
    ),
  );
}
