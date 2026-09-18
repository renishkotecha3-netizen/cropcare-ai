import 'package:flutter/material.dart';
import 'app_state.dart';
import 'screens/auth_screen.dart';
import 'screens/shell.dart';
import 'widgets/common.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(CropCareApp());
}

class CropCareApp extends StatefulWidget {
  CropCareApp({super.key});
  @override
  State<CropCareApp> createState() => _CropCareAppState();
}

class _CropCareAppState extends State<CropCareApp> {
  final state = AppState();
  @override
  void initState() {
    super.initState();
    state.init();
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CropCare AI',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: forest),
      scaffoldBackgroundColor: const Color(0xFFF5F9F5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF4AA74C),
        foregroundColor: Colors.white,
        centerTitle: false,
        toolbarHeight: 82,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 29,
          fontWeight: FontWeight.w700,
          color: Color(0xFF19251B),
        ),
        titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontSize: 17, height: 1.5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: forest,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    ),
    home: AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        if (state.loading)
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        if (state.startupError != null && state.user == null)
          return Scaffold(
            body: SafeArea(
              child: PageBody(
                children: [
                  const SizedBox(height: 60),
                  ErrorPanel(state.startupError!, retry: state.init),
                  TextButton(
                    onPressed: () => state.signOut(),
                    child: const Text('Return to sign in'),
                  ),
                ],
              ),
            ),
          );
        return state.user == null
            ? AuthScreen(state: state)
            : Shell(state: state);
      },
    ),
  );
}
