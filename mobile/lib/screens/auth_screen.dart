import 'package:flutter/material.dart';
import '../app_state.dart';
import '../widgets/common.dart';

class AuthScreen extends StatefulWidget {
  final AppState state;
  const AuthScreen({super.key, required this.state});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false, busy = false, hidden = true;
  String? error;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.state.authenticate(
        register,
        email.text.trim(),
        password.text,
        name.text.trim(),
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: PageBody(
        children: [
          const SizedBox(height: 28),
          const CircleAvatar(
            radius: 42,
            backgroundColor: forest,
            child: Icon(Icons.eco_rounded, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 22),
          Text(
            'CropCare AI',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const Text(
            'A little care. A healthier harvest.',
            style: TextStyle(color: Colors.black54, fontSize: 17),
          ),
          const SizedBox(height: 32),
          SectionCard(
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    register
                        ? 'Join your farming community'
                        : 'Welcome back, Farmer!',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    register
                        ? 'Create an account to keep your crop checks together.'
                        : 'Sign in to check your crops and follow their progress.',
                  ),
                  const SizedBox(height: 24),
                  if (register) ...[
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Enter your name.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    validator: (v) =>
                        v != null &&
                            RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch(v.trim())
                        ? null
                        : 'Enter a valid email.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: password,
                    obscureText: hidden,
                    autofillHints: [
                      register
                          ? AutofillHints.newPassword
                          : AutofillHints.password,
                    ],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => hidden = !hidden),
                        icon: Icon(
                          hidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (v) => v == null || v.length < 8
                        ? 'Use at least 8 characters.'
                        : null,
                  ),
                  if (register)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'Use a strong password with letters and numbers.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Text(
                      busy
                          ? 'Please wait…'
                          : (register ? 'Create account' : 'Sign in'),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              register = !register;
                              error = null;
                            }),
                      child: Text(
                        register
                            ? 'Already registered? Sign in'
                            : 'New here? Create an account',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Text(
            'Your photos and history stay in your account. Sharing a nearby report is optional.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    ),
  );
}
