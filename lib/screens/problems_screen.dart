import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/problem.dart';
import '../providers/app_controller.dart';
import '../widgets/ui.dart';
import '../widgets/app_theme.dart';
import 'problem_detail_screen.dart';

class ProblemsScreen extends ConsumerStatefulWidget {
  final bool initialReviewOnly;

  const ProblemsScreen({
    super.key,
    this.initialReviewOnly = false,
  });

  @override
  ConsumerState<ProblemsScreen> createState() => _ProblemsScreenState();
}

class _ProblemsScreenState extends ConsumerState<ProblemsScreen> {
  String query = '';
  String topic = 'All';
  String difficulty = 'All';
  String status = 'All';
  String sort = 'Default';
  late bool reviewOnly;

  @override
  void initState() {
    super.initState();
    reviewOnly = widget.initialReviewOnly;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(appControllerProvider);

    return async.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Unable to load problems: $e',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (state) {
        final topics = [
          'All',
          ...state.problems.map((p) => p.topic).toSet(),
        ];

        var list = state.problems.where((p) {
          final pr = state.progress[p.id];

          final matchesQuery =
              p.title.toLowerCase().contains(query.trim().toLowerCase());

          final matchesTopic = topic == 'All' || p.topic == topic;

          final matchesDiff = difficulty == 'All' || p.difficulty == difficulty;

          final done = pr?.completed ?? false;

          final matchesStatus = status == 'All' ||
              (status == 'Completed' && done) ||
              (status == 'Not Completed' && !done);

          final due = pr?.reviewDueAt != null &&
              !(pr!.reviewDueAt!.isAfter(DateTime.now()));

          return matchesQuery &&
              matchesTopic &&
              matchesDiff &&
              matchesStatus &&
              (!reviewOnly || due);
        }).toList();

        if (sort == 'Difficulty') {
          list.sort(
            (a, b) => _difficulty(a).compareTo(_difficulty(b)),
          );
        }

        if (sort == 'Topic') {
          list.sort(
            (a, b) => a.topic.compareTo(b.topic),
          );
        }

        if (sort == 'Completed/incomplete') {
          list.sort(
            (a, b) =>
                (state.progress[a.id]?.completed ?? false).toString().compareTo(
                      (state.progress[b.id]?.completed ?? false).toString(),
                    ),
          );
        }

        if (sort == 'Recently completed') {
          list.sort(
            (a, b) =>
                (state.progress[b.id]?.completedAt ?? DateTime(1970)).compareTo(
              state.progress[a.id]?.completedAt ?? DateTime(1970),
            ),
          );
        }

        if (sort == 'Recommended next') {
          list.sort((a, b) {
            final ac = state.progress[a.id]?.completed ?? false;
            final bc = state.progress[b.id]?.completed ?? false;

            return ac == bc ? a.order.compareTo(b.order) : (ac ? 1 : -1);
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Problems',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            actions: [
              if (reviewOnly)
                IconButton(
                  tooltip: 'Clear review filter',
                  onPressed: () {
                    setState(() {
                      reviewOnly = false;
                    });
                  },
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                // ---------------------------------------------------------------
                // SEARCH
                // ---------------------------------------------------------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    8,
                  ),
                  child: TextField(
                    onChanged: (v) {
                      setState(() {
                        query = v;
                      });
                    },
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search 150 problems...',
                      isDense: true,
                    ),
                  ),
                ),

                // ---------------------------------------------------------------
                // FILTER BAR
                // ---------------------------------------------------------------
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    itemCount: 4,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      switch (index) {
                        case 0:
                          return _filterChip(
                            'Topic',
                            topic,
                            topics,
                          );
                        case 1:
                          return _filterChip(
                            'Difficulty',
                            difficulty,
                            ['All', 'Easy', 'Medium', 'Hard'],
                          );
                        case 2:
                          return _filterChip(
                            'Status',
                            status,
                            [
                              'All',
                              'Completed',
                              'Not Completed',
                            ],
                          );
                        default:
                          return _filterChip(
                            'Sort',
                            sort,
                            [
                              'Default',
                              'Difficulty',
                              'Topic',
                              'Completed/incomplete',
                              'Recently completed',
                              'Recommended next',
                            ],
                          );
                      }
                    },
                  ),
                ),

                // ---------------------------------------------------------------
                // RESULT SUMMARY
                // ---------------------------------------------------------------
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    2,
                    20,
                    8,
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${list.length} problems',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (reviewOnly)
                        const Flexible(
                          child: Text(
                            'REVIEW QUEUE',
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: acid,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ---------------------------------------------------------------
                // PROBLEM LIST / EMPTY STATE
                // ---------------------------------------------------------------
                Expanded(
                  child: list.isEmpty
                      ? _EmptyResults(
                          hasFilters: _hasActiveFilters(),
                          onClear: _clearFilters,
                        )
                      : ListView.builder(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: list.length,
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            24,
                          ),
                          itemBuilder: (context, index) {
                            final p = list[index];
                            final pr = state.progress[p.id];
                            final done = pr?.completed ?? false;

                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: 8,
                              ),
                              child: GlowCard(
                                padding: const EdgeInsets.all(14),
                                onTap: () {
                                  FocusScope.of(context).unfocus();

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProblemDetailScreen(
                                        problem: p,
                                      ),
                                    ),
                                  );
                                },
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Problem number
                                    SizedBox(
                                      width: 30,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4,
                                        ),
                                        child: Text(
                                          '${p.order}'.padLeft(
                                            2,
                                            '0',
                                          ),
                                          style: const TextStyle(
                                            color: muted,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 8),

                                    // Completion indicator
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 1,
                                      ),
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: done
                                              ? acid.withValues(
                                                  alpha: 0.14,
                                                )
                                              : surface2,
                                          border: Border.all(
                                            color: done ? acid : line,
                                          ),
                                        ),
                                        child: Icon(
                                          done
                                              ? Icons.check
                                              : Icons.circle_outlined,
                                          size: 16,
                                          color: done ? acid : muted,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 12),

                                    // Flexible problem information
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.title,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              decoration: done
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(
                                            height: 5,
                                          ),
                                          Text(
                                            p.topic,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: muted,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(width: 8),

                                    // Difficulty + review indicator
                                    Flexible(
                                      flex: 0,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          DifficultyPill(
                                            difficulty: p.difficulty,
                                          ),
                                          if (pr?.reviewDueAt != null)
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                top: 6,
                                              ),
                                              child: Icon(
                                                Icons.bookmark_outline,
                                                color: acid,
                                                size: 17,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _hasActiveFilters() {
    return query.trim().isNotEmpty ||
        topic != 'All' ||
        difficulty != 'All' ||
        status != 'All' ||
        sort != 'Default' ||
        reviewOnly;
  }

  void _clearFilters() {
    setState(() {
      query = '';
      topic = 'All';
      difficulty = 'All';
      status = 'All';
      sort = 'Default';
      reviewOnly = false;
    });
  }

  int _difficulty(Problem p) {
    if (p.difficulty == 'Easy') {
      return 0;
    }

    if (p.difficulty == 'Medium') {
      return 1;
    }

    return 2;
  }

  Widget _filterChip(
    String label,
    String value,
    List<String> values,
  ) {
    return ActionChip(
      label: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 220,
        ),
        child: Text(
          '$label: $value',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      onPressed: () => _choose(label, values),
    );
  }

  // ---------------------------------------------------------------------------
  // RESPONSIVE FILTER BOTTOM SHEET
  // ---------------------------------------------------------------------------

  Future<void> _choose(
    String label,
    List<String> values,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: surface,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);
        final screenHeight = media.size.height;

        // Keep the sheet within a safe percentage of the available
        // screen. The ListView below handles any remaining options.
        final maxHeight = screenHeight * 0.78;

        final currentValue = label == 'Topic'
            ? topic
            : label == 'Difficulty'
                ? difficulty
                : label == 'Status'
                    ? status
                    : sort;

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxHeight,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),

                // Bottom-sheet handle
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),

                const SizedBox(height: 14),

                // Sheet header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${values.length} options',
                        style: const TextStyle(
                          color: muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Scrollable options.
                Flexible(
                  child: Scrollbar(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(
                        top: 4,
                        bottom: 12,
                      ),
                      itemCount: values.length,
                      itemBuilder: (context, index) {
                        final value = values[index];
                        final selected = value == currentValue;

                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                          ),
                          title: Text(
                            value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight:
                                  selected ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                          trailing: selected
                              ? const Icon(
                                  Icons.check,
                                  color: acid,
                                )
                              : null,
                          onTap: () {
                            Navigator.pop(
                              context,
                              value,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked == null) {
      return;
    }

    setState(() {
      if (label == 'Topic') {
        topic = picked;
      } else if (label == 'Difficulty') {
        difficulty = picked;
      } else if (label == 'Status') {
        status = picked;
      } else {
        sort = picked;
      }
    });
  }
}

// -----------------------------------------------------------------------------
// EMPTY RESULTS STATE
// -----------------------------------------------------------------------------

class _EmptyResults extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClear;

  const _EmptyResults({
    required this.hasFilters,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 420,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: acid.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  color: acid,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No problems found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                hasFilters
                    ? 'Try changing your search or filters.'
                    : 'There are no problems to display right now.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: muted,
                  fontSize: 13,
                ),
              ),
              if (hasFilters) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Clear filters'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
