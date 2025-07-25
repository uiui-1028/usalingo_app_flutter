import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../domain/entities/word.dart';
import '../../domain/repositories/word_repository.dart';
import '../datasources/sqlite_schema.dart';

class WordRepositorySQLite implements WordRepository {
  static const _dbName = 'words.db';
  static const _dbVersion = 1;
  static const _table = 'words';
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute(createWordsTable);
        await _insertSampleData(db);
      },
    );
  }

  Future<void> _insertSampleData(Database db) async {
    await db.insert(_table, {
      'text': 'apple',
      'meaning': 'りんご',
      'sentence': 'I eat an apple every morning.',
      'image_url': '',
      'tags': 'fruit,food',
    });
    await db.insert(_table, {
      'text': 'cat',
      'meaning': 'ねこ',
      'sentence': 'The cat is sleeping on the sofa.',
      'image_url': '',
      'tags': 'animal,pets',
    });
  }

  @override
  Future<List<Word>> fetchAllWords() async {
    final db = await database;
    final maps = await db.query(_table, orderBy: 'id ASC');
    return maps.map((m) => _fromMap(m)).toList();
  }

  @override
  Future<Word?> fetchWordById(int id) async {
    final db = await database;
    final maps = await db.query(_table, where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return _fromMap(maps.first);
  }

  @override
  Future<int> insertWord(Word word) async {
    final db = await database;
    return await db.insert(_table, _toMap(word));
  }

  @override
  Future<int> updateWord(Word word) async {
    final db = await database;
    return await db.update(
      _table,
      _toMap(word),
      where: 'id = ?',
      whereArgs: [word.id],
    );
  }

  @override
  Future<int> deleteWord(int id) async {
    final db = await database;
    return await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Word _fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as int?,
      text: map['text'] as String,
      meaning: map['meaning'] as String,
      sentence: map['sentence'] as String?,
      imageUrl: map['image_url'] as String?,
      tags: map['tags'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'])
          : null,
    );
  }

  Map<String, dynamic> _toMap(Word word) {
    return {
      'id': word.id,
      'text': word.text,
      'meaning': word.meaning,
      'sentence': word.sentence,
      'image_url': word.imageUrl,
      'tags': word.tags,
      'created_at': word.createdAt?.toIso8601String(),
    };
  }
}
