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
  final List<String> contentPages;
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
    final current = state.value;
    if (current == null || current.chapters.isEmpty) return;
    if (chapterIndex < 0 || chapterIndex >= current.chapters.length) return;

    state = AsyncData(current.copyWith(isLoading: true, error: null));

    try {
      final db = ref.read(databaseProvider);
      final chapter = current.chapters[chapterIndex];
      String content;

      if (chapter.content != null && chapter.content!.isNotEmpty) {
        content = chapter.content!;
      } else {
        final rules = await db.getRules();
        final matched = rules.where((r) => r.name == current.book!.ruleName);
        if (matched.isEmpty) {
          throw Exception('未找到规则: ${current.book!.ruleName}');
        }
        final rule = ref.read(ruleEngineProvider).parse(matched.first.config);
        final fetcher = ref.read(contentFetcherProvider);
        content = await fetcher.fetchContent(chapter.url, rule);
        await db.updateChapterContent(chapter.id!, content);
      }

      final pages = _splitIntoPages(content);

      state = AsyncData(current.copyWith(
        currentChapterIndex: chapterIndex,
        contentPages: pages,
        currentPageIndex: 0,
        isLoading: false,
      ));
    } catch (e) {
      state = AsyncData(current.copyWith(
        isLoading: false,
        error: '加载失败: $e',
      ));
    }
  }

  void nextPage() {
    final s = state.value;
    if (s == null) return;
    if (s.currentPageIndex < s.contentPages.length - 1) {
      state = AsyncData(s.copyWith(currentPageIndex: s.currentPageIndex + 1));
    } else {
      nextChapter();
    }
  }

  void prevPage() {
    final s = state.value;
    if (s == null) return;
    if (s.currentPageIndex > 0) {
      state = AsyncData(s.copyWith(currentPageIndex: s.currentPageIndex - 1));
    } else {
      prevChapter();
    }
  }

  void nextChapter() {
    final s = state.value;
    if (s == null) return;
    if (s.currentChapterIndex < s.chapters.length - 1) {
      final next = s.currentChapterIndex + 1;
      state = AsyncData(s.copyWith(
        currentChapterIndex: next,
        contentPages: const [],
        currentPageIndex: 0,
      ));
      loadChapterContent(next);
      _saveProgress(next);
    }
  }

  void prevChapter() {
    final s = state.value;
    if (s == null) return;
    if (s.currentChapterIndex > 0) {
      final prev = s.currentChapterIndex - 1;
      state = AsyncData(s.copyWith(
        currentChapterIndex: prev,
        contentPages: const [],
        currentPageIndex: 0,
      ));
      loadChapterContent(prev);
      _saveProgress(prev);
    }
  }

  Future<void> goToChapter(int chapterIndex) async {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(s.copyWith(
      currentChapterIndex: chapterIndex,
      contentPages: const [],
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
