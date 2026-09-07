import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/problem.dart';

class LocalRepository {
  Future<List<Problem>> loadProblems() async {
    final raw = await rootBundle.loadString('assets/data/neetcode150.json');
    final list = jsonDecode(raw) as List;
    return list.map((e) => Problem.fromJson(e)).toList();
  }

  String _progressKey(String? userId) =>
      'mins_progress_v2_${userId ?? 'guest'}';

  String _prefsKey(String? userId) =>
      'mins_preferences_v2_${userId ?? 'guest'}';

  String _syncQueueKey(String userId) => 'mins_sync_queue_v1_$userId';

  String _motivationKey(String? userId) =>
      'mins_motivation_v1_${userId ?? 'guest'}';

  String _sessionKey(String? userId) => 'mins_session_v1_${userId ?? 'guest'}';

  Future<Map<String, ProblemProgress>> loadProgress(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_progressKey(userId));

    if (raw == null) return {};

    final map = jsonDecode(raw) as Map<String, dynamic>;

    return map.map((key, value) {
      final v = value as Map<String, dynamic>;

      return MapEntry(
        key,
        ProblemProgress(
          completed: v['completed'] == true,
          completedAt: v['completedAt'] == null
              ? null
              : DateTime.tryParse(v['completedAt']),
          notes: v['notes'] ?? '',
          reviewDueAt: v['reviewDueAt'] == null
              ? null
              : DateTime.tryParse(v['reviewDueAt']),
          lastReviewedAt: v['lastReviewedAt'] == null
              ? null
              : DateTime.tryParse(v['lastReviewedAt']),
        ),
      );
    });
  }

  Future<void> saveProgress(
    String? userId,
    Map<String, ProblemProgress> progress,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final payload = progress.map(
      (key, value) => MapEntry(
        key,
        {
          'completed': value.completed,
          'completedAt': value.completedAt?.toIso8601String(),
          'notes': value.notes,
          'reviewDueAt': value.reviewDueAt?.toIso8601String(),
          'lastReviewedAt': value.lastReviewedAt?.toIso8601String(),
        },
      ),
    );

    await prefs.setString(
      _progressKey(userId),
      jsonEncode(payload),
    );
  }

  // ---------------------------------------------------------------------------
  // OFFLINE SYNC QUEUE
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> loadSyncQueue(
    String userId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_syncQueueKey(userId));

    if (raw == null) return [];

    final decoded = jsonDecode(raw);

    if (decoded is! List) return [];

    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> saveSyncQueue(
    String userId,
    List<Map<String, dynamic>> queue,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _syncQueueKey(userId),
      jsonEncode(queue),
    );
  }

  Future<void> enqueueSync(
    String userId,
    String problemId,
    ProblemProgress progress,
  ) async {
    final queue = await loadSyncQueue(userId);

    final operation = {
      'problemId': problemId,
      'completed': progress.completed,
      'completedAt': progress.completedAt?.toIso8601String(),
      'notes': progress.notes,
      'reviewDueAt': progress.reviewDueAt?.toIso8601String(),
      'lastReviewedAt': progress.lastReviewedAt?.toIso8601String(),
      'queuedAt': DateTime.now().toIso8601String(),
    };

    // If the same problem is already queued, replace its older operation.
    // We only need the latest state for a given problem.
    queue.removeWhere(
      (item) => item['problemId'] == problemId,
    );

    queue.add(operation);

    await saveSyncQueue(userId, queue);
  }

  Future<void> removeSyncOperation(
    String userId,
    String problemId,
  ) async {
    final queue = await loadSyncQueue(userId);

    queue.removeWhere(
      (item) => item['problemId'] == problemId,
    );

    await saveSyncQueue(userId, queue);
  }

  Future<void> clearSyncQueue(String userId) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_syncQueueKey(userId));
  }

  Future<Map<String, dynamic>> loadPrefs(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey(userId));

    return raw == null ? {} : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> savePrefs(
    String? userId,
    Map<String, dynamic> value,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _prefsKey(userId),
      jsonEncode(value),
    );
  }

  // ---------------------------------------------------------------------------
  // MOTIVATION TRACKING
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> loadMotivationState(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_motivationKey(userId));

    return raw == null ? {} : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveMotivationState(
    String? userId,
    Map<String, dynamic> state,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _motivationKey(userId),
      jsonEncode(state),
    );
  }

  Future<bool> shouldShowMotivation(
    String? userId,
    String eventType,
  ) async {
    final state = await loadMotivationState(userId);

    final lastDate = state['lastDate'] as String?;
    final todayKey = _todayKey();

    if (lastDate != todayKey) {
      return true;
    }

    final dailyCount = state['dailyCount'] as int? ?? 0;
    if (dailyCount >= 3) {
      return false;
    }

    final lastEventTypes = state['lastEventTypes'] as List<dynamic>? ?? [];
    if (lastEventTypes.contains(eventType)) {
      return false;
    }

    return true;
  }

  Future<void> recordMotivationShown(
    String? userId,
    String eventType,
  ) async {
    final state = await loadMotivationState(userId);
    final todayKey = _todayKey();

    final lastDate = state['lastDate'] as String?;
    final dailyCount =
        (lastDate == todayKey ? (state['dailyCount'] as int? ?? 0) : 0) + 1;

    final lastEventTypes = (lastDate == todayKey
        ? (state['lastEventTypes'] as List<dynamic>? ?? [])
        : <dynamic>[])
      ..add(eventType);

    final updatedState = <String, dynamic>{
      'lastDate': todayKey,
      'dailyCount': dailyCount,
      'lastEventTypes': lastEventTypes,
    };

    await saveMotivationState(userId, updatedState);
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  // ---------------------------------------------------------------------------
  // SESSION TRACKING
  // ---------------------------------------------------------------------------

  static const _sessionInactivityMinutes = 120;

  Future<Map<String, dynamic>> loadSessionState(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey(userId));

    return raw == null ? {} : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> saveSessionState(
    String? userId,
    Map<String, dynamic> state,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _sessionKey(userId),
      jsonEncode(state),
    );
  }

  Future<int> getSessionCompletedCount(String? userId) async {
    final state = await loadSessionState(userId);
    final lastActivity = state['lastActivity'] as String?;

    if (lastActivity == null) {
      return 0;
    }

    final lastActivityTime = DateTime.parse(lastActivity);
    final now = DateTime.now();

    // Reset session if inactive for too long
    if (now.difference(lastActivityTime).inMinutes >=
        _sessionInactivityMinutes) {
      await saveSessionState(userId, {});
      return 0;
    }

    return state['completedCount'] as int? ?? 0;
  }

  Future<void> incrementSessionCompleted(String? userId) async {
    final state = await loadSessionState(userId);
    final lastActivity = state['lastActivity'] as String?;

    final now = DateTime.now();

    // Reset session if inactive for too long
    if (lastActivity != null) {
      final lastActivityTime = DateTime.parse(lastActivity);
      if (now.difference(lastActivityTime).inMinutes >=
          _sessionInactivityMinutes) {
        await saveSessionState(userId, {
          'lastActivity': now.toIso8601String(),
          'completedCount': 1,
        });
        return;
      }
    }

    final completedCount = (state['completedCount'] as int? ?? 0) + 1;

    await saveSessionState(userId, {
      'lastActivity': now.toIso8601String(),
      'completedCount': completedCount,
    });
  }
}
