import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/word.dart';
import '../../domain/repositories/word_repository.dart';
import '../../app/app.dart';

class WordRepositorySupabase implements WordRepository {
  final SupabaseClient _client = SupabaseInitializer.client;

  @override
  Future<List<Word>> fetchAllWords() async {
    final response = await _client
        .from('words')
        .select()
        .order('id', ascending: true);
    return (response as List)
        .map(
          (m) => Word(
            id: m['id'] as int?,
            text: m['word_text'] as String,
            meaning: m['definition'] as String? ?? '',
            sentence: null, // example_contentsテーブルから取得
            imageUrl: null, // example_contentsテーブルから取得
            tags: m['part_of_speech'] as String?,
            createdAt: m['created_at'] != null
                ? DateTime.tryParse(m['created_at'])
                : null,
            isLearned: false, // user_learning_progressテーブルから取得
            reviewCount: 0, // user_learning_progressテーブルから取得
            lastReviewedAt: null, // user_learning_progressテーブルから取得
          ),
        )
        .toList();
  }

  @override
  Future<Word?> fetchWordById(int id) async {
    // TODO: 実装
    return null;
  }

  @override
  Future<int> insertWord(Word word) async {
    // TODO: 実装
    return 0;
  }

  @override
  Future<int> updateWord(Word word) async {
    // TODO: 実装
    return 0;
  }

  @override
  Future<int> deleteWord(int id) async {
    // TODO: 実装
    return 0;
  }

  @override
  Future<void> resetLearningProgress() async {
    await _client.from('words').update({
      'is_learned': false,
      'review_count': 0,
      'last_reviewed_at': null,
    });
  }
}
