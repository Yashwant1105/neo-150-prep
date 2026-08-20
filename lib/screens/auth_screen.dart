import 'dart:async';

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

  // ===========================================================================
  // TYPING ANIMATION
  // ===========================================================================

  static const String _animatedText = 'One stronger you.';

  String _visibleText = '';
  Timer? _typingTimer;
  Timer? _cursorTimer;

  bool _showCursor = true;

  @override
  void initState() {
    super.initState();

    _startTypingAnimation();

    _cursorTimer = Timer.periodic(
      const Duration(milliseconds: 520),
      (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _showCursor = !_showCursor;
        });
      },
    );
  }

  void _startTypingAnimation() {
    int index = 0;

    _typingTimer = Timer.periodic(
      const Duration(milliseconds: 75),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (index >= _animatedText.length) {
          timer.cancel();
          return;
        }

        setState(() {
          _visibleText += _animatedText[index];
        });

        index++;
      },
    );
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  // ===========================================================================
  // GOOGLE SIGN IN
  // ===========================================================================

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

  // ===========================================================================
  // UI
  // ===========================================================================

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

              // -----------------------------------------------------------------
              // APP ICON
              // -----------------------------------------------------------------

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

              // -----------------------------------------------------------------
              // HERO
              // -----------------------------------------------------------------

              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '150 problems.\n',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontSize: 38,
                            height: 1.03,
                            fontWeight: FontWeight.w800,
                            color: white,
                          ),
                    ),
                    TextSpan(
                      text: _visibleText,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontSize: 38,
                            height: 1.03,
                            fontWeight: FontWeight.w800,
                            color: white,
                          ),
                    ),
                    TextSpan(
                      text: _showCursor ? '▌' : ' ',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontSize: 34,
                            height: 1.03,
                            fontWeight: FontWeight.w500,
                            color: acid,
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // -----------------------------------------------------------------
              // SUBTITLE
              // -----------------------------------------------------------------

              Text(
                'A focused coding grind built around progress, not noise.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: muted,
                      fontSize: 16,
                      height: 1.45,
                    ),
              ),

              const Spacer(),

              // -----------------------------------------------------------------
              // GOOGLE SIGN IN
              // -----------------------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: loading ? null : _signInWithGoogle,
                  style: FilledButton.styleFrom(
                    backgroundColor: acid,
                    foregroundColor: ink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ink,
                          ),
                        )
                      : const Icon(
                          Icons.g_mobiledata,
                          size: 28,
                          color: ink,
                        ),
                  label: Text(
                    'Continue with Google',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: ink,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // -----------------------------------------------------------------
              // SYNC MESSAGE
              // -----------------------------------------------------------------

              Center(
                child: Text(
                  'Your progress syncs across devices.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
