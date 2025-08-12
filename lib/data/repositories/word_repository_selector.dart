import '../../domain/repositories/word_repository.dart';
import 'word_repository_sqlite.dart';
import 'word_repository_supabase.dart';

// リポジトリ選択ロジッククラス
class WordRepositorySelector {
  // 現在の接続状態に基づいて適切なリポジトリを選択
  static WordRepository selectRepository({
    required bool isOnline,
    required bool useLocalFirst,
  }) {
    if (useLocalFirst || !isOnline) {
      // オフライン時またはローカル優先設定時はSQLiteリポジトリを使用
      return WordRepositorySQLite();
    } else {
      // オンライン時はSupabaseリポジトリを使用
      return WordRepositorySupabase();
    }
  }

  // ネットワーク状態の監視とリポジトリの自動切り替え
  static WordRepository getRepositoryForCurrentState({
    required bool hasInternetConnection,
    required bool isUserAuthenticated,
    required bool preferLocalData,
  }) {
    // ユーザーが認証されていない場合はローカルリポジトリを使用
    if (!isUserAuthenticated) {
      return WordRepositorySQLite();
    }

    // インターネット接続がない場合はローカルリポジトリを使用
    if (!hasInternetConnection) {
      return WordRepositorySQLite();
    }

    // ローカルデータを優先する設定の場合はSQLiteリポジトリを使用
    if (preferLocalData) {
      return WordRepositorySQLite();
    }

    // それ以外の場合はSupabaseリポジトリを使用
    return WordRepositorySupabase();
  }
}
