import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/entities/learning_progress.dart';

/// 学習進捗データのSQLiteデータベース操作を担当するデータソース
class LearningProgressDataSource {
  static Database? _database;
  static const String _tableName = 'learning_progress';

  /// データベースインスタンスを取得（シングルトンパターン）
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// データベースの初期化
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'usalingo_learning_progress.db');

    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  /// テーブル作成
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        word_id INTEGER PRIMARY KEY,
        srs_level INTEGER NOT NULL,
        next_review_date TEXT NOT NULL
      )
    ''');
  }

  /// 学習進捗を保存または更新
  Future<void> saveLearningProgress(LearningProgress progress) async {
    final db = await database;
    await db.insert(_tableName, {
      'word_id': progress.wordId,
      'srs_level': progress.srsLevel,
      'next_review_date': progress.nextReviewDate.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 指定された単語IDの学習進捗を取得
  Future<LearningProgress?> getLearningProgress(int wordId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'word_id = ?',
      whereArgs: [wordId],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    return LearningProgress(
      wordId: map['word_id'],
      srsLevel: map['srs_level'],
      nextReviewDate: DateTime.parse(map['next_review_date']),
    );
  }

  /// 今日復習すべき学習進捗一覧を取得
  Future<List<LearningProgress>> getDueTodayProgress() async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayString = today.toIso8601String();

    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'next_review_date <= ?',
      whereArgs: [todayString],
    );

    return maps
        .map(
          (map) => LearningProgress(
            wordId: map['word_id'],
            srsLevel: map['srs_level'],
            nextReviewDate: DateTime.parse(map['next_review_date']),
          ),
        )
        .toList();
  }

  /// すべての学習進捗を取得
  Future<List<LearningProgress>> getAllLearningProgress() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName);

    return maps
        .map(
          (map) => LearningProgress(
            wordId: map['word_id'],
            srsLevel: map['srs_level'],
            nextReviewDate: DateTime.parse(map['next_review_date']),
          ),
        )
        .toList();
  }

  /// 指定された単語IDの学習進捗を削除
  Future<void> deleteLearningProgress(int wordId) async {
    final db = await database;
    await db.delete(_tableName, where: 'word_id = ?', whereArgs: [wordId]);
  }

  /// すべての学習進捗を削除
  Future<void> deleteAllLearningProgress() async {
    final db = await database;
    await db.delete(_tableName);
  }

  /// データベースを閉じる
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
