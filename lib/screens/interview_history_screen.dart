import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/supabase_service.dart';
import '../widgets/app_theme.dart';
import '../widgets/ui.dart';

class InterviewHistoryScreen extends ConsumerStatefulWidget {
  const InterviewHistoryScreen({super.key});

  @override
  ConsumerState<InterviewHistoryScreen> createState() =>
      _InterviewHistoryScreenState();
}

class _InterviewHistoryScreenState
    extends ConsumerState<InterviewHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<_InterviewHistorySession> _sessions = const [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final userId = SupabaseService.currentSession?.user.id;

    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Sign in to view your interview history.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await SupabaseService().fetchInterviewHistory(userId);
      final sessions = _buildSessions(rows);

      if (!mounted) return;

      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Could not load interview history.';
      });
    }
  }

  List<_InterviewHistorySession> _buildSessions(
    List<Map<String, dynamic>> rows,
  ) {
    // The current schema has no separate session_id. A completed session is
    // represented by its Q2 row (`session_completed = true`) and the Q1 row
    // immediately preceding it for the same problem. Build sessions from
    // that existing contract instead of adding another database table.
    final ascending = List<Map<String, dynamic>>.from(rows)
      ..sort((a, b) => _date(a).compareTo(_date(b)));

    final pendingQ1 = <String, Map<String, dynamic>>{};
    final sessions = <_InterviewHistorySession>[];

    for (final row in ascending) {
      final problemId = row['problem_id'] as String;
      final questionNumber = row['question_number'] as int;
      final completed = row['session_completed'] == true;

      if (questionNumber == 1 && !completed) {
        pendingQ1[problemId] = row;
        continue;
      }

      if (completed) {
        final q1 = pendingQ1.remove(problemId);
        final attempts = <_InterviewAttempt>[
          if (q1 != null) _InterviewAttempt.fromRow(q1),
          _InterviewAttempt.fromRow(row),
        ];

        sessions.add(
          _InterviewHistorySession.fromRows(
            problemId: problemId,
            rows: attempts,
            problemData: Map<String, dynamic>.from(row['problems'] as Map),
          ),
        );
      }
    }

    sessions.sort(
      (a, b) => b.completedAt.compareTo(a.completedAt),
    );

    return sessions;
  }

  DateTime _date(Map<String, dynamic> row) {
    return DateTime.tryParse(row['created_at'].toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Interview History',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh history',
            onPressed: _loading ? null : _loadHistory,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
        children: [
          GlowCard(
            child: Column(
              children: [
                const Icon(
                  Icons.history_rounded,
                  color: muted,
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: humanTextStyle(
                    color: muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadHistory,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_sessions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
        children: const [
          _EmptyHistoryCard(),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        itemCount: _sessions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final session = _sessions[index];

          return _HistoryCard(
            session: session,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _InterviewHistoryDetailScreen(
                    session: session,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _InterviewHistorySession {
  final String problemId;
  final String title;
  final String topic;
  final String difficulty;
  final List<_InterviewAttempt> attempts;
  final DateTime completedAt;

  const _InterviewHistorySession({
    required this.problemId,
    required this.title,
    required this.topic,
    required this.difficulty,
    required this.attempts,
    required this.completedAt,
  });

  factory _InterviewHistorySession.fromRows({
    required String problemId,
    required List<_InterviewAttempt> rows,
    required Map<String, dynamic> problemData,
  }) {
    return _InterviewHistorySession(
      problemId: problemId,
      title: problemData['title'] as String? ?? 'Unknown problem',
      topic: problemData['topic'] as String? ?? '',
      difficulty: problemData['difficulty'] as String? ?? '',
      attempts: rows,
      completedAt: rows.last.createdAt,
    );
  }

  int get totalScore => attempts.fold(
        0,
        (sum, attempt) => sum + (attempt.score ?? 0),
      );

  int get scoredCount =>
      attempts.where((attempt) => attempt.score != null).length;

  double? get averageScore {
    if (scoredCount == 0) return null;
    return totalScore / scoredCount;
  }
}

class _InterviewAttempt {
  final String id;
  final int questionNumber;
  final String question;
  final String answer;
  final String feedback;
  final int? score;
  final DateTime createdAt;

  const _InterviewAttempt({
    required this.id,
    required this.questionNumber,
    required this.question,
    required this.answer,
    required this.feedback,
    required this.score,
    required this.createdAt,
  });

  factory _InterviewAttempt.fromRow(Map<String, dynamic> row) {
    return _InterviewAttempt(
      id: row['id'] as String,
      questionNumber: (row['question_number'] as num).toInt(),
      question: row['question'] as String? ?? '',
      answer: row['answer'] as String? ?? '',
      feedback: row['feedback'] as String? ?? '',
      score: (row['score'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(row['created_at'].toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

String _topicIcon(String topic) {
  switch (topic) {
    case 'Arrays & Hashing':
      return 'assets/icons/topics/array.svg';
    case 'Two Pointers':
      return 'assets/icons/topics/two_pointers.svg';
    case 'Sliding Window':
      return 'assets/icons/topics/sliding_window.svg';
    case 'Stack':
      return 'assets/icons/topics/stack.svg';
    case 'Binary Search':
      return 'assets/icons/topics/binary_search.svg';
    case 'Linked List':
      return 'assets/icons/topics/linked_list.svg';
    case 'Trees':
      return 'assets/icons/topics/tree.svg';
    case 'Tries':
      return 'assets/icons/topics/tries.svg';
    case 'Heap / Priority Queue':
      return 'assets/icons/topics/heap.svg';
    case 'Backtracking':
      return 'assets/icons/topics/backtracking.svg';
    case 'Graphs':
      return 'assets/icons/topics/graph.svg';
    case 'Advanced Graphs':
      return 'assets/icons/topics/advanced_graph.svg';
    case '1-D Dynamic Programming':
      return 'assets/icons/topics/dp_1d.svg';
    case '2-D Dynamic Programming':
      return 'assets/icons/topics/dp_2d.svg';
    case 'Greedy':
      return 'assets/icons/topics/greedy.svg';
    case 'Intervals':
      return 'assets/icons/topics/intervals.svg';
    case 'Math & Geometry':
      return 'assets/icons/topics/math_geometry.svg';
    case 'Bit Manipulation':
      return 'assets/icons/topics/bit_manipulation.svg';
    default:
      return 'assets/icons/topics/array.svg';
  }
}

class _HistoryCard extends StatelessWidget {
  final _InterviewHistorySession session;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final average = session.averageScore;

    return GlowCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: acid.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: SvgPicture.asset(
              _topicIcon(session.topic),
              width: 26,
              height: 26,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${session.topic} • ${session.difficulty}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _relative(session.completedAt),
                  style: GoogleFonts.inter(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (average != null)
                Text(
                  '${average.toStringAsFixed(1)}/10',
                  style: GoogleFonts.spaceMono(
                    color: acid,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              const SizedBox(height: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: muted,
                size: 21,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _relative(DateTime date) {
    final diff = DateTime.now().difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays > 1) return '${diff.inDays} days ago';
    if (diff.inDays < 0) return 'Soon';
    return 'Recently';
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard();

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      child: Column(
        children: [
          const Icon(
            Icons.history_rounded,
            color: muted,
            size: 34,
          ),
          const SizedBox(height: 12),
          const Text(
            'No completed interviews yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Finish a two-question mock interview and it will appear here.',
            textAlign: TextAlign.center,
            style: humanTextStyle(
              color: muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InterviewHistoryDetailScreen extends StatelessWidget {
  final _InterviewHistorySession session;

  const _InterviewHistoryDetailScreen({
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final average = session.averageScore;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Interview Review',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          GlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INTERVIEW',
                  style: GoogleFonts.spaceMono(
                    color: acid,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  session.title,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${session.topic} • ${session.difficulty}',
                  style: GoogleFonts.inter(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (average != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${average.toStringAsFixed(1)}/10 average',
                    style: GoogleFonts.spaceMono(
                      color: acid,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...session.attempts.map(
            (attempt) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _AttemptDetailCard(
                attempt: attempt,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttemptDetailCard extends StatelessWidget {
  final _InterviewAttempt attempt;

  const _AttemptDetailCard({
    required this.attempt,
  });

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'QUESTION ${attempt.questionNumber}',
                  style: GoogleFonts.spaceMono(
                    color: const Color(0xFFFF9F43),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              if (attempt.score != null)
                Text(
                  '${attempt.score}/10',
                  style: GoogleFonts.spaceMono(
                    color: acid,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailSection(
            title: 'INTERVIEWER',
            child: _RichComplexityText(
              text: attempt.question,
            ),
          ),
          const SizedBox(height: 16),
          _DetailSection(
            title: 'YOUR ANSWER',
            child: Text(
              attempt.answer,
              style: GoogleFonts.inter(
                color: white,
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _DetailSection(
            title: 'AI FEEDBACK',
            child: _FeedbackRichText(
              text: attempt.feedback,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailSection({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.spaceMono(
            color: const Color(0xFFFF9F43),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 7),
        child,
      ],
    );
  }
}

class _RichComplexityText extends StatelessWidget {
  final String text;

  const _RichComplexityText({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeText(text);
    final spans = <TextSpan>[];
    final regex = RegExp(r'\bO\s*\([^)]*\)', caseSensitive: false);
    var cursor = 0;

    for (final match in regex.allMatches(normalized)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: normalized.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: GoogleFonts.spaceMono(
            color: const Color(0xFFFF9F43),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
      cursor = match.end;
    }

    if (cursor < normalized.length) {
      spans.add(TextSpan(text: normalized.substring(cursor)));
    }

    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(
          color: white,
          fontSize: 13,
          height: 1.5,
          fontWeight: FontWeight.w600,
        ),
        children: spans,
      ),
    );
  }
}

class _FeedbackRichText extends StatelessWidget {
  final String text;

  const _FeedbackRichText({
    required this.text,
  });

  static const _sectionNames = {
    'SCORE',
    'WHAT YOU DID WELL',
    'WHAT TO IMPROVE',
    'INTERVIEWER FEEDBACK',
  };

  @override
  Widget build(BuildContext context) {
    final lines = _normalizeText(text).split('\n');
    final children = <Widget>[];

    for (final line in lines) {
      final raw = line.trim();
      if (raw.isEmpty) {
        children.add(const SizedBox(height: 7));
        continue;
      }

      final heading = raw.replaceAll(':', '').trim().toUpperCase();
      if (_sectionNames.contains(heading)) {
        children.add(
          Padding(
            padding: EdgeInsets.only(
              top: children.isEmpty ? 0 : 10,
              bottom: 5,
            ),
            child: Text(
              heading,
              style: GoogleFonts.spaceMono(
                color: const Color(0xFFFF9F43),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ),
        );
        continue;
      }

      children.add(_RichComplexityText(text: raw));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

String _normalizeText(String value) {
  var text = value
      .replaceAll(r'\$', '')
      .replaceAll('\$', '')
      .replaceAll(r'\(', '')
      .replaceAll(r'\)', '')
      .replaceAll(r'\[', '')
      .replaceAll(r'\]', '')
      .replaceAll('`', '')
      .replaceAll(RegExp(r'\*\*'), '')
      .replaceAll(RegExp(r'__'), '');

  final replacements = <String, String>{
    r'\bO\s+of\s+n\s+log\s+n\b': 'O(n log n)',
    r'\bO\s+of\s+log\s+n\b': 'O(log n)',
    r'\bO\s+of\s+n\b': 'O(n)',
    r'\bO\s+of\s+1\b': 'O(1)',
    r'\bconstant\s+time\b': 'O(1)',
    r'\blogarithmic\s+time\b': 'O(log n)',
    r'\blinear\s+time\b': 'O(n)',
    r'\blinear\s+space\b': 'O(n)',
    r'\bconstant\s+space\b': 'O(1)',
  };

  for (final entry in replacements.entries) {
    text = text.replaceAll(
      RegExp(entry.key, caseSensitive: false),
      entry.value,
    );
  }

  text = text.replaceAllMapped(
    RegExp(r'\bO\s*\(\s*([^)]+?)\s*\)', caseSensitive: false),
    (match) => 'O(${match.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim()})',
  );

  return text
      .replaceAll(RegExp(r'^\s*[-*•]\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*#{1,6}\s+', multiLine: true), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
