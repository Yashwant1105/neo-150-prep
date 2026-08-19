import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/problem.dart';
import '../providers/app_controller.dart';
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

        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                onPressed: () => launchUrl(
                  Uri.parse(widget.problem.externalUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new),
                tooltip: 'Open problem',
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
              Text(
                'PROBLEM ${widget.problem.order.toString().padLeft(2, '0')}',
                style: const TextStyle(
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
                      style: const TextStyle(
                        color: muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
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
                          child: Icon(
                            progress.completed
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            key: ValueKey(progress.completed),
                            color: progress.completed ? acid : muted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          progress.completed ? 'Completed' : 'Not completed',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '+$_xp XP',
                          style: const TextStyle(
                            color: acid,
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
                        icon: Icon(
                          progress.completed ? Icons.undo : Icons.check,
                        ),
                        label: Text(
                          progress.completed
                              ? 'Mark incomplete'
                              : 'Mark as completed',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref
                      .read(appControllerProvider.notifier)
                      .flagForReview(widget.problem);

                  if (!mounted) {
                    return;
                  }

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Review queued for 14 days.',
                      ),
                    ),
                  );
                },
                icon: Icon(
                  progress.reviewDueAt != null
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  color: acid,
                ),
                label: Text(
                  progress.reviewDueAt != null
                      ? 'Flagged for review'
                      : 'Flag for review',
                ),
              ),
              const SizedBox(height: 26),
              const SectionTitle(
                title: 'Your notes',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notes,
                maxLines: 9,
                onChanged: (value) {
                  ref.read(appControllerProvider.notifier).saveNotes(
                        widget.problem,
                        value,
                      );
                },
                decoration: const InputDecoration(
                  hintText:
                      'Approach, gotchas, complexity, things to revisit...',
                ),
              ),
              const SizedBox(height: 20),
              if (progress.completedAt != null)
                Text(
                  'Completed ${_relative(progress.completedAt!)}',
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                  ),
                ),
              if (progress.reviewDueAt != null)
                Text(
                  'Review due ${_relative(progress.reviewDueAt!)}',
                  style: const TextStyle(
                    color: acid,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleCompletion(bool wasCompleted) async {
    final controller = ref.read(appControllerProvider.notifier);

    await controller.toggleComplete(widget.problem);

    if (!mounted) {
      return;
    }

    // Only reward the transition:
    //
    // incomplete → completed
    //
    // Completing → incomplete should not show XP reward.
    if (!wasCompleted) {
      final updatedState = ref.read(appControllerProvider).value;

      if (updatedState == null) {
        return;
      }

      _showCompletionReward(updatedState);
    }
  }

  void _showCompletionReward(AppState state) {
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
      barrierColor: Colors.black.withValues(alpha: 0.78),
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
                  onNext: () {
                    Navigator.pop(dialogContext);
                    _openNextProblem(state);
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

  void _openNextProblem(AppState state) {
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

  String _relative(DateTime d) {
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

class _CompletionRewardCard extends StatefulWidget {
  final Problem problem;
  final int xp;
  final int streak;
  final int totalCompleted;
  final String compliment;
  final VoidCallback onNext;

  const _CompletionRewardCard({
    required this.problem,
    required this.xp,
    required this.streak,
    required this.totalCompleted,
    required this.compliment,
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
                    color: acid.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: acid.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: acid,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'COMPLETED',
                    style: TextStyle(
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
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.problem.title,
              style: const TextStyle(
                color: muted,
                fontSize: 13,
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
                  const Text(
                    '🔥',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.streak} day streak',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${widget.totalCompleted}/150',
                    style: const TextStyle(
                      color: muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.compliment,
              style: const TextStyle(
                fontSize: 16,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: widget.onNext,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Next Problem',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 19,
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
s