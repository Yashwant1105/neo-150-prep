import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'interview_history_screen.dart';

import '../models/problem.dart';
import '../providers/app_controller.dart';
import '../services/ai_coach_service.dart';
import '../services/supabase_service.dart';
import '../widgets/app_theme.dart';
import '../widgets/ui.dart';
import '../widgets/mp_icon.dart';

class InterviewScreen extends ConsumerStatefulWidget {
  final Problem? initialProblem;

  const InterviewScreen({
    super.key,
    this.initialProblem,
  });

  @override
  ConsumerState<InterviewScreen> createState() => _InterviewScreenState();
}

class _InterviewScreenState extends ConsumerState<InterviewScreen> {
  final _answerController = TextEditingController();
  final _ai = AiCoachService();

  Problem? _problem;
  String? _question;
  String? _feedback;

  int _questionNumber = 0;
  int? _score;
  bool _loading = false;
  bool _submitting = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();

    _problem = widget.initialProblem;

    // When Interview Me is opened directly from a completed problem,
    // there is no problem-picker interaction to call _start().
    // Start the interview after the first frame so the screen is mounted.
    if (widget.initialProblem != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _start(widget.initialProblem!);
      });
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _buildUserContext(Problem problem) async {
    final state = ref.read(appControllerProvider).value;
    if (state == null) return null;

    Map<String, dynamic>? interviewContext;
    final userId = SupabaseService.currentSession?.user.id;

    if (userId != null) {
      try {
        interviewContext =
            await SupabaseService().fetchRecentInterviewStats(userId);
      } catch (_) {
        interviewContext = null;
      }
    }

    return state.buildAiCoachContext(interviewContext: interviewContext);
  }

  Future<void> _start(Problem problem) async {
    setState(() {
      _problem = problem;
      _question = null;
      _feedback = null;
      _score = null;
      _questionNumber = 1;
      _finished = false;
      _loading = true;
      _answerController.clear();
    });

    try {
      final state = ref.read(appControllerProvider).value;
      final notes = state?.progress[problem.id]?.notes ?? '';
      final userContext = await _buildUserContext(problem);

      final question = await _ai.getInterviewQuestion(
        title: problem.title,
        topic: problem.topic,
        difficulty: problem.difficulty,
        questionNumber: 1,
        notes: notes,
        userContext: userContext,
      );

      if (!mounted) return;

      setState(() {
        _question = _cleanText(question);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Interview could not start: $e'),
        ),
      );
    }
  }

  Future<void> _submitAnswer() async {
    final problem = _problem;
    final question = _question;
    final answer = _answerController.text.trim();

    if (problem == null || question == null || answer.isEmpty || _submitting) {
      return;
    }

    setState(() => _submitting = true);

    try {
      final state = ref.read(appControllerProvider).value;
      final notes = state?.progress[problem.id]?.notes ?? '';
      final userContext = await _buildUserContext(problem);

      final rawFeedback = await _ai.getInterviewFeedback(
        title: problem.title,
        topic: problem.topic,
        difficulty: problem.difficulty,
        question: question,
        answer: answer,
        questionNumber: _questionNumber,
        notes: notes,
        userContext: userContext,
      );

      final cleanedFeedback = _cleanText(rawFeedback);
      final parsedScore = _extractScore(rawFeedback);

      // Persist the answer + AI evaluation immediately.
      // Q2 is marked as the completed session; Q1 remains part of the same
      // session but is not considered complete yet.
      try {
        await ref.read(appControllerProvider.notifier).saveInterviewAttempt(
              problem: problem,
              questionNumber: _questionNumber,
              question: question,
              answer: answer,
              feedback: cleanedFeedback,
              score: parsedScore,
              sessionCompleted: _questionNumber == 2,
            );
      } catch (saveError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Feedback loaded, but interview history could not be saved: $saveError',
              ),
            ),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _feedback = cleanedFeedback;
        _score = parsedScore;
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _submitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not evaluate your answer: $e'),
        ),
      );
    }
  }

  Future<void> _nextQuestion() async {
    final problem = _problem;

    if (problem == null || _questionNumber >= 2) {
      setState(() => _finished = true);
      return;
    }

    setState(() {
      _questionNumber = 2;
      _question = null;
      _feedback = null;
      _score = null;
      _answerController.clear();
      _loading = true;
    });

    try {
      final state = ref.read(appControllerProvider).value;
      final notes = state?.progress[problem.id]?.notes ?? '';
      final userContext = await _buildUserContext(problem);

      final question = await _ai.getInterviewQuestion(
        title: problem.title,
        topic: problem.topic,
        difficulty: problem.difficulty,
        questionNumber: 2,
        notes: notes,
        userContext: userContext,
      );

      if (!mounted) return;

      setState(() {
        _question = _cleanText(question);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load the next question: $e'),
        ),
      );
    }
  }

  void _reset() {
    setState(() {
      _problem = null;
      _question = null;
      _feedback = null;
      _score = null;
      _questionNumber = 0;
      _loading = false;
      _submitting = false;
      _finished = false;
      _answerController.clear();
    });
  }

  int? _extractScore(String text) {
    final match = RegExp(
      r'(?:SCORE|Score)\s*[:\-]?\s*(\d{1,2})\s*/\s*10',
    ).firstMatch(text);

    if (match == null) return null;

    final value = int.tryParse(match.group(1)!);

    if (value == null) return null;

    return value.clamp(0, 10);
  }

  String _cleanText(String text) {
    final cleaned = text
        .replaceAll(
          RegExp(r'\*\*(.*?)\*\*'),
          r'$1',
        )
        .replaceAll(
          RegExp(r'__(.*?)__'),
          r'$1',
        )
        .replaceAll(
          RegExp(r'^#{1,6}\s*', multiLine: true),
          '',
        )
        .replaceAll(
          RegExp(r'^\s*[-•]\s*', multiLine: true),
          '',
        )
        .replaceAll(
          RegExp(r'\n{3,}'),
          '\n\n',
        )
        .trim();

    return _normalizeComplexityText(cleaned);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Interview',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Interview History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const InterviewHistoryScreen(),
                ),
              );
            },
            icon: MpIcon(
              'core/interview_history',
              size: 23,
            ),
          ),
          if (_problem != null)
            IconButton(
              tooltip: 'Choose another problem',
              onPressed: _reset,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
            ),
        ],
      ),
      body: state.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Unable to load interview: $e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (appState) {
          if (_problem == null) {
            return _ProblemPicker(
              problems: appState.problems
                  .where(
                    (p) => appState.progress[p.id]?.completed == true,
                  )
                  .toList()
                ..sort((a, b) {
                  final aDone = appState.hasCompletedInterview(a.id);
                  final bDone = appState.hasCompletedInterview(b.id);
                  if (aDone == bDone) return a.order.compareTo(b.order);
                  return aDone ? 1 : -1;
                }),
              onSelect: _start,
            );
          }

          return _InterviewSession(
            problem: _problem!,
            question: _question,
            feedback: _feedback,
            score: _score,
            questionNumber: _questionNumber,
            loading: _loading,
            submitting: _submitting,
            finished: _finished,
            answerController: _answerController,
            onSubmit: _submitAnswer,
            onNext: _nextQuestion,
            onRestart: () => _start(_problem!),
            onChooseAnother: _reset,
          );
        },
      ),
    );
  }
}

// =============================================================================
// SHARED COMPLEXITY NORMALIZER
// =============================================================================

String _normalizeComplexityText(String value) {
  var text = value;

  // ---------------------------------------------------------------------------
  // REMOVE MARKDOWN / LATEX WRAPPERS
  // ---------------------------------------------------------------------------

  // Handles:
  // $O(1)$
  // \$O(1)\$
  // \(O(1)\)
  // \[O(1)\]
  // `O(1)`
  text = text
      .replaceAll(r'\$', '')
      .replaceAll('\$', '')
      .replaceAll(r'\(', '')
      .replaceAll(r'\)', '')
      .replaceAll(r'\[', '')
      .replaceAll(r'\]', '')
      .replaceAll('`', '');

  // Remove Markdown emphasis.
  text = text.replaceAll(RegExp(r'\*\*'), '').replaceAll(RegExp(r'__'), '');

  // ---------------------------------------------------------------------------
  // NORMALIZE COMMON AI COMPLEXITY FORMATS
  // ---------------------------------------------------------------------------

  final replacements = <String, String>{
    r'\bO\s+of\s+n\s+log\s+n\b': 'O(n log n)',
    r'\bO\s+of\s+log\s+n\b': 'O(log n)',
    r'\bO\s+of\s+n\b': 'O(n)',
    r'\bO\s+of\s+1\b': 'O(1)',
    r'\bO\s+of\s+m\s*\+\s*n\b': 'O(m + n)',
    r'\bO\s+of\s+n\s*\+\s*m\b': 'O(n + m)',
    r'\bO\s+of\s+n\s+square\b': 'O(n²)',
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
  // CLEAN MARKDOWN HEADINGS / BULLETS
  // ---------------------------------------------------------------------------

  text = text
      .replaceAll(
        RegExp(
          r'^\s*#{1,6}\s*',
          multiLine: true,
        ),
        '',
      )
      .replaceAll(
        RegExp(
          r'^\s*[-*•]\s+',
          multiLine: true,
        ),
        '',
      )
      .replaceAll(
        RegExp(r'\n{3,}'),
        '\n\n',
      )
      .trim();

  return text;
}
// =============================================================================
// PROBLEM PICKER
// =============================================================================

class _ProblemPicker extends StatelessWidget {
  final List<Problem> problems;
  final ValueChanged<Problem> onSelect;

  const _ProblemPicker({
    required this.problems,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        30,
      ),
      children: [
        GlowCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🎤 MOCK INTERVIEW',
                style: TextStyle(
                  color: acid,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.7,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Practice explaining problems like you are in a real technical interview.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a completed problem. You will get two interview questions followed by AI feedback.',
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle(
          title: 'Completed problems',
        ),
        const SizedBox(height: 10),
        if (problems.isEmpty)
          GlowCard(
            child: Column(
              children: const [
                Icon(
                  Icons.lock_outline,
                  color: muted,
                  size: 30,
                ),
                SizedBox(height: 10),
                Text(
                  'Complete a problem first',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Your completed problems will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        else
          ...problems.map(
            (problem) => Padding(
              padding: const EdgeInsets.only(
                bottom: 10,
              ),
              child: GlowCard(
                padding: EdgeInsets.zero,
                onTap: () => onSelect(problem),
                child: ListTile(
                  title: Text(
                    problem.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    '${problem.topic} • ${problem.difficulty}',
                    style: const TextStyle(
                      color: muted,
                      fontSize: 11,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: acid,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// INTERVIEW SESSION
// =============================================================================

class _InterviewSession extends StatelessWidget {
  final Problem problem;
  final String? question;
  final String? feedback;
  final int? score;
  final int questionNumber;
  final bool loading;
  final bool submitting;
  final bool finished;
  final TextEditingController answerController;
  final VoidCallback onSubmit;
  final VoidCallback onNext;
  final VoidCallback onRestart;
  final VoidCallback onChooseAnother;

  const _InterviewSession({
    required this.problem,
    required this.question,
    required this.feedback,
    required this.score,
    required this.questionNumber,
    required this.loading,
    required this.submitting,
    required this.finished,
    required this.answerController,
    required this.onSubmit,
    required this.onNext,
    required this.onRestart,
    required this.onChooseAnother,
  });

  @override
  Widget build(BuildContext context) {
    if (finished) {
      return _FinishedView(
        problem: problem,
        onRestart: onRestart,
        onChooseAnother: onChooseAnother,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        30,
      ),
      children: [
        // ---------------------------------------------------------------------
        // PROBLEM HEADER
        // ---------------------------------------------------------------------

        Row(
          children: [
            Expanded(
              child: Text(
                problem.title,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            DifficultyPill(
              difficulty: problem.difficulty,
            ),
          ],
        ),

        const SizedBox(height: 6),

        Text(
          '${problem.topic} • Question $questionNumber of 2',
          style: GoogleFonts.inter(
            color: muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 18),

        // ---------------------------------------------------------------------
        // INTERVIEW QUESTION
        // ---------------------------------------------------------------------

        if (loading)
          const GlowCard(
            child: SizedBox(
              height: 150,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          )
        else if (question != null)
          GlowCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _InterviewSectionLabel(
                  'INTERVIEWER',
                ),
                const SizedBox(height: 10),
                _ComplexityRichText(
                  text: question!,
                  baseStyle: GoogleFonts.inter(
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 14),

        // ---------------------------------------------------------------------
        // YOUR ANSWER
        // ---------------------------------------------------------------------

        if (feedback == null && !loading)
          GlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _InterviewSectionLabel(
                  'YOUR ANSWER',
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: answerController,
                  minLines: 5,
                  maxLines: 8,
                  textInputAction: TextInputAction.newline,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Explain your reasoning...',
                    hintStyle: GoogleFonts.inter(
                      color: muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: submitting ? null : onSubmit,
                    child: submitting
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Submit answer',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),

        // ---------------------------------------------------------------------
        // FEEDBACK
        // ---------------------------------------------------------------------

        if (feedback != null)
          GlowCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: _InterviewSectionLabel(
                        'FEEDBACK',
                      ),
                    ),
                    if (score != null)
                      Text(
                        '$score/10',
                        style: GoogleFonts.spaceMono(
                          color: acid,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _InterviewFeedbackText(
                  text: feedback!,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: onNext,
                    child: Text(
                      questionNumber == 1
                          ? 'Next question'
                          : 'Finish interview',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// INTERVIEW SECTION LABEL
// =============================================================================

class _InterviewSectionLabel extends StatelessWidget {
  final String text;

  const _InterviewSectionLabel(
    this.text,
  );

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.spaceMono(
        color: const Color(0xFFFF9F43),
        fontSize: 10,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.6,
      ),
    );
  }
}

// =============================================================================
// INTERVIEW FEEDBACK
// =============================================================================

class _InterviewFeedbackText extends StatelessWidget {
  final String text;

  const _InterviewFeedbackText({
    required this.text,
  });

  static const _tangerine = Color(0xFFFF9F43);

  static const _sectionNames = {
    'SCORE',
    'WHAT YOU DID WELL',
    'WHAT TO IMPROVE',
    'INTERVIEWER FEEDBACK',
  };

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeComplexityText(text);
    final lines = normalized.split('\n');
    final children = <Widget>[];

    for (final line in lines) {
      final raw = line.trim();

      if (raw.isEmpty) {
        children.add(
          const SizedBox(height: 7),
        );
        continue;
      }

      final heading = raw.replaceAll(':', '').trim().toUpperCase();

      // -----------------------------------------------------------------------
      // TANGERINE SUBSECTION
      // -----------------------------------------------------------------------

      if (_sectionNames.contains(heading)) {
        children.add(
          Padding(
            padding: EdgeInsets.only(
              top: children.isEmpty ? 0 : 12,
              bottom: 6,
            ),
            child: Text(
              heading,
              style: GoogleFonts.spaceMono(
                color: _tangerine,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.6,
              ),
            ),
          ),
        );

        continue;
      }

      // -----------------------------------------------------------------------
      // GOOGLE-FONT FEEDBACK CONTENT + COMPLEXITY FORMATTING
      // -----------------------------------------------------------------------

      children.add(
        _ComplexityRichText(
          text: raw,
          baseStyle: GoogleFonts.inter(
            color: white,
            fontSize: 13,
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

// =============================================================================
// COMPLEXITY TEXT
// =============================================================================

class _ComplexityRichText extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;

  const _ComplexityRichText({
    required this.text,
    required this.baseStyle,
  });

  static const _complexityColor = Color(0xFFFF9F43);

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeComplexityText(text);

    final spans = <TextSpan>[];

    final regex = RegExp(
      r'\bO\s*\([^)]*\)',
      caseSensitive: false,
    );

    var cursor = 0;

    for (final match in regex.allMatches(normalized)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: normalized.substring(
              cursor,
              match.start,
            ),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: match.group(0),
          style: GoogleFonts.spaceMono(
            color: _complexityColor,
            fontSize: baseStyle.fontSize,
            height: baseStyle.height,
            fontWeight: FontWeight.w900,
          ),
        ),
      );

      cursor = match.end;
    }

    if (cursor < normalized.length) {
      spans.add(
        TextSpan(
          text: normalized.substring(cursor),
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: spans,
      ),
    );
  }
}
// =============================================================================
// FINISHED VIEW
// =============================================================================

class _FinishedView extends StatelessWidget {
  final Problem problem;
  final VoidCallback onRestart;
  final VoidCallback onChooseAnother;

  const _FinishedView({
    required this.problem,
    required this.onRestart,
    required this.onChooseAnother,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        30,
        20,
        30,
      ),
      children: [
        GlowCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(
                Icons.mic_rounded,
                color: acid,
                size: 46,
              ),
              const SizedBox(height: 14),
              const Text(
                'INTERVIEW COMPLETE',
                style: TextStyle(
                  color: acid,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                problem.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nice work. Keep practicing how you explain your reasoning, not just how you solve.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: onRestart,
                  child: const Text(
                    'Interview again',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: onChooseAnother,
                  child: const Text(
                    'Choose another problem',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
