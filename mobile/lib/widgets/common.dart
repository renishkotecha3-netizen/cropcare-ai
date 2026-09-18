import 'package:flutter/material.dart';

const forest = Color(0xFF2E7D32);
const paleGreen = Color(0xFFEAF6EA);

class SectionCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  const SectionCard({super.key, required this.child, this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0xFFD9EAD7)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0C2E7D32),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

class ErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback? retry;
  const ErrorPanel(this.message, {super.key, this.retry});
  @override
  Widget build(BuildContext context) => SectionCard(
    child: Column(
      children: [
        const Icon(Icons.cloud_off_rounded, color: forest, size: 36),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        if (retry != null)
          TextButton.icon(
            onPressed: retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
      ],
    ),
  );
}

class EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const EmptyPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  @override
  Widget build(BuildContext context) => SectionCard(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: paleGreen,
            child: Icon(icon, color: forest, size: 36),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    ),
  );
}

void showMessage(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
String dateLabel(dynamic value) {
  if (value == null) return '';
  final d = DateTime.parse(value.toString()).toLocal();
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class PageBody extends StatelessWidget {
  final List<Widget> children;
  const PageBody({super.key, required this.children});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(20),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    ),
  );
}
