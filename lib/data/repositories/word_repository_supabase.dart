import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/word.dart';
import '../../domain/repositories/word_repository.dart';
import '../../secrets.dart';

class WordRepositorySupabase implements WordRepository {
  final SupabaseClient _client = SupabaseClient(supabaseUrl, supabaseAnonKey);

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
            text: m['text'] as String,
            meaning: m['meaning'] as String,
            sentence: m['sentence'] as String?,
            imageUrl: m['image_url'] as String?,
            tags: m['tags'] as String? ?? m['tug'] as String?, // ←両方対応
            createdAt: m['created_at'] != null
                ? DateTime.tryParse(m['created_at'])
                : null,
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
}
