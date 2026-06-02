# 小说阅读器 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个 Flutter 安卓小说阅读器，通过 JSON 规则动态适配网站，支持章节模式和翻页模式。

**Architecture:** Riverpod 状态管理 + dio 网络层 + dart html 解析层 + sqflite 本地存储。核心引擎（RuleEngine + ContentFetcher）作为纯 Dart 模块独立于 UI，通过 Riverpod Provider 连接到 6 个页面。

**Tech Stack:** Flutter 3.x, Dart 3.x, Riverpod 2.x, dio 5.x, html 0.15.x, sqflite 2.x, go_router 13.x, gbk_codec 0.4.x

---

### Task 1: Flutter 项目初始化

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/main.dart`

- [ ] **Step 1: 创建 Flutter 项目**

```bash
cd D:/workspace-latest/novel-transfer
flutter create --org com.novel --project-name novel_reader .
```

- [ ] **Step 2: 编辑 pubspec.yaml，添加所有依赖**

在 `pubspec.yaml` 的 `dependencies` 区块中加入：

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.6
  flutter_riverpod: ^2.4.9
  dio: ^5.4.0
  html: ^0.15.4
  sqflite: ^2.3.0
  path_provider: ^2.1.1
  go_router: ^13.0.0
  gbk_codec: ^0.4.0
```

在 `dev_dependencies` 区块中加入：

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
  sqflite_common_ffi: ^2.3.0
```

- [ ] **Step 3: 安装依赖**

```bash
flutter pub get
```

- [ ] **Step 4: 验证项目可运行**

```bash
flutter analyze
```

预期：无错误输出。

- [ ] **Step 5: 写入最小 main.dart**

```dart
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NovelReaderApp());
}

class NovelReaderApp extends StatelessWidget {
  const NovelReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Novel Reader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(child: Text('Novel Reader')),
      ),
    );
  }
}
```

- [ ] **Step 6: Commit**

```bash
git init
git add -A
git commit -m "chore: initialize flutter project with dependencies"
```

---

### Task 2: 数据模型 Models

**Files:**
- Create: `lib/models/book.dart`
- Create: `lib/models/chapter.dart`
- Create: `lib/models/rule.dart`
- Create: `lib/models/reading_progress.dart`
- Create: `test/models/book_test.dart`

- [ ] **Step 1: 写 Book 模型测试**

```dart
// test/models/book_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader/models/book.dart';

void main() {
  test('Book fromMap and toMap roundtrip', () {
    final map = {
      'id': 1,
      'title': '测试小说',
      'author': '作者名',
      'cover_url': 'https://example.com/cover.jpg',
      'description': '一本好书',
      'source_url': 'https://example.com/book/1',
      'rule_name': 'test_rule',
      'created_at': 1717334400,
    };
    final book = Book.fromMap(map);
    expect(book.id, 1);
    expect(book.title, '测试小说');
    expect(book.toMap(), map);
  });

  test('Book fromMap with null id', () {
    final map = {
      'title': '新书',
      'author': null,
      'cover_url': null,
      'description': null,
      'source_url': 'https://example.com/book/2',
      'rule_name': 'test_rule',
      'created_at': 1717334400,
    };
    final book = Book.fromMap(map);
    expect(book.id, isNull);
    expect(book.author, isNull);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/models/book_test.dart
```

预期：FAIL，Book 类未定义。

- [ ] **Step 3: 实现 Book 模型**

```dart
// lib/models/book.dart
class Book {
  final int? id;
  final String title;
  final String? author;
  final String? coverUrl;
  final String? description;
  final String sourceUrl;
  final String ruleName;
  final int createdAt;

  const Book({
    this.id,
    required this.title,
    this.author,
    this.coverUrl,
    this.description,
    required this.sourceUrl,
    required this.ruleName,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'author': author,
        'cover_url': coverUrl,
        'description': description,
        'source_url': sourceUrl,
        'rule_name': ruleName,
        'created_at': createdAt,
      };

  factory Book.fromMap(Map<String, dynamic> map) => Book(
        id: map['id'] as int?,
        title: map['title'] as String,
        author: map['author'] as String?,
        coverUrl: map['cover_url'] as String?,
        description: map['description'] as String?,
        sourceUrl: map['source_url'] as String,
        ruleName: map['rule_name'] as String,
        createdAt: map['created_at'] as int,
      );

  Book copyWith({
    int? id,
    String? title,
    String? author,
    String? coverUrl,
    String? description,
    String? sourceUrl,
    String? ruleName,
    int? createdAt,
  }) =>
      Book(
        id: id ?? this.id,
        title: title ?? this.title,
        author: author ?? this.author,
        coverUrl: coverUrl ?? this.coverUrl,
        description: description ?? this.description,
        sourceUrl: sourceUrl ?? this.sourceUrl,
        ruleName: ruleName ?? this.ruleName,
        createdAt: createdAt ?? this.createdAt,
      );
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
flutter test test/models/book_test.dart
```

- [ ] **Step 5: 实现 Chapter、Rule、ReadingProgress 模型**

```dart
// lib/models/chapter.dart
class Chapter {
  final int? id;
  final int bookId;
  final String title;
  final String url;
  final int index;
  final String? content;

  const Chapter({
    this.id,
    required this.bookId,
    required this.title,
    required this.url,
    required this.index,
    this.content,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'book_id': bookId,
        'title': title,
        'url': url,
        'index': index,
        'content': content,
      };

  factory Chapter.fromMap(Map<String, dynamic> map) => Chapter(
        id: map['id'] as int?,
        bookId: map['book_id'] as int,
        title: map['title'] as String,
        url: map['url'] as String,
        index: map['index'] as int,
        content: map['content'] as String?,
      );
}
```

```dart
// lib/models/rule.dart
class Rule {
  final int? id;
  final String name;
  final String config;
  final int updatedAt;

  const Rule({
    this.id,
    required this.name,
    required this.config,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'config': config,
        'updated_at': updatedAt,
      };

  factory Rule.fromMap(Map<String, dynamic> map) => Rule(
        id: map['id'] as int?,
        name: map['name'] as String,
        config: map['config'] as String,
        updatedAt: map['updated_at'] as int,
      );
}
```

```dart
// lib/models/reading_progress.dart
class ReadingProgress {
  final int? id;
  final int bookId;
  final int chapterIndex;
  final double scrollOffset;
  final int updatedAt;

  const ReadingProgress({
    this.id,
    required this.bookId,
    required this.chapterIndex,
    this.scrollOffset = 0.0,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'book_id': bookId,
        'chapter_index': chapterIndex,
        'scroll_offset': scrollOffset,
        'updated_at': updatedAt,
      };

  factory ReadingProgress.fromMap(Map<String, dynamic> map) =>
      ReadingProgress(
        id: map['id'] as int?,
        bookId: map['book_id'] as int,
        chapterIndex: map['chapter_index'] as int,
        scrollOffset: (map['scroll_offset'] as num?)?.toDouble() ?? 0.0,
        updatedAt: map['updated_at'] as int,
      );
}
```

- [ ] **Step 6: Commit**

```bash
git add lib/models/ test/models/
git commit -m "feat: add data models (Book, Chapter, Rule, ReadingProgress)"
```

---

### Task 3: 数据库 DatabaseHelper

**Files:**
- Create: `lib/database/database_helper.dart`
- Create: `test/database/database_helper_test.dart`

- [ ] **Step 1: 写数据库测试**

```dart
// test/database/database_helper_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:novel_reader/database/database_helper.dart';
import 'package:novel_reader/models/book.dart';
import 'package:novel_reader/models/rule.dart';
import 'package:novel_reader/models/chapter.dart';
import 'package:novel_reader/models/reading_progress.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper db;

  setUp(() async {
    db = DatabaseHelper();
    await db.init(test: true);
  });

  tearDown(() async {
    await db.close();
  });

  test('insert and get book', () async {
    final book = Book(
      title: '测试',
      sourceUrl: 'https://example.com/book/1',
      ruleName: 'test_rule',
      createdAt: 1717334400,
    );
    final id = await db.insertBook(book);
    expect(id, 1);

    final books = await db.getBooks();
    expect(books.length, 1);
    expect(books.first.title, '测试');
  });

  test('insert and delete book cascades chapters', () async {
    final bookId = await db.insertBook(Book(
      title: 'X', sourceUrl: 'u', ruleName: 'r', createdAt: 1,
    ));
    await db.insertChapter(Chapter(
      bookId: bookId, title: 'Ch1', url: 'u1', index: 0,
    ));
    await db.deleteBook(bookId);
    final chapters = await db.getChapters(bookId);
    expect(chapters, isEmpty);
  });

  test('update reading progress', () async {
    final bookId = await db.insertBook(Book(
      title: 'X', sourceUrl: 'u', ruleName: 'r', createdAt: 1,
    ));
    await db.saveProgress(ReadingProgress(
      bookId: bookId, chapterIndex: 3, scrollOffset: 0.5, updatedAt: 1,
    ));
    final progress = await db.getProgress(bookId);
    expect(progress, isNotNull);
    expect(progress!.chapterIndex, 3);
  });

  test('insert and get rules', () async {
    final rule = Rule(name: 'test', config: '{}', updatedAt: 1);
    final id = await db.insertRule(rule);
    expect(id, 1);

    final rules = await db.getRules();
    expect(rules.length, 1);
    expect(rules.first.name, 'test');
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/database/database_helper_test.dart
```

- [ ] **Step 3: 实现 DatabaseHelper**

```dart
// lib/database/database_helper.dart
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
      return openDatabase(
        p.join(await getDatabasesPath(), 'test_novel_reader.db'),
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
    // Enable foreign keys
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
```

- [ ] **Step 4: 运行测试确认通过**

```bash
flutter test test/database/database_helper_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/database/ test/database/
git commit -m "feat: add DatabaseHelper with SQLite CRUD"
```

---

### Task 4: RuleEngine 规则解析引擎

**Files:**
- Create: `lib/engine/rule_engine.dart`
- Create: `test/engine/rule_engine_test.dart`

- [ ] **Step 1: 写 RuleEngine 测试**

```dart
// test/engine/rule_engine_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader/engine/rule_engine.dart';

void main() {
  late RuleEngine engine;
  setUp(() => engine = RuleEngine());

  final validChapterRule = '''
{
  "name": "test",
  "baseUrl": "https://example.com",
  "mode": "chapter",
  "book": {
    "title": ".book-title",
    "author": ".author",
    "cover": ".cover img @src",
    "description": ".desc"
  },
  "chapterList": {
    "url": ".chapters a @href",
    "container": ".chapter-list",
    "item": "li a",
    "title": "self::text",
    "href": "self::@href"
  },
  "content": {
    "title": ".chapter-title",
    "body": "#content",
    "nextPage": ".next @href",
    "filters": [".ad", "script"]
  }
}
''';

  final validScrollRule = '''
{
  "name": "scroll_test",
  "mode": "scroll",
  "content": {
    "title": ".page-title",
    "body": ".content",
    "nextPage": "a.next @href",
    "filters": [".comment"]
  }
}
''';

  test('parse valid chapter rule', () {
    final config = engine.parse(validChapterRule);
    expect(config.name, 'test');
    expect(config.baseUrl, 'https://example.com');
    expect(config.mode, 'chapter');
    expect(config.book?.title, '.book-title');
    expect(config.book?.cover, '.cover img');
    expect(config.book?.coverAttr, 'src');
    expect(config.chapterList?.url, '.chapters a');
    expect(config.chapterList?.urlAttr, 'href');
    expect(config.chapterList?.title, 'self::text');
    expect(config.chapterList?.href, 'self::@href');
    expect(config.content.title, '.chapter-title');
    expect(config.content.body, '#content');
    expect(config.content.nextPage, '.next');
    expect(config.content.nextPageAttr, 'href');
    expect(config.content.filters, ['.ad', 'script']);
  });

  test('parse valid scroll rule', () {
    final config = engine.parse(validScrollRule);
    expect(config.mode, 'scroll');
    expect(config.book, isNull);
    expect(config.chapterList, isNull);
  });

  test('validate returns empty string for valid rule', () {
    expect(engine.validate(validChapterRule), '');
    expect(engine.validate(validScrollRule), '');
  });

  test('validate returns error for invalid JSON', () {
    final error = engine.validate('{bad json}');
    expect(error, isNotEmpty);
    expect(error, contains('JSON'));
  });

  test('validate returns error for missing mode', () {
    final error = engine.validate('{"name":"x","content":{"body":"b"}}');
    expect(error, contains('mode'));
  });

  test('validate returns error for missing content.body', () {
    final error = engine.validate('{"name":"x","mode":"chapter","content":{}}');
    expect(error, contains('content.body'));
  });

  test('validate returns error for chapter mode missing chapterList', () {
    final error = engine.validate('''
{"name":"x","mode":"chapter","content":{"body":"b"}}
''');
    expect(error, contains('chapterList'));
  });

  test('parse extracts attribute selectors correctly', () {
    final config = engine.parse('''
{"name":"x","mode":"scroll","content":{"body":"div.content","filters":[]}}
''');
    expect(config.content.body, 'div.content');
    expect(config.content.bodyAttr, isNull);
  });

  test('parse resolves self::text and self::@attr', () {
    final config = engine.parse(validChapterRule);
    // title uses self::text (no attr extraction)
    expect(config.chapterList?.titleAttr, isNull);
    // href uses self::@href (attr extraction from self)
    expect(config.chapterList?.href, 'self::');
    expect(config.chapterList?.hrefAttr, 'href');
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/engine/rule_engine_test.dart
```

- [ ] **Step 3: 实现 RuleEngine**

```dart
// lib/engine/rule_engine.dart
import 'dart:convert';

class SelectorSpec {
  final String selector;
  final String? attr;

  const SelectorSpec({required this.selector, this.attr});
}

class BookSelectors {
  final SelectorSpec? title;
  final SelectorSpec? author;
  final SelectorSpec? cover;
  final SelectorSpec? description;

  const BookSelectors({this.title, this.author, this.cover, this.description});
}

class ChapterListSelectors {
  final SelectorSpec? url;
  final SelectorSpec container;
  final SelectorSpec item;
  final SelectorSpec title;
  final SelectorSpec href;

  const ChapterListSelectors({
    this.url,
    required this.container,
    required this.item,
    required this.title,
    required this.href,
  });
}

class ContentSelectors {
  final SelectorSpec? title;
  final SelectorSpec body;
  final SelectorSpec? nextPage;
  final List<String> filters;

  const ContentSelectors({
    this.title,
    required this.body,
    this.nextPage,
    this.filters = const [],
  });
}

class RuleConfig {
  final String name;
  final String? baseUrl;
  final String encoding;
  final String mode;
  final BookSelectors? book;
  final ChapterListSelectors? chapterList;
  final ContentSelectors content;

  const RuleConfig({
    required this.name,
    this.baseUrl,
    this.encoding = 'utf-8',
    required this.mode,
    this.book,
    this.chapterList,
    required this.content,
  });
}

class RuleEngine {
  /// Parse a CSS selector string, splitting off attribute if present.
  /// ".class @attr" -> SelectorSpec(selector: ".class", attr: "attr")
  /// "self::text" -> SelectorSpec(selector: "self::", attr: null, isText: true)
  /// "self::@href" -> SelectorSpec(selector: "self::", attr: "href")
  static SelectorSpec _parseSelector(String raw) {
    // Handle self:: cases first
    if (raw.startsWith('self::')) {
      final rest = raw.substring(6); // after "self::"
      if (rest.startsWith('@')) {
        return SelectorSpec(selector: 'self::', attr: rest.substring(1));
      }
      return const SelectorSpec(selector: 'self::');
    }
    // Normal CSS selector, check for @attr suffix
    final parts = raw.split(' @');
    if (parts.length == 2) {
      return SelectorSpec(selector: parts[0].trim(), attr: parts[1].trim());
    }
    return SelectorSpec(selector: raw.trim());
  }

  static SelectorSpec? _parseOptionalSelector(dynamic value) {
    if (value == null) return null;
    return _parseSelector(value as String);
  }

  static String _attrOrNull(SelectorSpec? s) => s?.attr ?? '';

  RuleConfig parse(String jsonString) {
    final map = json.decode(jsonString) as Map<String, dynamic>;
    final mode = map['mode'] as String? ?? 'chapter';

    BookSelectors? book;
    if (map['book'] != null) {
      final b = map['book'] as Map<String, dynamic>;
      book = BookSelectors(
        title: _parseOptionalSelector(b['title']),
        author: _parseOptionalSelector(b['author']),
        cover: _parseOptionalSelector(b['cover']),
        description: _parseOptionalSelector(b['description']),
      );
    }

    ChapterListSelectors? chapterList;
    if (map['chapterList'] != null) {
      final cl = map['chapterList'] as Map<String, dynamic>;
      chapterList = ChapterListSelectors(
        url: _parseOptionalSelector(cl['url']),
        container: _parseSelector(cl['container'] as String),
        item: _parseSelector(cl['item'] as String),
        title: _parseSelector(cl['title'] as String),
        href: _parseSelector(cl['href'] as String),
      );
    }

    final c = map['content'] as Map<String, dynamic>;
    final filters = (c['filters'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final content = ContentSelectors(
      title: _parseOptionalSelector(c['title']),
      body: _parseSelector(c['body'] as String),
      nextPage: _parseOptionalSelector(c['nextPage']),
      filters: filters,
    );

    return RuleConfig(
      name: map['name'] as String? ?? '',
      baseUrl: map['baseUrl'] as String?,
      encoding: map['encoding'] as String? ?? 'utf-8',
      mode: mode,
      book: book,
      chapterList: chapterList,
      content: content,
    );
  }

  /// Validate a rule JSON string. Returns empty string if valid,
  /// or an error message describing the problem.
  String validate(String jsonString) {
    Map<String, dynamic> map;
    try {
      map = json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return 'JSON 格式错误: $e';
    }

    if (!map.containsKey('mode') && !map.containsKey('name')) {
      return '缺少必填字段: mode, name';
    }
    if (!map.containsKey('mode')) {
      return '缺少必填字段: mode';
    }
    if (!map.containsKey('name')) {
      return '缺少必填字段: name';
    }

    final mode = map['mode'] as String?;
    if (mode != 'chapter' && mode != 'scroll') {
      return 'mode 必须是 "chapter" 或 "scroll"';
    }

    if (!map.containsKey('content')) {
      return '缺少必填字段: content';
    }
    final content = map['content'] as Map<String, dynamic>?;
    if (content == null || !content.containsKey('body')) {
      return '缺少必填字段: content.body';
    }

    if (mode == 'chapter' && !map.containsKey('chapterList')) {
      return '章节模式必须包含 chapterList';
    }

    return '';
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
flutter test test/engine/rule_engine_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/engine/ test/engine/
git commit -m "feat: add RuleEngine with JSON parsing and validation"
```

---

### Task 5: ContentFetcher 内容抓取器

**Files:**
- Create: `lib/engine/content_fetcher.dart`
- Create: `test/engine/content_fetcher_test.dart`

- [ ] **Step 1: 写 ContentFetcher 测试（用 mock HTML）**

```dart
// test/engine/content_fetcher_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_reader/engine/rule_engine.dart';
import 'package:novel_reader/engine/content_fetcher.dart';

void main() {
  late RuleEngine ruleEngine;
  late ContentFetcher fetcher;

  // Mock HTML for a book detail page
  final bookHtml = '''
<html>
<head><title>Test Book</title></head>
<body>
  <div class="book-info">
    <h1>斗破苍穹</h1>
    <span class="author">天蚕土豆</span>
    <img class="cover" src="/cover.jpg">
    <div class="desc">这是一个精彩的故事</div>
  </div>
  <div class="chapter-list">
    <ul>
      <li><a href="/ch1.html">第一章 开始</a></li>
      <li><a href="/ch2.html">第二章 冒险</a></li>
    </ul>
  </div>
  <div class="ad">广告内容</div>
</body>
</html>''';

  // Mock HTML for a chapter page
  final chapterHtml = '''
<html><body>
  <h1 class="chapter-title">第一章 开始</h1>
  <div id="content">
    <p>正文内容第一段</p>
    <p>正文内容第二段</p>
  </div>
  <div class="ad">广告</div>
  <a class="next-chapter" href="/ch2.html">下一章</a>
  <script>alert('xss')</script>
</body></html>''';

  setUp(() {
    ruleEngine = RuleEngine();
    fetcher = ContentFetcher();
  });

  test('extract book info from HTML', () {
    final rule = ruleEngine.parse('''
{
  "name": "test",
  "baseUrl": "https://example.com",
  "mode": "chapter",
  "book": {
    "title": ".book-info h1",
    "author": ".book-info .author",
    "cover": ".book-cover @src",
    "description": ".book-info .desc"
  },
  "chapterList": {
    "container": ".chapter-list",
    "item": "li a",
    "title": "self::text",
    "href": "self::@href"
  },
  "content": {
    "title": ".chapter-title",
    "body": "#content",
    "nextPage": ".next-chapter @href",
    "filters": [".ad", "script"]
  }
}
''');
    final doc = fetcher.parseHtml(bookHtml);

    expect(fetcher.extractText(doc, rule.book!.title!), '斗破苍穹');
    expect(fetcher.extractText(doc, rule.book!.author!), '天蚕土豆');
    expect(fetcher.extractAttr(doc, rule.book!.cover!), 'https://example.com/cover.jpg');
  });

  test('extract chapter list from HTML', () {
    final rule = ruleEngine.parse('''
{
  "name": "test",
  "baseUrl": "https://example.com",
  "mode": "chapter",
  "chapterList": {
    "container": ".chapter-list",
    "item": "li a",
    "title": "self::text",
    "href": "self::@href"
  },
  "content": {
    "body": "#content",
    "filters": []
  }
}
''');
    final doc = fetcher.parseHtml(bookHtml);
    final chapters = fetcher.extractChapterList(
      doc, rule.chapterList!, 'https://example.com',
    );

    expect(chapters.length, 2);
    expect(chapters[0].title, '第一章 开始');
    expect(chapters[0].url, 'https://example.com/ch1.html');
    expect(chapters[1].title, '第二章 冒险');
  });

  test('extract chapter content and apply filters', () {
    final rule = ruleEngine.parse('''
{
  "name": "test",
  "mode": "chapter",
  "content": {
    "title": ".chapter-title",
    "body": "#content",
    "nextPage": ".next-chapter @href",
    "filters": [".ad", "script"]
  }
}
''');
    final doc = fetcher.parseHtml(chapterHtml);

    expect(fetcher.extractText(doc, rule.content.title!), '第一章 开始');

    final body = fetcher.extractBody(doc, rule.content);
    expect(body, contains('正文内容第一段'));
    expect(body, contains('正文内容第二段'));
    expect(body, isNot(contains('广告')));
    expect(body, isNot(contains('alert')));

    // nextPage URL should be resolved
    final nextUrl = fetcher.extractAttr(doc, rule.content.nextPage!);
    expect(nextUrl, 'https://example.com/ch2.html');
  });

  test('resolve relative URLs', () {
    expect(
      ContentFetcher.resolveUrl('/path/page.html', 'https://example.com'),
      'https://example.com/path/page.html',
    );
    expect(
      ContentFetcher.resolveUrl('page.html', 'https://example.com/dir/'),
      'https://example.com/dir/page.html',
    );
    expect(
      ContentFetcher.resolveUrl('https://other.com/page', 'https://example.com'),
      'https://other.com/page',
    );
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
flutter test test/engine/content_fetcher_test.dart
```

- [ ] **Step 3: 实现 ContentFetcher**

```dart
// lib/engine/content_fetcher.dart
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:dio/dio.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'rule_engine.dart';

class ChapterInfo {
  final String title;
  final String url;
  const ChapterInfo({required this.title, required this.url});
}

class BookInfo {
  final String title;
  final String? author;
  final String? coverUrl;
  final String? description;
  final List<ChapterInfo> chapters;

  const BookInfo({
    required this.title,
    this.author,
    this.coverUrl,
    this.description,
    this.chapters = const [],
  });
}

class ContentFetcher {
  final Dio _dio;

  ContentFetcher()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36',
          },
        ));

  /// Parse HTML string into a DOM document
  dom.Document parseHtml(String html) => html_parser.parse(html);

  /// Extract text from the first element matching [spec]
  String? extractText(dom.Document doc, SelectorSpec spec) {
    if (spec.selector == 'self::') {
      return null; // self:: only makes sense in list context
    }
    final el = doc.querySelector(spec.selector);
    return el?.text.trim();
  }

  /// Extract attribute from the first element matching [spec]
  String? extractAttr(dom.Document doc, SelectorSpec spec, {String? baseUrl}) {
    final el = doc.querySelector(spec.selector);
    if (el == null) return null;
    final value = el.attributes[spec.attr ?? ''] ?? '';
    if (value.isEmpty) return null;
    return baseUrl != null ? resolveUrl(value, baseUrl) : value;
  }

  /// Extract chapter list from container > items
  List<ChapterInfo> extractChapterList(
    dom.Document doc,
    ChapterListSelectors selectors,
    String baseUrl,
  ) {
    final container = doc.querySelector(selectors.container.selector);
    if (container == null) return [];

    final items = container.querySelectorAll(selectors.item.selector);
    return items.map((item) {
      // For self:: selectors, resolve from the item element itself
      String title;
      if (selectors.title.selector == 'self::') {
        title = item.text.trim();
      } else {
        final el = item.querySelector(selectors.title.selector);
        title = el?.text.trim() ?? '';
      }

      String href;
      if (selectors.href.selector == 'self::') {
        href = item.attributes[selectors.href.attr ?? 'href'] ?? '';
      } else {
        final el = item.querySelector(selectors.href.selector);
        href = el?.attributes[selectors.href.attr ?? 'href'] ?? '';
      }

      return ChapterInfo(
        title: title,
        url: resolveUrl(href, baseUrl),
      );
    }).where((c) => c.title.isNotEmpty && c.url.isNotEmpty).toList();
  }

  /// Extract body text after removing filters
  String extractBody(dom.Document doc, ContentSelectors selectors) {
    // Clone the body element to avoid mutating the original
    final bodyEl = doc.querySelector(selectors.body.selector);
    if (bodyEl == null) return '';

    // Remove filtered elements
    for (final filter in selectors.filters) {
      bodyEl.querySelectorAll(filter).forEach((el) => el.remove());
    }

    // Extract text, preserving paragraph structure
    final paragraphs = <String>[];
    bodyEl.querySelectorAll('p, br').forEach((el) {
      // This is a simplification; in practice we process all child nodes
    });

    // Walk all text nodes and block elements
    final buffer = StringBuffer();
    _walkNodes(bodyEl.nodes, buffer);
    return buffer.toString().trim();
  }

  void _walkNodes(List<dom.Node> nodes, StringBuffer buffer) {
    for (final node in nodes) {
      if (node is dom.Text) {
        final text = node.text.trim();
        if (text.isNotEmpty) {
          buffer.writeln(text);
        }
      } else if (node is dom.Element) {
        final tag = node.localName ?? '';
        if (tag == 'br' || tag == 'p' || tag == 'div') {
          // Block elements: add newline between blocks
        }
        _walkNodes(node.nodes, buffer);
        if (tag == 'p' || tag == 'div') {
          buffer.writeln(); // double newline after block
        }
      }
    }
  }

  /// Fetch book info: title, author, cover, description, and chapter list
  Future<BookInfo> fetchBookInfo(
    String url,
    RuleConfig rule,
  ) async {
    final html = await _fetchHtml(url, rule.encoding);
    final doc = parseHtml(html);
    final baseUrl = rule.baseUrl ?? url;

    final title = rule.book?.title != null
        ? (extractText(doc, rule.book!.title!) ?? '')
        : '';
    final author = rule.book?.author != null
        ? extractText(doc, rule.book!.author!)
        : null;
    final coverUrl = rule.book?.cover != null
        ? extractAttr(doc, rule.book!.cover!, baseUrl: baseUrl)
        : null;
    final description = rule.book?.description != null
        ? extractText(doc, rule.book!.description!)
        : null;

    List<ChapterInfo> chapters = [];
    if (rule.chapterList != null) {
      // If chapterList has a url, fetch that page first
      String listUrl = url;
      if (rule.chapterList!.url != null) {
        listUrl = extractAttr(doc, rule.chapterList!.url!, baseUrl: baseUrl) ??
            url;
      }
      if (listUrl != url) {
        final listHtml = await _fetchHtml(listUrl, rule.encoding);
        final listDoc = parseHtml(listHtml);
        chapters = extractChapterList(listDoc, rule.chapterList!, baseUrl);
      } else {
        chapters = extractChapterList(doc, rule.chapterList!, baseUrl);
      }
    }

    return BookInfo(
      title: title,
      author: author,
      coverUrl: coverUrl,
      description: description,
      chapters: chapters,
    );
  }

  /// Fetch and extract chapter content
  Future<String> fetchContent(String url, RuleConfig rule) async {
    final html = await _fetchHtml(url, rule.encoding);
    final doc = parseHtml(html);
    return extractBody(doc, rule.content);
  }

  /// Fetch HTML with encoding fallback: UTF-8 → GBK → GB2312
  Future<String> _fetchHtml(String url, String encoding) async {
    final response = await _dio.get(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data as List<int>;

    // Try the specified encoding first
    if (encoding.toLowerCase() == 'gbk' || encoding.toLowerCase() == 'gb2312') {
      return gbk.decode(bytes);
    }

    try {
      return String.fromCharCodes(bytes);
    } catch (_) {
      // Fallback to GBK for Chinese sites
      try {
        return gbk.decode(bytes);
      } catch (_) {
        return String.fromCharCodes(bytes); // last resort
      }
    }
  }

  /// Resolve a relative URL against a base URL
  static String resolveUrl(String url, String baseUrl) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    if (url.startsWith('/')) {
      final uri = Uri.parse(base);
      return '${uri.scheme}://${uri.host}$url';
    }
    // Relative to current directory
    final lastSlash = base.lastIndexOf('/');
    final dir = base.substring(0, lastSlash);
    return '$dir/$url';
  }

  void dispose() {
    _dio.close();
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
flutter test test/engine/content_fetcher_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/engine/ test/engine/
git commit -m "feat: add ContentFetcher with HTML parsing and encoding fallback"
```

---

### Task 6: Riverpod 状态管理

**Files:**
- Create: `lib/providers/database_provider.dart`
- Create: `lib/providers/books_provider.dart`
- Create: `lib/providers/rules_provider.dart`
- Create: `lib/providers/reader_provider.dart`

- [ ] **Step 1: 创建 DatabaseProvider（单例提供）**

```dart
// lib/providers/database_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_reader/database/database_helper.dart';

final databaseProvider = Provider<DatabaseHelper>((ref) {
  final db = DatabaseHelper();
  ref.onDispose(() => db.close());
  return db;
});
```

- [ ] **Step 2: 创建 BooksProvider**

```dart
// lib/providers/books_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_reader/database/database_helper.dart';
import 'package:novel_reader/engine/content_fetcher.dart';
import 'package:novel_reader/engine/rule_engine.dart';
import 'package:novel_reader/models/book.dart';
import 'package:novel_reader/models/chapter.dart';
import 'package:novel_reader/providers/database_provider.dart';

final ruleEngineProvider = Provider<RuleEngine>((ref) => RuleEngine());
final contentFetcherProvider = Provider<ContentFetcher>((ref) => ContentFetcher());

// Book list state
final booksProvider = AsyncNotifierProvider<BooksNotifier, List<Book>>(
  BooksNotifier.new,
);

class BooksNotifier extends AsyncNotifier<List<Book>> {
  @override
  Future<List<Book>> build() async {
    final db = ref.read(databaseProvider);
    return db.getBooks();
  }

  Future<Book> addBook(String url, String ruleName) async {
    final db = ref.read(databaseProvider);
    final rules = await db.getRules();
    final ruleJson = rules.firstWhere((r) => r.name == ruleName).config;

    final fetcher = ref.read(contentFetcherProvider);
    final rule = ref.read(ruleEngineProvider).parse(ruleJson);

    // Fetch book info
    final info = await fetcher.fetchBookInfo(url, rule);

    final book = Book(
      title: info.title,
      author: info.author,
      coverUrl: info.coverUrl,
      description: info.description,
      sourceUrl: url,
      ruleName: ruleName,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    final bookId = await db.insertBook(book);

    // Insert chapters
    if (info.chapters.isNotEmpty) {
      final chapters = <Chapter>[];
      for (var i = 0; i < info.chapters.length; i++) {
        chapters.add(Chapter(
          bookId: bookId,
          title: info.chapters[i].title,
          url: info.chapters[i].url,
          index: i,
        ));
      }
      await db.insertChapters(chapters);
    }

    ref.invalidateSelf();
    return book.copyWith(id: bookId);
  }

  Future<void> deleteBook(int id) async {
    final db = ref.read(databaseProvider);
    await db.deleteBook(id);
    ref.invalidateSelf();
  }
}
```

- [ ] **Step 3: 创建 RulesProvider**

```dart
// lib/providers/rules_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_reader/models/rule.dart';
import 'package:novel_reader/providers/database_provider.dart';

final rulesProvider = AsyncNotifierProvider<RulesNotifier, List<Rule>>(
  RulesNotifier.new,
);

class RulesNotifier extends AsyncNotifier<List<Rule>> {
  @override
  Future<List<Rule>> build() async {
    final db = ref.read(databaseProvider);
    return db.getRules();
  }

  Future<void> saveRule(String name, String config) async {
    final db = ref.read(databaseProvider);
    final existing = await db.getRules();
    final match = existing.where((r) => r.name == name).toList();

    if (match.isNotEmpty) {
      await db.updateRule(Rule(
        id: match.first.id,
        name: name,
        config: config,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ));
    } else {
      await db.insertRule(Rule(
        name: name,
        config: config,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ));
    }
    ref.invalidateSelf();
  }

  Future<void> deleteRule(int id) async {
    final db = ref.read(databaseProvider);
    await db.deleteRule(id);
    ref.invalidateSelf();
  }
}
```

- [ ] **Step 4: 创建 ReaderProvider**

```dart
// lib/providers/reader_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_reader/models/book.dart';
import 'package:novel_reader/models/chapter.dart';
import 'package:novel_reader/models/reading_progress.dart';
import 'package:novel_reader/providers/database_provider.dart';
import 'package:novel_reader/providers/books_provider.dart';

class ReaderState {
  final Book? book;
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final List<String> contentPages; // current chapter split into pages
  final int currentPageIndex;
  final bool isLoading;
  final String? error;

  const ReaderState({
    this.book,
    this.chapters = const [],
    this.currentChapterIndex = 0,
    this.contentPages = const [],
    this.currentPageIndex = 0,
    this.isLoading = false,
    this.error,
  });

  ReaderState copyWith({
    Book? book,
    List<Chapter>? chapters,
    int? currentChapterIndex,
    List<String>? contentPages,
    int? currentPageIndex,
    bool? isLoading,
    String? error,
  }) =>
      ReaderState(
        book: book ?? this.book,
        chapters: chapters ?? this.chapters,
        currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
        contentPages: contentPages ?? this.contentPages,
        currentPageIndex: currentPageIndex ?? this.currentPageIndex,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

final readerProvider =
    AsyncNotifierProvider.family<ReaderNotifier, ReaderState, int>(
  ReaderNotifier.new,
);

class ReaderNotifier extends FamilyAsyncNotifier<ReaderState, int> {
  @override
  Future<ReaderState> build(int bookId) async {
    final db = ref.read(databaseProvider);
    final book = await db.getBook(bookId);
    final chapters = await db.getChapters(bookId);
    final progress = await db.getProgress(bookId);

    final chapterIndex = progress?.chapterIndex ?? 0;

    return ReaderState(
      book: book,
      chapters: chapters,
      currentChapterIndex: chapterIndex,
      isLoading: false,
    );
  }

  Future<void> loadChapterContent(int chapterIndex) async {
    state = AsyncData(state.value!.copyWith(isLoading: true, error: null));
    try {
      final db = ref.read(databaseProvider);
      final chapter = state.value!.chapters[chapterIndex];
      String content;

      if (chapter.content != null && chapter.content!.isNotEmpty) {
        content = chapter.content!;
      } else {
        // Fetch content with rule
        final rules = await db.getRules();
        final ruleJson =
            rules.firstWhere((r) => r.name == state.value!.book!.ruleName).config;
        final rule = ref.read(ruleEngineProvider).parse(ruleJson);
        final fetcher = ref.read(contentFetcherProvider);
        content = await fetcher.fetchContent(chapter.url, rule);
        await db.updateChapterContent(chapter.id!, content);
      }

      // Split content into pages based on character count (simple pagination)
      final pages = _splitIntoPages(content);

      state = AsyncData(state.value!.copyWith(
        currentChapterIndex: chapterIndex,
        contentPages: pages,
        currentPageIndex: 0,
        isLoading: false,
      ));
    } catch (e) {
      state = AsyncData(state.value!.copyWith(
        isLoading: false,
        error: '加载失败: $e',
      ));
    }
  }

  void nextPage() {
    final s = state.value!;
    if (s.currentPageIndex < s.contentPages.length - 1) {
      state = AsyncData(s.copyWith(currentPageIndex: s.currentPageIndex + 1));
    } else {
      nextChapter();
    }
  }

  void prevPage() {
    final s = state.value!;
    if (s.currentPageIndex > 0) {
      state = AsyncData(s.copyWith(currentPageIndex: s.currentPageIndex - 1));
    } else {
      prevChapter();
    }
  }

  void nextChapter() {
    final s = state.value!;
    if (s.currentChapterIndex < s.chapters.length - 1) {
      final next = s.currentChapterIndex + 1;
      state = AsyncData(s.copyWith(
        currentChapterIndex: next,
        contentPages: [],
        currentPageIndex: 0,
      ));
      loadChapterContent(next);
      _saveProgress(next);
    }
  }

  void prevChapter() {
    final s = state.value!;
    if (s.currentChapterIndex > 0) {
      final prev = s.currentChapterIndex - 1;
      state = AsyncData(s.copyWith(
        currentChapterIndex: prev,
        contentPages: [],
        currentPageIndex: 0,
      ));
      loadChapterContent(prev);
      _saveProgress(prev);
    }
  }

  Future<void> goToChapter(int chapterIndex) async {
    final s = state.value!;
    state = AsyncData(s.copyWith(
      currentChapterIndex: chapterIndex,
      contentPages: [],
      currentPageIndex: 0,
    ));
    await loadChapterContent(chapterIndex);
    await _saveProgress(chapterIndex);
  }

  Future<void> _saveProgress(int chapterIndex) async {
    final db = ref.read(databaseProvider);
    await db.saveProgress(ReadingProgress(
      bookId: arg,
      chapterIndex: chapterIndex,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  List<String> _splitIntoPages(String content, {int charsPerPage = 800}) {
    final pages = <String>[];
    final lines = content.split('\n');
    var currentPage = StringBuffer();
    var charCount = 0;

    for (final line in lines) {
      if (charCount + line.length > charsPerPage && charCount > 0) {
        pages.add(currentPage.toString());
        currentPage = StringBuffer();
        charCount = 0;
      }
      currentPage.writeln(line);
      charCount += line.length + 1;
    }

    if (currentPage.isNotEmpty) {
      pages.add(currentPage.toString());
    }

    return pages.isEmpty ? [content] : pages;
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add lib/providers/
git commit -m "feat: add Riverpod providers for books, rules, and reader"
```

---

### Task 7: 书架页面 BookshelfPage

**Files:**
- Create: `lib/pages/bookshelf_page.dart`

- [ ] **Step 1: 实现 BookshelfPage**

```dart
// lib/pages/bookshelf_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:novel_reader/providers/books_provider.dart';

class BookshelfPage extends ConsumerWidget {
  const BookshelfPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('书架'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '规则管理',
            onPressed: () => context.push('/rules'),
          ),
        ],
      ),
      body: booksAsync.when(
        data: (books) {
          if (books.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('书架空空，点击右下角添加图书',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return _BookCard(book: book);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _BookCard extends ConsumerWidget {
  final dynamic book; // Book type, simplified for brevity
  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push('/reader/${book.id}'),
      onLongPress: () => _showDeleteDialog(context, ref),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: book.coverUrl != null
                  ? Image.network(book.coverUrl!,
                      fit: BoxFit.cover, errorBuilder: (_, __, ___) =>
                          const Icon(Icons.book, size: 48)))
                  : Container(
                      color: Colors.amber.shade100,
                      child: const Icon(Icons.book, size: 48),
                    ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除图书'),
        content: Text('确定要删除「${book.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(booksProvider.notifier).deleteBook(book.id!);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/pages/bookshelf_page.dart
git commit -m "feat: add BookshelfPage with grid layout and delete"
```

---

### Task 8: 添加图书页面 AddBookPage

**Files:**
- Create: `lib/pages/add_book_page.dart`

- [ ] **Step 1: 实现 AddBookPage**

```dart
// lib/pages/add_book_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:novel_reader/providers/books_provider.dart';
import 'package:novel_reader/providers/rules_provider.dart';

class AddBookPage extends ConsumerStatefulWidget {
  const AddBookPage({super.key});

  @override
  ConsumerState<AddBookPage> createState() => _AddBookPageState();
}

class _AddBookPageState extends ConsumerState<AddBookPage> {
  final _urlController = TextEditingController();
  String? _selectedRule;
  bool _isFetching = false;
  String? _error;
  dynamic _preview; // BookInfo preview

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetchPreview() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || _selectedRule == null) {
      setState(() => _error = '请输入 URL 并选择规则');
      return;
    }

    setState(() {
      _isFetching = true;
      _error = null;
      _preview = null;
    });

    try {
      final rules = ref.read(rulesProvider).value ?? [];
      final ruleJson = rules.firstWhere((r) => r.name == _selectedRule).config;
      final rule = ref.read(ruleEngineProvider).parse(ruleJson);
      final fetcher = ref.read(contentFetcherProvider);
      final info = await fetcher.fetchBookInfo(url, rule);
      setState(() => _preview = info);
    } catch (e) {
      setState(() => _error = '抓取失败: $e');
    } finally {
      setState(() => _isFetching = false);
    }
  }

  Future<void> _addToBookshelf() async {
    if (_preview == null) return;
    try {
      await ref.read(booksProvider.notifier).addBook(
            _urlController.text.trim(),
            _selectedRule!,
          );
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = '添加失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(rulesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('添加图书')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // URL input
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: '图书详情页 URL',
                hintText: 'https://...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),

            // Rule selector
            rulesAsync.when(
              data: (rules) => DropdownButtonFormField<String>(
                value: _selectedRule,
                decoration: const InputDecoration(
                  labelText: '选择规则',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.rule),
                ),
                hint: const Text('选择网站适配规则'),
                items: rules
                    .map((r) =>
                        DropdownMenuItem(value: r.name, child: Text(r.name)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedRule = v),
              ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Text('加载规则失败: $e'),
            ),
            const SizedBox(height: 16),

            // Fetch button
            ElevatedButton.icon(
              onPressed: _isFetching ? null : _fetchPreview,
              icon: const Icon(Icons.search),
              label: const Text('抓取预览'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 16),

            // Error display
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),

            // Loading
            if (_isFetching)
              const Center(child: CircularProgressIndicator()),

            // Preview
            if (_preview != null) ...[
              const Divider(height: 32),
              Text('书名: ${_preview!.title}',
                  style: Theme.of(context).textTheme.titleLarge),
              if (_preview!.author != null)
                Text('作者: ${_preview!.author}'),
              if (_preview!.description != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_preview!.description!,
                      maxLines: 5, overflow: TextOverflow.ellipsis),
                ),
              if (_preview!.chapters.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('共 ${_preview!.chapters.length} 章'),
                ),
              const SizedBox(height: 16),

              // Add button
              ElevatedButton.icon(
                onPressed: _addToBookshelf,
                icon: const Icon(Icons.add),
                label: const Text('加入书架'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/pages/add_book_page.dart
git commit -m "feat: add AddBookPage with URL input and preview"
```

---

### Task 9: 规则管理页面 RulesPage

**Files:**
- Create: `lib/pages/rules_page.dart`

- [ ] **Step 1: 实现 RulesPage**

```dart
// lib/pages/rules_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:novel_reader/providers/rules_provider.dart';

class RulesPage extends ConsumerWidget {
  const RulesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(rulesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('规则管理')),
      body: rulesAsync.when(
        data: (rules) {
          if (rules.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.rule_folder, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('还没有规则，点击右下角创建',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final rule = rules[index];
              return ListTile(
                leading: const Icon(Icons.code),
                title: Text(rule.name),
                subtitle: Text(
                  '更新于 ${DateTime.fromMillisecondsSinceEpoch(rule.updatedAt).toString().substring(0, 19)}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(context, ref, rule),
                ),
                onTap: () => context.push('/rules/edit/${rule.id}'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/rules/edit/new'),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, dynamic rule) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除规则'),
        content: Text('确定要删除规则「${rule.name}」吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              ref.read(rulesProvider.notifier).deleteRule(rule.id!);
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/pages/rules_page.dart
git commit -m "feat: add RulesPage with list and delete"
```

---

### Task 10: 规则编辑器页面 RuleEditorPage

**Files:**
- Create: `lib/pages/rule_editor_page.dart`

- [ ] **Step 1: 实现 RuleEditorPage**

```dart
// lib/pages/rule_editor_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:novel_reader/engine/rule_engine.dart';
import 'package:novel_reader/providers/rules_provider.dart';

class RuleEditorPage extends ConsumerStatefulWidget {
  final String ruleId; // 'new' or integer string
  const RuleEditorPage({super.key, required this.ruleId});

  @override
  ConsumerState<RuleEditorPage> createState() => _RuleEditorPageState();
}

class _RuleEditorPageState extends ConsumerState<RuleEditorPage> {
  final _nameController = TextEditingController();
  final _configController = TextEditingController();
  String? _validationError;
  final _engine = RuleEngine();

  bool get _isEditing => widget.ruleId != 'new';

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadRule();
    }
  }

  Future<void> _loadRule() async {
    final rules = ref.read(rulesProvider).value ?? [];
    final rule = rules.where((r) => r.id.toString() == widget.ruleId).firstOrNull;
    if (rule != null) {
      _nameController.text = rule.name;
      _configController.text = rule.config;
    }
  }

  void _validate() {
    final error = _engine.validate(_configController.text);
    setState(() => _validationError = error.isEmpty ? null : error);
    if (error.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('规则校验通过'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final config = _configController.text.trim();
    if (name.isEmpty) {
      setState(() => _validationError = '请输入规则名称');
      return;
    }
    final error = _engine.validate(config);
    if (error.isNotEmpty) {
      setState(() => _validationError = error);
      return;
    }
    try {
      await ref.read(rulesProvider.notifier).saveRule(name, config);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _validationError = '保存失败: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _configController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑规则' : '新建规则'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '规则名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _configController,
                decoration: InputDecoration(
                  labelText: 'JSON 配置',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                  errorText: _validationError,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _validate,
              icon: const Icon(Icons.check),
              label: const Text('校验 JSON'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/pages/rule_editor_page.dart
git commit -m "feat: add RuleEditorPage with JSON editing and validation"
```

---

### Task 11: 阅读器页面 ReaderPage

**Files:**
- Create: `lib/pages/reader_page.dart`
- Create: `lib/widgets/reader_menu.dart`

- [ ] **Step 1: 实现阅读器辅助 Widget——ReaderMenu**

```dart
// lib/widgets/reader_menu.dart
import 'package:flutter/material.dart';

class ReaderMenu extends StatelessWidget {
  final double fontSize;
  final double brightness;
  final bool isDarkMode;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onBrightnessChanged;
  final VoidCallback onToggleDarkMode;
  final VoidCallback onOpenToc;

  const ReaderMenu({
    super.key,
    required this.fontSize,
    required this.brightness,
    required this.isDarkMode,
    required this.onFontSizeChanged,
    required this.onBrightnessChanged,
    required this.onToggleDarkMode,
    required this.onOpenToc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Font size
          Row(
            children: [
              const Icon(Icons.text_decrease, color: Colors.white, size: 20),
              Expanded(
                child: Slider(
                  value: fontSize,
                  min: 12,
                  max: 28,
                  divisions: 8,
                  activeColor: Colors.white,
                  onChanged: onFontSizeChanged,
                ),
              ),
              const Icon(Icons.text_increase, color: Colors.white, size: 24),
            ],
          ),
          const SizedBox(height: 8),

          // Brightness
          Row(
            children: [
              const Icon(Icons.brightness_low, color: Colors.white, size: 20),
              Expanded(
                child: Slider(
                  value: brightness,
                  min: 0.1,
                  max: 1.0,
                  activeColor: Colors.white,
                  onChanged: onBrightnessChanged,
                ),
              ),
              const Icon(Icons.brightness_high, color: Colors.white, size: 24),
            ],
          ),
          const SizedBox(height: 16),

          // Dark mode + TOC buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: onToggleDarkMode,
                icon: Icon(
                    isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    color: Colors.white),
                label: Text(
                    isDarkMode ? '日间模式' : '夜间模式',
                    style: const TextStyle(color: Colors.white)),
              ),
              TextButton.icon(
                onPressed: onOpenToc,
                icon: const Icon(Icons.list, color: Colors.white),
                label: const Text('目录',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 实现 ReaderPage**

```dart
// lib/pages/reader_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:novel_reader/providers/reader_provider.dart';
import 'package:novel_reader/widgets/reader_menu.dart';

class ReaderPage extends ConsumerStatefulWidget {
  final int bookId;
  const ReaderPage({super.key, required this.bookId});

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  double _fontSize = 18;
  double _brightness = 0.8;
  bool _isDarkMode = false;
  bool _menuVisible = false;

  @override
  void initState() {
    super.initState();
    _initReader();
  }

  Future<void> _initReader() async {
    final notifier = ref.read(readerProvider(widget.bookId).notifier);
    await notifier.loadChapterContent(
        ref.read(readerProvider(widget.bookId)).value?.currentChapterIndex ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final readerAsync = ref.watch(readerProvider(widget.bookId));

    final bgColor = _isDarkMode ? Colors.grey.shade900 : Colors.white;
    final textColor = _isDarkMode ? Colors.grey.shade200 : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              _isDarkMode ? Brightness.light : Brightness.dark,
        ),
        child: readerAsync.when(
          data: (state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final pages = state.contentPages;
            final hasContent = pages.isNotEmpty;
            final currentContent = hasContent
                ? pages[state.currentPageIndex]
                : '';

            return Stack(
              children: [
                // Touch zone: left third - previous page
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  width: MediaQuery.of(context).size.width / 3,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      ref.read(readerProvider(widget.bookId).notifier).prevPage();
                    },
                  ),
                ),

                // Touch zone: right third - next page
                Positioned(
                  right: 0, top: 0, bottom: 0,
                  width: MediaQuery.of(context).size.width / 3,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      ref.read(readerProvider(widget.bookId).notifier).nextPage();
                    },
                  ),
                ),

                // Touch zone: center - toggle menu
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => setState(() => _menuVisible = !_menuVisible),
                    child: hasContent
                        ? SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 32),
                              child: Column(
                                children: [
                                  // Chapter title
                                  if (state.chapters.isNotEmpty &&
                                      state.currentChapterIndex <
                                          state.chapters.length)
                                    Text(
                                      state.chapters[state.currentChapterIndex]
                                          .title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: textColor.withAlpha(128),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  const SizedBox(height: 16),

                                  // Body content
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: Text(
                                        currentContent,
                                        style: TextStyle(
                                          fontSize: _fontSize,
                                          height: 1.8,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Bottom info bar
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${state.currentPageIndex + 1} / ${pages.length}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textColor.withAlpha(128),
                                          ),
                                        ),
                                        Text(
                                          '${state.currentChapterIndex + 1} / ${state.chapters.length} 章',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textColor.withAlpha(128),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              state.error ?? '暂无内容',
                              style: TextStyle(color: textColor),
                            ),
                          ),
                  ),
                ),

                // Menu overlay
                if (_menuVisible)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ReaderMenu(
                      fontSize: _fontSize,
                      brightness: _brightness,
                      isDarkMode: _isDarkMode,
                      onFontSizeChanged: (v) =>
                          setState(() => _fontSize = v),
                      onBrightnessChanged: (v) =>
                          setState(() => _brightness = v),
                      onToggleDarkMode: () =>
                          setState(() => _isDarkMode = !_isDarkMode),
                      onOpenToc: () =>
                          context.push('/toc/${widget.bookId}'),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载阅读器失败: $e')),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add lib/pages/reader_page.dart lib/widgets/reader_menu.dart
git commit -m "feat: add ReaderPage with touch zones, pagination, and menu"
```

---

### Task 12: 章节目录页面 TocPage

**Files:**
- Create: `lib/pages/toc_page.dart`

- [ ] **Step 1: 实现 TocPage**

```dart
// lib/pages/toc_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:novel_reader/providers/reader_provider.dart';

class TocPage extends ConsumerWidget {
  final int bookId;
  const TocPage({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readerAsync = ref.watch(readerProvider(bookId));

    return Scaffold(
      appBar: AppBar(title: const Text('目录')),
      body: readerAsync.when(
        data: (state) {
          final chapters = state.chapters;
          final current = state.currentChapterIndex;

          return ListView.builder(
            itemCount: chapters.length,
            itemBuilder: (context, index) {
              final isCurrent = index == current;
              return ListTile(
                leading: Text('${index + 1}',
                    style: TextStyle(
                      color: isCurrent ? Theme.of(context).primaryColor : null,
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                    )),
                title: Text(
                  chapters[index].title,
                  style: TextStyle(
                    color: isCurrent ? Theme.of(context).primaryColor : null,
                    fontWeight:
                        isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isCurrent
                    ? Icon(Icons.play_arrow,
                        color: Theme.of(context).primaryColor)
                    : null,
                onTap: () async {
                  await ref
                      .read(readerProvider(bookId).notifier)
                      .goToChapter(index);
                  if (context.mounted) context.pop();
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载目录失败: $e')),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/pages/toc_page.dart
git commit -m "feat: add TocPage for chapter navigation"
```

---

### Task 13: App 路由与入口组装

**Files:**
- Create: `lib/app.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: 创建 App 组件（含路由）**

```dart
// lib/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:novel_reader/pages/bookshelf_page.dart';
import 'package:novel_reader/pages/add_book_page.dart';
import 'package:novel_reader/pages/reader_page.dart';
import 'package:novel_reader/pages/rules_page.dart';
import 'package:novel_reader/pages/rule_editor_page.dart';
import 'package:novel_reader/pages/toc_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const BookshelfPage(),
      ),
      GoRoute(
        path: '/add',
        builder: (context, state) => const AddBookPage(),
      ),
      GoRoute(
        path: '/reader/:bookId',
        builder: (context, state) {
          final bookId = int.parse(state.pathParameters['bookId']!);
          return ReaderPage(bookId: bookId);
        },
      ),
      GoRoute(
        path: '/rules',
        builder: (context, state) => const RulesPage(),
      ),
      GoRoute(
        path: '/rules/edit/:ruleId',
        builder: (context, state) {
          final ruleId = state.pathParameters['ruleId']!;
          return RuleEditorPage(ruleId: ruleId);
        },
      ),
      GoRoute(
        path: '/toc/:bookId',
        builder: (context, state) {
          final bookId = int.parse(state.pathParameters['bookId']!);
          return TocPage(bookId: bookId);
        },
      ),
    ],
  );
});

class NovelReaderApp extends ConsumerWidget {
  const NovelReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Novel Reader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
```

- [ ] **Step 2: 更新 main.dart**

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_reader/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: NovelReaderApp()));
}
```

- [ ] **Step 3: 验证整体编译**

```bash
flutter analyze
```

修复所有编译错误。

- [ ] **Step 4: Commit**

```bash
git add lib/app.dart lib/main.dart
git commit -m "feat: wire up app routing with go_router and Riverpod"
```

---

### Task 14: 错误处理与编码回退完善

**Files:**
- Modify: `lib/engine/content_fetcher.dart`

- [ ] **Step 1: 在 ContentFetcher 中增加 dio 重试和超时错误处理**

更新 `_fetchHtml` 方法（替换原有方法）：

```dart
// lib/engine/content_fetcher.dart — 在 ContentFetcher 类中修改 _fetchHtml 和添加重试逻辑

Future<String> _fetchHtml(String url, String encoding) async {
  int retries = 0;
  const maxRetries = 3;

  while (retries < maxRetries) {
    try {
      final response = await _dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data as List<int>;
      return _decodeBytes(bytes, encoding);
    } on DioException catch (e) {
      retries++;
      if (retries >= maxRetries) {
        rethrow;
      }
      // Wait before retry (exponential backoff)
      await Future.delayed(Duration(seconds: retries));
    }
  }
  throw Exception('Max retries exceeded');
}

String _decodeBytes(List<int> bytes, String encoding) {
  // Try specified encoding
  if (encoding.toLowerCase() == 'gbk' || encoding.toLowerCase() == 'gb2312') {
    try {
      return gbk.decode(bytes);
    } catch (_) {}
  }

  // Try UTF-8
  try {
    return utf8.decode(bytes);
  } catch (_) {}

  // Try GBK as fallback for Chinese sites
  try {
    return gbk.decode(bytes);
  } catch (_) {}

  // Last resort: Latin-1 (never fails)
  return latin1.decode(bytes);
}
```

需要在文件头部添加 import：
```dart
import 'dart:convert';
```

- [ ] **Step 2: 运行全部测试**

```bash
flutter test
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add retry logic and encoding fallback chain"
```

---

## 验证清单

全部任务完成后，执行以下验证：

```bash
# 1. 代码质量检查
flutter analyze

# 2. 运行所有单元测试
flutter test

# 3. 构建 APK（debug）
flutter build apk --debug
```

所有命令应该成功，无报错。

## 后续可迭代方向（不包含在本计划中）

- 翻页动画（PageView 过渡）
- 屏幕亮度直接调节（使用系统 API）
- 字体选择
- 连续翻页模式的自动 nextPage 抓取
