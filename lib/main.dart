import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'providers/app_controller.dart';
import 'screens/auth_screen.dart';
import 'screens/shell.dart';
import 'services/notification_service.dart';
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
  } else {
    debugPrint('SUPABASE NOT CONFIGURED');
  }

  await NotificationService.instance.initialize();

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

class _AuthGateState extends ConsumerState<AuthGate>
    with WidgetsBindingObserver {
  Session? _session;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // Get the session that may already exist when the app starts.
    _session = SupabaseService.currentSession;

    if (_session != null) {
      debugPrint('[NOTIF SYNC] call starting: initial session');
      NotificationService.instance.syncForCurrentUser();
      debugPrint('[NOTIF SYNC] call returned: initial session');
    }

    // Listen for login/logout changes.
    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      debugPrint('AUTH EVENT: $event');

      if (session == null && event == AuthChangeEvent.initialSession) {
        debugPrint('[AUTH] initialSession has null session');
      }

      if (!mounted) {
        debugPrint('[AUTH] AuthGate unmounted, skipping sync');
        return;
      }

      setState(() {
        _session = session;
      });

      // Refresh app data after login.
      if (session != null) {
        debugPrint('[NOTIF SYNC] call starting: auth event');
        NotificationService.instance.syncForCurrentUser();
        debugPrint('[NOTIF SYNC] call returned: auth event');
        ref.invalidate(appControllerProvider);
      } else {
        ref.invalidate(appControllerProvider);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    ref.invalidate(appControllerProvider);
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
