import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'interview_screen.dart';

import '../models/problem.dart';
import '../providers/app_controller.dart';
import '../services/ai_coach_service.dart';
import '../widgets/ui.dart';
import '../widgets/app_theme.dart';

class ProblemDetailScreen extends ConsumerStatefulWidget {
  final Problem problem;

  const ProblemDetailScreen({
    super.key,
    required this.problem,
  });

  @override
  ConsumerState<ProblemDetailScreen> createState() =>
      _ProblemDetailScreenState();
}

class _ProblemDetailScreenState extends ConsumerState<ProblemDetailScreen> {
  late final TextEditingController notes;

  // ---------------------------------------------------------------------------
  // AI COACH STATE
  // ---------------------------------------------------------------------------

  bool _aiLoading = false;

  // Cache each AI response separately.
  // Moving between already-generated hints/approach never calls Gemini again.
  String? _hint1Text;
  String? _hint2Text;
  String? _approachText;

  // The currently visible AI Coach mode.
  String? _aiMode;

  @override
  void initState() {
    super.initState();

    final progress =
        ref.read(appControllerProvider).value?.progress[widget.problem.id];

    notes = TextEditingController(
      text: progress?.notes ?? '',
    );
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  int get _xp {
    switch (widget.problem.difficulty) {
      case 'Easy':
        return 10;
      case 'Medium':
        return 20;
      default:
        return 30;
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(appControllerProvider);

    return async.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Scaffold(
        body: Center(
          child: Text('$e'),
        ),
      ),
      data: (state) {
        final progress =
            state.progress[widget.problem.id] ?? const ProblemProgress();

        final isFlagged = progress.reviewDueAt != null;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Back',
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Transform.rotate(
                angle: 3.14159265359,
                child: SvgPicture.asset(
                  'assets/icons/core/arrow_forward.svg',
                  width: 25,
                  height: 25,
                ),
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Open problem',
                onPressed: () => launchUrl(
                  Uri.parse(widget.problem.externalUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(
                  Icons.open_in_new,
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              34,
            ),
            children: [
              // -----------------------------------------------------------------
              // PROBLEM HEADER
              // -----------------------------------------------------------------

              Text(
                'PROBLEM ${widget.problem.order.toString().padLeft(2, '0')}',
                style: technicalTextStyle(
                  color: acid,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                widget.problem.title,
                style: const TextStyle(
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  DifficultyPill(
                    difficulty: widget.problem.difficulty,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      widget.problem.topic,
                      style: humanTextStyle(
                        color: muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // -----------------------------------------------------------------
              // COMPLETION CARD
              // -----------------------------------------------------------------

              GlowCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(
                            milliseconds: 250,
                          ),
                          child: progress.completed
                              ? SvgPicture.asset(
                                  'assets/icons/core/check.svg',
                                  key: const ValueKey('completed'),
                                  width: 27,
                                  height: 27,
                                )
                              : Container(
                                  key: const ValueKey('incomplete'),
                                  width: 27,
                                  height: 27,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: muted,
                                      width: 2,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          progress.completed ? 'Completed' : 'Not completed',
                          style: humanTextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '+$_xp XP',
                          style: technicalTextStyle(
                            color: acid,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () => _toggleCompletion(
                          progress.completed,
                        ),
                        icon: SvgPicture.asset(
                          'assets/icons/core/check.svg',
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                            ink,
                            BlendMode.srcIn,
                          ),
                        ),
                        label: Text(
                          progress.completed
                              ? 'Mark incomplete'
                              : 'Mark as completed',
                          style: humanTextStyle(
                            color: ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // -----------------------------------------------------------------
              // REVIEW BUTTON
              // -----------------------------------------------------------------

              OutlinedButton.icon(
                onPressed: () => _toggleReview(isFlagged),
                icon: SvgPicture.asset(
                  isFlagged
                      ? 'assets/icons/core/bookmark.svg'
                      : 'assets/icons/core/review.svg',
                  width: 21,
                  height: 21,
                ),
                label: Text(
                  isFlagged ? 'Flagged for review' : 'Flag for review',
                  style: humanTextStyle(
                    color: acid,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // -----------------------------------------------------------------
              // INTERVIEW ME
              // -----------------------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: progress.completed
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => InterviewScreen(
                                initialProblem: widget.problem,
                              ),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(
                    Icons.mic_none_rounded,
                    size: 20,
                  ),
                  label: Text(
                    progress.completed
                        ? 'Interview Me'
                        : 'Complete problem to interview',
                    style: humanTextStyle(
                      color: progress.completed ? acid : muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 26),

              // -----------------------------------------------------------------
              // AI COACH
              // -----------------------------------------------------------------

              _AiCoachCard(
                loading: _aiLoading,
                text: _currentAiText,
                mode: _aiMode,
                onHint:
                    _aiMode == null ? () => _askAiCoach(mode: 'hint1') : null,
                onDeeperHint: _aiMode == 'hint1'
                    ? () => _askAiCoach(mode: 'hint2')
                    : null,
                onApproach: (_aiMode == 'hint1' || _aiMode == 'hint2')
                    ? () => _askAiCoach(mode: 'approach')
                    : null,
                backLabel: _aiMode == 'approach'
                    ? (_hint2Text != null ? 'Hint 02' : 'Hint 01')
                    : 'Hint 01',
                onBack: _aiMode == 'approach'
                    ? () {
                        final previousMode =
                            _hint2Text != null ? 'hint2' : 'hint1';

                        setState(() {
                          _aiMode = previousMode;
                        });
                      }
                    : _aiMode == 'hint2'
                        ? () {
                            setState(() {
                              _aiMode = 'hint1';
                            });
                          }
                        : null,
              ),

              const SizedBox(height: 28),

              // -----------------------------------------------------------------
              // NOTES
              // -----------------------------------------------------------------

              const SectionTitle(
                title: 'Your notes',
              ),

              const SizedBox(height: 10),

              TextField(
                controller: notes,
                maxLines: 9,
                onChanged: (value) {
                  ref
                      .read(
                        appControllerProvider.notifier,
                      )
                      .saveNotes(
                        widget.problem,
                        value,
                      );
                },
                decoration: InputDecoration(
                  hintText:
                      'Approach, gotchas, complexity, things to revisit...',
                  hintStyle: humanTextStyle(
                    color: muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (progress.completedAt != null)
                Text(
                  'Completed ${_relative(progress.completedAt!)}',
                  style: humanTextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),

              if (progress.reviewDueAt != null)
                Text(
                  'Review due ${_relative(progress.reviewDueAt!)}',
                  style: technicalTextStyle(
                    color: acid,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // AI COACH
  // ---------------------------------------------------------------------------

  String? get _currentAiText {
    switch (_aiMode) {
      case 'hint1':
        return _hint1Text;
      case 'hint2':
        return _hint2Text;
      case 'approach':
        return _approachText;
      default:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // AI COACH
  // ---------------------------------------------------------------------------

  Future<void> _askAiCoach({
    required String mode,
  }) async {
    if (_aiLoading) {
      return;
    }

    // If this response was already generated, just show the cached result.
    // This guarantees that navigation never triggers another Gemini call.
    final cachedText = switch (mode) {
      'hint1' => _hint1Text,
      'hint2' => _hint2Text,
      'approach' => _approachText,
      _ => null,
    };

    if (cachedText != null && cachedText.isNotEmpty) {
      setState(() {
        _aiMode = mode;
      });
      return;
    }

    setState(() {
      _aiLoading = true;
      _aiMode = mode;
    });

    try {
      final state = ref.read(appControllerProvider).value;
      final userContext = state?.buildAiCoachContext();

      final text = await AiCoachService().getHint(
        title: widget.problem.title,
        topic: widget.problem.topic,
        difficulty: widget.problem.difficulty,
        mode: mode,
        notes: notes.text.trim(),
        userContext: userContext,
      );

      if (!mounted) {
        return;
      }

      final cleaned = _cleanAiResponse(text, mode);

      setState(() {
        switch (mode) {
          case 'hint1':
            _hint1Text = cleaned;
            break;
          case 'hint2':
            _hint2Text = cleaned;
            break;
          case 'approach':
            _approachText = cleaned;
            break;
        }

        _aiMode = mode;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      // Return to the previous successfully generated state if the request
      // fails, rather than leaving the user on a blank AI Coach card.
      setState(() {
        _aiMode = _hint2Text != null
            ? 'hint2'
            : _hint1Text != null
                ? 'hint1'
                : null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'AI Coach unavailable. Try again.',
            style: humanTextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _aiLoading = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // AI RESPONSE CLEANUP
  // ---------------------------------------------------------------------------

  String _cleanAiResponse(
    String value,
    String mode,
  ) {
    var cleaned = value.trim();

    // The UI already supplies the section label, so don't repeat it.
    cleaned = cleaned.replaceFirst(
      RegExp(
        r"""^(?:welcome to neo 150 prep[!,.]?\s*)?(?:let['’]s\s+)?(?:tackle\s+)?(?:the\s+)?(?:problem|valid anagram)[.!:]?\s*""",
        caseSensitive: false,
      ),
      '',
    );

    // Remove common conversational endings that make the card feel like chat.
    cleaned = cleaned.replaceFirst(
      RegExp(
        r"""\s*(?:would you like|want me to|do you want)\b.*$""",
        caseSensitive: false,
        dotAll: true,
      ),
      '',
    );

    // Strip Markdown formatting because the card is plain Flutter Text.
    cleaned = cleaned
        .replaceAll(RegExp(r'\*\*'), '')
        .replaceAll(RegExp(r'`{1,3}'), '')
        .replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*#{1,6}\s+', multiLine: true), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    if (mode == 'approach') {
      // Keep the approach instructional and direct.
      cleaned = cleaned.replaceFirst(
        RegExp(
          r"""^here(?: is|['’]s) (?:the )?(?:high[- ]level )?approach[:.]?\s*""",
          caseSensitive: false,
        ),
        '',
      );
    }

    final result = cleaned.isEmpty ? value.trim() : cleaned;
    return _normalizeComplexityText(result);
  }

  static String _normalizeComplexityText(String value) {
    var text = value;

    // ---------------------------------------------------------------------------
    // REMOVE LATEX / MARKDOWN WRAPPERS
    // ---------------------------------------------------------------------------

    // Remove escaped dollar signs.
    text = text.replaceAll(r'\$', '');

    // Remove normal dollar signs used as math delimiters.
    text = text.replaceAll('\$', '');

    // Remove LaTeX inline math delimiters.
    text = text.replaceAll(r'\(', '');
    text = text.replaceAll(r'\)', '');

    // Remove backticks around complexity expressions.
    text = text.replaceAll('`', '');

    // ---------------------------------------------------------------------------
    // NORMALIZE COMMON AI FORMATS
    // ---------------------------------------------------------------------------

    final replacements = <String, String>{
      // O of n log n
      r'\bO\s+of\s+n\s+log\s+n\b': 'O(n log n)',

      // O of log n
      r'\bO\s+of\s+log\s+n\b': 'O(log n)',

      // O of n
      r'\bO\s+of\s+n\b': 'O(n)',

      // O of 1
      r'\bO\s+of\s+1\b': 'O(1)',

      // O of m + n
      r'\bO\s+of\s+m\s*\+\s*n\b': 'O(m + n)',

      // O of n + m
      r'\bO\s+of\s+n\s*\+\s*m\b': 'O(n + m)',

      // O of n square
      r'\bO\s+of\s+n\s+square\b': 'O(n²)',

      // Common verbal forms
      r'\bconstant\s+time\b': 'O(1)',
      r'\blogarithmic\s+time\b': 'O(log n)',
      r'\blinear\s+time\b': 'O(n)',
      r'\blinear\s+space\b': 'O(n)',
      r'\bconstant\s+space\b': 'O(1)',
    };

    for (final entry in replacements.entries) {
      text = text.replaceAll(
        RegExp(
          entry.key,
          caseSensitive: false,
        ),
        entry.value,
      );
    }

    // ---------------------------------------------------------------------------
    // NORMALIZE O ( n ) → O(n)
    // NORMALIZE O( n log n ) → O(n log n)
    // ---------------------------------------------------------------------------

    text = text.replaceAllMapped(
      RegExp(
        r'\bO\s*\(\s*([^)]+?)\s*\)',
        caseSensitive: false,
      ),
      (match) {
        final inside = match
            .group(1)!
            .replaceAll(
              RegExp(r'\s+'),
              ' ',
            )
            .trim();

        return 'O($inside)';
      },
    );

    // ---------------------------------------------------------------------------
    // CLEAN UP DUPLICATED SPACING
    // ---------------------------------------------------------------------------

    text = text
        .replaceAll(
          RegExp(r'[ \t]+'),
          ' ',
        )
        .replaceAll(
          RegExp(r' *\n *'),
          '\n',
        )
        .replaceAll(
          RegExp(r'\n{3,}'),
          '\n\n',
        )
        .trim();

    return text;
  }

  // ---------------------------------------------------------------------------
  // REVIEW TOGGLE
  // ---------------------------------------------------------------------------

  Future<void> _toggleReview(
    bool isCurrentlyFlagged,
  ) async {
    final controller = ref.read(
      appControllerProvider.notifier,
    );

    if (isCurrentlyFlagged) {
      await controller.clearReview(
        widget.problem,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Removed from review.',
          ),
        ),
      );
    } else {
      await controller.flagForReview(
        widget.problem,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Review queued for 14 days.',
          ),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // COMPLETION
  // ---------------------------------------------------------------------------

  Future<void> _toggleCompletion(
    bool wasCompleted,
  ) async {
    final controller = ref.read(
      appControllerProvider.notifier,
    );

    final motivation = await controller.toggleComplete(
      widget.problem,
    );

    if (!mounted) {
      return;
    }

    // Only reward:
    //
    // incomplete → completed
    //
    // Completing → incomplete does not show XP reward.

    if (!wasCompleted) {
      final updatedState = ref.read(appControllerProvider).value;

      if (updatedState == null) {
        return;
      }

      _showCompletionReward(
        updatedState,
        motivation: motivation,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // COMPLETION REWARD
  // ---------------------------------------------------------------------------

  void _showCompletionReward(
    AppState state, {
    String? motivation,
  }) {
    final streak = state.currentStreak;

    final compliment = _getCompliment(
      difficulty: widget.problem.difficulty,
      completed: state.completed,
      streak: streak,
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Completion reward',
      barrierColor: Colors.black.withValues(
        alpha: 0.78,
      ),
      transitionDuration: const Duration(
        milliseconds: 350,
      ),
      pageBuilder: (
        dialogContext,
        animation,
        secondaryAnimation,
      ) {
        return SafeArea(
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _CompletionRewardCard(
                  problem: widget.problem,
                  xp: _xp,
                  streak: streak,
                  totalCompleted: state.completed,
                  compliment: compliment,
                  motivation: motivation,
                  onNext: () {
                    Navigator.pop(
                      dialogContext,
                    );

                    _openNextProblem(
                      state,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (
        dialogContext,
        animation,
        secondaryAnimation,
        child,
      ) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.90,
              end: 1.0,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // COMPLIMENTS
  // ---------------------------------------------------------------------------

  String _getCompliment({
    required String difficulty,
    required int completed,
    required int streak,
  }) {
    if (completed == 150) {
      return "You didn't just finish a list. You built a habit.";
    }

    if (completed == 100) {
      return '100 problems. That is serious interview prep.';
    }

    if (completed == 50) {
      return 'Halfway there. Your consistency is showing.';
    }

    if (streak >= 14) {
      return 'Two weeks straight. You are locked in.';
    }

    if (streak >= 7) {
      return 'A full week of grinding. Keep going.';
    }

    if (difficulty == 'Hard') {
      return 'That one was nasty. And you still cleared it.';
    }

    if (difficulty == 'Medium') {
      return 'Nice. Medium problems are where the patterns start clicking.';
    }

    final compliments = [
      'Clean work. Keep the momentum.',
      'One more pattern added to the toolkit.',
      'That counts. Your future interviewer is going to like this.',
      'Small win. Bigger compounding effect.',
      'Nice. Your problem-solving muscle is getting stronger.',
    ];

    return compliments[completed % compliments.length];
  }

  // ---------------------------------------------------------------------------
  // NEXT PROBLEM
  // ---------------------------------------------------------------------------

  void _openNextProblem(
    AppState state,
  ) {
    final next = state.nextProblem;

    if (next == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "You cleared the board. That's a serious grind. 🫡",
          ),
        ),
      );

      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ProblemDetailScreen(
          problem: next,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RELATIVE DATE
  // ---------------------------------------------------------------------------

  String _relative(
    DateTime d,
  ) {
    final diff = DateTime.now().difference(d);

    if (diff.inDays == 0) {
      return 'today';
    }

    if (diff.inDays == 1) {
      return 'yesterday';
    }

    if (diff.isNegative) {
      return 'in ${-diff.inDays} days';
    }

    return '${diff.inDays} days ago';
  }
}

// =============================================================================
// AI COACH CARD
// =============================================================================

class _AiFormattedText extends StatelessWidget {
  final String text;
  final bool approach;

  const _AiFormattedText({
    required this.text,
    required this.approach,
  });

  static const _tangerine = Color(0xFFFF9F43);

  static const _sectionNames = {
    'PATTERN',
    'CORE IDEA',
    'HOW IT WORKS',
    'TIME COMPLEXITY',
    'SPACE COMPLEXITY',
  };

  @override
  Widget build(BuildContext context) {
    final normalized = _ProblemDetailScreenState._normalizeComplexityText(text);

    // -------------------------------------------------------------------------
    // HINTS
    // -------------------------------------------------------------------------

    if (!approach) {
      return _buildRichText(
        normalized,
        GoogleFonts.inter(
          color: Colors.white,
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    // -------------------------------------------------------------------------
    // APPROACH
    // -------------------------------------------------------------------------

    final lines = normalized.split('\n');
    final children = <Widget>[];

    for (final rawLine in lines) {
      final raw = rawLine.trim();

      if (raw.isEmpty) {
        children.add(
          const SizedBox(height: 7),
        );
        continue;
      }

      final heading = raw.replaceAll(':', '').trim().toUpperCase();

      // -----------------------------------------------------------------------
      // TANGERINE SECTION HEADING
      // -----------------------------------------------------------------------

      if (_sectionNames.contains(heading)) {
        children.add(
          Padding(
            padding: EdgeInsets.only(
              top: children.isEmpty ? 0 : 13,
              bottom: 6,
            ),
            child: Text(
              heading,
              style: GoogleFonts.spaceMono(
                color: _tangerine,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.7,
              ),
            ),
          ),
        );

        continue;
      }

      // -----------------------------------------------------------------------
      // NORMAL GOOGLE-FONT CONTENT
      // -----------------------------------------------------------------------

      children.add(
        _buildRichText(
          raw,
          GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildRichText(
    String value,
    TextStyle style,
  ) {
    final spans = <TextSpan>[];

    final complexityRegex = RegExp(
      r'\bO\s*\([^)]*\)',
      caseSensitive: false,
    );

    var cursor = 0;

    for (final match in complexityRegex.allMatches(value)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: value.substring(
              cursor,
              match.start,
            ),
          ),
        );
      }

      final complexity = match.group(0)!;

      spans.add(
        TextSpan(
          text: complexity,
          style: GoogleFonts.spaceMono(
            color: _tangerine,
            fontSize: style.fontSize,
            height: style.height,
            fontWeight: FontWeight.w900,
          ),
        ),
      );

      cursor = match.end;
    }

    if (cursor < value.length) {
      spans.add(
        TextSpan(
          text: value.substring(cursor),
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: style,
        children: spans,
      ),
    );
  }
}

// =============================================================================
// AI COACH CARD
// =============================================================================

class _AiCoachCard extends StatelessWidget {
  final bool loading;
  final String? text;
  final String? mode;

  final VoidCallback? onHint;
  final VoidCallback? onDeeperHint;
  final VoidCallback? onApproach;
  final VoidCallback? onBack;
  final String? backLabel;

  const _AiCoachCard({
    required this.loading,
    required this.text,
    required this.mode,
    required this.onHint,
    required this.onDeeperHint,
    required this.onApproach,
    required this.onBack,
    this.backLabel,
  });

  String get _label {
    switch (mode) {
      case 'hint1':
        return 'HINT 01';
      case 'hint2':
        return 'HINT 02';
      case 'approach':
        return 'APPROACH';
      default:
        return 'AI COACH';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: acid.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: acid.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: SvgPicture.asset(
                  'assets/icons/core/ai_coach.svg',
                  width: 24,
                  height: 24,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI COACH',
                      style: technicalTextStyle(
                        color: acid,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.7,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Stuck? Get a nudge, not the answer.',
                      style: humanTextStyle(
                        color: muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (loading) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: acid,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Thinking...',
                  style: humanTextStyle(
                    color: muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          if (!loading && text != null) ...[
            const SizedBox(height: 18),
            Text(
              _label,
              style: technicalTextStyle(
                color: acid,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            _AiFormattedText(
              text: text!,
              approach: mode == 'approach',
            ),
          ],
          const SizedBox(height: 18),
          if (!loading && text == null && onHint != null)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: onHint,
                icon: SvgPicture.asset(
                  'assets/icons/core/ai_coach.svg',
                  width: 19,
                  height: 19,
                  colorFilter: const ColorFilter.mode(
                    ink,
                    BlendMode.srcIn,
                  ),
                ),
                label: Text(
                  'Get a hint',
                  style: humanTextStyle(
                    color: ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          if (!loading &&
              text != null &&
              (onDeeperHint != null || onApproach != null))
            Row(
              children: [
                if (onDeeperHint != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDeeperHint,
                      child: Text(
                        'Deeper hint',
                        style: humanTextStyle(
                          color: acid,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                if (onDeeperHint != null && onApproach != null)
                  const SizedBox(width: 10),
                if (onApproach != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onApproach,
                      child: Text(
                        'Show approach',
                        style: humanTextStyle(
                          color: acid,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          if (!loading && text != null && onBack != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 17,
                  color: muted,
                ),
                label: Text(
                  mode == 'approach' ? 'Back to $backLabel' : 'Back to Hint 01',
                  style: humanTextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// COMPLETION REWARD CARD
// =============================================================================

class _CompletionRewardCard extends StatefulWidget {
  final Problem problem;
  final int xp;
  final int streak;
  final int totalCompleted;
  final String compliment;
  final String? motivation;
  final VoidCallback onNext;

  const _CompletionRewardCard({
    required this.problem,
    required this.xp,
    required this.streak,
    required this.totalCompleted,
    required this.compliment,
    this.motivation,
    required this.onNext,
  });

  @override
  State<_CompletionRewardCard> createState() => _CompletionRewardCardState();
}

class _CompletionRewardCardState extends State<_CompletionRewardCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 650,
      ),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
      child: GlowCard(
        padding: const EdgeInsets.fromLTRB(
          22,
          24,
          22,
          22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: acid.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: acid.withValues(
                        alpha: 0.25,
                      ),
                    ),
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/core/check.svg',
                    width: 28,
                    height: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'COMPLETED',
                    style: technicalTextStyle(
                      color: acid,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              '+${widget.xp} XP',
              style: technicalTextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.problem.title,
              style: humanTextStyle(
                color: muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: line,
                ),
              ),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/icons/core/streak.svg',
                    width: 21,
                    height: 21,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.streak} day streak',
                    style: humanTextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.totalCompleted}/150',
                    style: technicalTextStyle(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.compliment,
              style: humanTextStyle(
                fontSize: 16,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (widget.motivation != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: acid.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: acid.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  widget.motivation!,
                  style: humanTextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: white,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: widget.onNext,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Next Problem',
                      style: humanTextStyle(
                        color: ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SvgPicture.asset(
                      'assets/icons/core/arrow_forward.svg',
                      width: 19,
                      height: 19,
                      colorFilter: const ColorFilter.mode(
                        ink,
                        BlendMode.srcIn,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
