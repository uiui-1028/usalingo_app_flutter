import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/learning_progress.dart';
import '../../app/app.dart';

/// Supabase用の学習進捗データソース
class LearningProgressSupabaseDataSource {
  final SupabaseClient _client = SupabaseInitializer.client;

  /// 特定の単語の学習進捗を取得
  Future<LearningProgress?> getLearningProgress(int wordId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final response = await _client
          .from('user_learning_progress')
          .select()
          .eq('user_id', user.id)
          .eq('word_id', wordId)
          .single();

      if (response == null) return null;

      return LearningProgress(
        wordId: response['word_id'] as int,
        status: response['status'] as String? ?? 'new',
        lastReviewedAt: response['last_reviewed_at'] != null
            ? DateTime.tryParse(response['last_reviewed_at'])
            : null,
        nextReviewDate: response['next_review_date'] != null
            ? DateTime.tryParse(response['next_review_date'])
            : null,
        srsLevel: response['srs_level'] as int? ?? 1,
        easinessFactor:
            (response['easiness_factor'] as num?)?.toDouble() ?? 2.5,
        repetitions: response['repetitions'] as int? ?? 0,
        intervalDays: response['interval_days'] as int? ?? 0,
      );
    } catch (e) {
      // データが見つからない場合はnullを返す
      return null;
    }
  }

  /// 今日復習すべき学習進捗を取得
  Future<List<LearningProgress>> getDueTodayProgress() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final today = DateTime.now();
      final response = await _client
          .from('user_learning_progress')
          .select()
          .eq('user_id', user.id)
          .lte('next_review_date', today.toIso8601String())
          .order('next_review_date', ascending: true);

      return (response as List)
          .map(
            (data) => LearningProgress(
              wordId: data['word_id'] as int,
              status: data['status'] as String? ?? 'new',
              lastReviewedAt: data['last_reviewed_at'] != null
                  ? DateTime.tryParse(data['last_reviewed_at'])
                  : null,
              nextReviewDate: data['next_review_date'] != null
                  ? DateTime.tryParse(data['next_review_date'])
                  : null,
              srsLevel: data['srs_level'] as int? ?? 1,
              easinessFactor:
                  (data['easiness_factor'] as num?)?.toDouble() ?? 2.5,
              repetitions: data['repetitions'] as int? ?? 0,
              intervalDays: data['interval_days'] as int? ?? 0,
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 全ての学習進捗を取得
  Future<List<LearningProgress>> getAllLearningProgress() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final response = await _client
          .from('user_learning_progress')
          .select()
          .eq('user_id', user.id)
          .order('word_id', ascending: true);

      return (response as List)
          .map(
            (data) => LearningProgress(
              wordId: data['word_id'] as int,
              status: data['status'] as String? ?? 'new',
              lastReviewedAt: data['last_reviewed_at'] != null
                  ? DateTime.tryParse(data['last_reviewed_at'])
                  : null,
              nextReviewDate: data['next_review_date'] != null
                  ? DateTime.tryParse(data['next_review_date'])
                  : null,
              srsLevel: data['srs_level'] as int? ?? 1,
              easinessFactor:
                  (data['easiness_factor'] as num?)?.toDouble() ?? 2.5,
              repetitions: data['repetitions'] as int? ?? 0,
              intervalDays: data['interval_days'] as int? ?? 0,
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 学習進捗を保存
  Future<void> saveLearningProgress(LearningProgress progress) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _client.from('user_learning_progress').upsert({
        'user_id': user.id,
        'word_id': progress.wordId,
        'status': progress.status,
        'last_reviewed_at': progress.lastReviewedAt?.toIso8601String(),
        'next_review_date': progress.nextReviewDate?.toIso8601String(),
        'srs_level': progress.srsLevel,
        'easiness_factor': progress.easinessFactor,
        'repetitions': progress.repetitions,
        'interval_days': progress.intervalDays,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // エラーハンドリング
      rethrow;
    }
  }

  /// 特定の単語の学習進捗を削除
  Future<void> deleteLearningProgress(int wordId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _client
          .from('user_learning_progress')
          .delete()
          .eq('user_id', user.id)
          .eq('word_id', wordId);
    } catch (e) {
      // エラーハンドリング
      rethrow;
    }
  }

  /// 全ての学習進捗を削除
  Future<void> deleteAllLearningProgress() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return;

      await _client
          .from('user_learning_progress')
          .delete()
          .eq('user_id', user.id);
    } catch (e) {
      // エラーハンドリング
      rethrow;
    }
  }
}
