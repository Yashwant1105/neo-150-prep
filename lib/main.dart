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
      title: "Min's Prep",
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
  String? _lastUserId;

  @override
  Widget build(BuildContext context) {
    if (!SupabaseService.isConfigured) {
      return const Shell();
    }

    return StreamBuilder<AuthState>(
      stream: SupabaseService.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = SupabaseService.currentSession;
        final userId = session?.user.id;

        if (userId != _lastUserId) {
          _lastUserId = userId;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.invalidate(appControllerProvider);
            }
          });
        }

        if (session == null) {
          return const AuthScreen();
        }

        return const Shell();
      },
    );
  }
}
