import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'providers/app_controller.dart';
import 'screens/auth_screen.dart';
import 'screens/shell.dart';
import 'services/supabase_service.dart';
import 'widgets/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.supabaseUrl.isNotEmpty &&
      AppConfig.supabasePublishableKey.isNotEmpty) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );

    debugPrint('SUPABASE INITIALIZED');
    debugPrint(
      'INITIAL SESSION: ${Supabase.instance.client.auth.currentSession?.user.id}',
    );
  } else {
    debugPrint('SUPABASE NOT CONFIGURED');
  }

  runApp(
    const ProviderScope(
      child: MinsPrepApp(),
    ),
  );
}

class MinsPrepApp extends StatelessWidget {
  const MinsPrepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Neo 150 Prep',
      theme: buildAppTheme(),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  Session? _session;

  @override
  void initState() {
    super.initState();

    // Get the session that may already exist when the app starts.
    _session = SupabaseService.currentSession;

    // Listen for login/logout changes.
    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      debugPrint('AUTH EVENT: $event');
      debugPrint('AUTH SESSION: ${session?.user.id}');

      if (!mounted) return;

      setState(() {
        _session = session;
      });

      // Refresh app data after login.
      if (session != null) {
        ref.invalidate(appControllerProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Supabase isn't configured.
    if (!SupabaseService.isConfigured) {
      return const Shell();
    }

    // User is logged in.
    if (_session != null) {
      return const Shell();
    }

    // User is not logged in.
    return const AuthScreen();
  }
}
