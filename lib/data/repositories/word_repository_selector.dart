import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/word_repository.dart';
import 'word_repository_sqlite.dart';
import 'word_repository_supabase.dart';

enum DbType { sqlite, supabase }

final dbTypeProvider = StateProvider<DbType>((ref) => DbType.sqlite);

final wordRepositoryProvider = Provider<WordRepository>((ref) {
  final dbType = ref.watch(dbTypeProvider);
  switch (dbType) {
    case DbType.supabase:
      return WordRepositorySupabase();
    case DbType.sqlite:
    default:
      return WordRepositorySQLite();
  }
});
