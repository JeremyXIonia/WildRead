import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_reader/engine/content_fetcher.dart';
import 'package:novel_reader/engine/rule_engine.dart';
import 'package:novel_reader/models/book.dart';
import 'package:novel_reader/models/chapter.dart';
import 'package:novel_reader/providers/database_provider.dart';

final ruleEngineProvider = Provider<RuleEngine>((ref) => RuleEngine());

final contentFetcherProvider =
    Provider<ContentFetcher>((ref) => ContentFetcher());

final booksProvider =
    AsyncNotifierProvider<BooksNotifier, List<Book>>(BooksNotifier.new);

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
