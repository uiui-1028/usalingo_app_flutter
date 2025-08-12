import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/learning_progress_repository_impl.dart';
import '../data/repositories/word_repository_sqlite.dart';
import '../data/repositories/word_repository_supabase.dart';
import '../data/repositories/word_repository_selector.dart';
import '../data/datasources/learning_progress_datasource.dart';
import '../data/datasources/local_word_datasource.dart';
import '../domain/repositories/learning_progress_repository.dart';
import '../domain/repositories/word_repository.dart';
import '../domain/entities/word.dart';
import '../domain/usecases/get_due_today_cards.dart';
import '../domain/usecases/get_learning_progress.dart';
import '../domain/usecases/get_next_word.dart';
import '../domain/usecases/mark_card_result.dart';

// データソースプロバイダー
final learningProgressDataSourceProvider = Provider<LearningProgressDataSource>(
  (ref) {
    return LearningProgressSupabaseDataSource();
  },
);

final localWordDataSourceProvider = Provider<LocalWordDataSource>((ref) {
  return LocalWordSQLiteDataSource();
});

// リポジトリプロバイダー
final learningProgressRepositoryProvider = Provider<LearningProgressRepository>(
  (ref) {
    final dataSource = ref.watch(learningProgressDataSourceProvider);
    return LearningProgressRepositoryImpl(dataSource);
  },
);

final wordRepositoryProvider = Provider<WordRepository>((ref) {
  // 現在はSQLiteリポジトリを使用（後で選択ロジックを実装）
  return WordRepositorySQLite();
});

final wordRepositorySupabaseProvider = Provider<WordRepository>((ref) {
  return WordRepositorySupabase();
});

final wordRepositorySQLiteProvider = Provider<WordRepository>((ref) {
  return WordRepositorySQLite();
});

// リポジトリ選択プロバイダー
final wordRepositorySelectorProvider = Provider<WordRepositorySelector>((ref) {
  return WordRepositorySelector();
});

// ユースケースプロバイダー
final getDueTodayCardsProvider = Provider<GetDueTodayCards>((ref) {
  final repository = ref.watch(learningProgressRepositoryProvider);
  return GetDueTodayCards(repository);
});

final getLearningProgressProvider = Provider<GetLearningProgress>((ref) {
  final repository = ref.watch(learningProgressRepositoryProvider);
  return GetLearningProgress(repository);
});

final getNextWordProvider = Provider<GetNextWord>((ref) {
  final repository = ref.watch(wordRepositoryProvider);
  return GetNextWord(repository);
});

final markCardResultProvider = Provider<MarkCardResult>((ref) {
  final repository = ref.watch(learningProgressRepositoryProvider);
  return MarkCardResult(repository);
});

// 単語リストプロバイダー
final wordListProvider = FutureProvider<List<Word>>((ref) async {
  final repository = ref.watch(wordRepositoryProvider);
  return await repository.fetchAllWords();
});

// データベースタイププロバイダー
final dbTypeProvider = StateProvider<DbType>((ref) {
  return DbType.sqlite;
});

// データベースタイプの列挙型
enum DbType { sqlite, supabase }

// アプリケーション状態プロバイダー
final appStateProvider = StateProvider<AppState>((ref) {
  return AppState.initial;
});

// アプリケーション状態の列挙型
enum AppState { initial, loading, authenticated, unauthenticated, error }

// ユーザー認証状態プロバイダー
final userAuthStateProvider = StateProvider<UserAuthState>((ref) {
  return UserAuthState.unknown;
});

// ユーザー認証状態の列挙型
enum UserAuthState { unknown, authenticated, unauthenticated, guest }

// ネットワーク接続状態プロバイダー
final networkConnectionProvider = StateProvider<bool>((ref) {
  return true; // デフォルトは接続済み
});

// 学習セッション状態プロバイダー
final learningSessionProvider = StateProvider<LearningSessionState>((ref) {
  return LearningSessionState.idle;
});

// 学習セッション状態の列挙型
enum LearningSessionState { idle, active, paused, completed, error }
