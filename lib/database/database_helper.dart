import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:novel_reader/models/book.dart';
import 'package:novel_reader/models/chapter.dart';
import 'package:novel_reader/models/rule.dart';
import 'package:novel_reader/models/reading_progress.dart';

class DatabaseHelper {
  static const _dbName = 'novel_reader.db';
  static const _version = 1;
  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb(test: false);
    return _db!;
  }

  Future<void> init({bool test = false}) async {
    _db = await _initDb(test: test);
  }

  Future<Database> _initDb({required bool test}) async {
    if (test) {
      final path = await getDatabasesPath();
      return openDatabase(
        p.join(path, 'test_novel_reader.db'),
        version: _version,
        onCreate: _onCreate,
      );
    }
    return openDatabase(
      p.join(await getDatabasesPath(), _dbName),
      version: _version,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT,
        cover_url TEXT,
        description TEXT,
        source_url TEXT NOT NULL,
        rule_name TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE chapters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        url TEXT NOT NULL,
        "index" INTEGER NOT NULL,
        content TEXT,
        UNIQUE(book_id, url)
      )
    ''');
    await db.execute('''
      CREATE TABLE reading_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL UNIQUE REFERENCES books(id) ON DELETE CASCADE,
        chapter_index INTEGER NOT NULL,
        scroll_offset REAL DEFAULT 0.0,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        config TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('PRAGMA foreign_keys = ON');
  }

  // --- Books ---

  Future<int> insertBook(Book book) async {
    final db = await database;
    return db.insert('books', book.toMap());
  }

  Future<List<Book>> getBooks() async {
    final db = await database;
    final maps = await db.query('books', orderBy: 'created_at DESC');
    return maps.map(Book.fromMap).toList();
  }

  Future<Book?> getBook(int id) async {
    final db = await database;
    final maps = await db.query('books', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Book.fromMap(maps.first);
  }

  Future<int> deleteBook(int id) async {
    final db = await database;
    await db.delete('chapters', where: 'book_id = ?', whereArgs: [id]);
    return db.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  // --- Chapters ---

  Future<void> insertChapters(List<Chapter> chapters) async {
    final db = await database;
    final batch = db.batch();
    for (final ch in chapters) {
      batch.insert('chapters', ch.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Chapter>> getChapters(int bookId) async {
    final db = await database;
    final maps = await db.query(
      'chapters',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: '"index" ASC',
    );
    return maps.map(Chapter.fromMap).toList();
  }

  Future<void> updateChapterContent(int chapterId, String content) async {
    final db = await database;
    await db.update(
      'chapters',
      {'content': content},
      where: 'id = ?',
      whereArgs: [chapterId],
    );
  }

  // --- Progress ---

  Future<void> saveProgress(ReadingProgress progress) async {
    final db = await database;
    await db.insert(
      'reading_progress',
      progress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ReadingProgress?> getProgress(int bookId) async {
    final db = await database;
    final maps = await db.query(
      'reading_progress',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    if (maps.isEmpty) return null;
    return ReadingProgress.fromMap(maps.first);
  }

  // --- Rules ---

  Future<int> insertRule(Rule rule) async {
    final db = await database;
    return db.insert('rules', rule.toMap());
  }

  Future<List<Rule>> getRules() async {
    final db = await database;
    final maps = await db.query('rules', orderBy: 'updated_at DESC');
    return maps.map(Rule.fromMap).toList();
  }

  Future<Rule?> getRule(int id) async {
    final db = await database;
    final maps = await db.query('rules', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Rule.fromMap(maps.first);
  }

  Future<int> updateRule(Rule rule) async {
    final db = await database;
    return db.update('rules', rule.toMap(),
        where: 'id = ?', whereArgs: [rule.id]);
  }

  Future<int> deleteRule(int id) async {
    final db = await database;
    return db.delete('rules', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
