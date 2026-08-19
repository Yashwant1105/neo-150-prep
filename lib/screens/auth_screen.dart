import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool loading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => loading = true);

    try {
      await SupabaseService().signInWithGoogle();
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign-in failed: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: acid,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.terminal,
                  color: ink,
                  size: 28,
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                '150 problems.\nOne stronger you.',
                style: TextStyle(
                  fontSize: 38,
                  height: 1.03,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'A focused coding grind built around progress, not noise.',
                style: TextStyle(
                  color: muted,
                  fontSize: 16,
                  height: 1.45,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: loading ? null : _signInWithGoogle,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.g_mobiledata,
                          size: 28,
                        ),
                  label: const Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Your progress syncs across devices.',
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}
