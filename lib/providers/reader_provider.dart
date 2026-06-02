import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wildread/engine/content_fetcher.dart';
import 'package:wildread/models/book.dart';
import 'package:wildread/models/chapter.dart';
import 'package:wildread/models/reading_progress.dart';
import 'package:wildread/providers/database_provider.dart';
import 'package:wildread/providers/books_provider.dart';

class ReaderState {
  final Book? book;
  final List<Chapter> chapters;
  final int currentChapterIndex;
  final List<String> contentPages;
  final int currentPageIndex;
  final bool isLoading;
  final String? error;
  final String? debugInfo;

  const ReaderState({
    this.book,
    this.chapters = const [],
    this.currentChapterIndex = 0,
    this.contentPages = const [],
    this.currentPageIndex = 0,
    this.isLoading = false,
    this.error,
    this.debugInfo,
  });

  ReaderState copyWith({
    Book? book,
    List<Chapter>? chapters,
    int? currentChapterIndex,
    List<String>? contentPages,
    int? currentPageIndex,
    bool? isLoading,
    String? error,
    String? debugInfo,
  }) =>
      ReaderState(
        book: book ?? this.book,
        chapters: chapters ?? this.chapters,
        currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
        contentPages: contentPages ?? this.contentPages,
        currentPageIndex: currentPageIndex ?? this.currentPageIndex,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        debugInfo: debugInfo,
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
    final pageIndex = (progress?.scrollOffset ?? 0).round();

    return ReaderState(
      book: book,
      chapters: chapters,
      currentChapterIndex: chapterIndex,
      currentPageIndex: pageIndex,
      isLoading: false,
    );
  }

  Future<void> loadChapterContent(int chapterIndex) async {
    // Always reset to loading state, even if retrying after error
    final current = state.value;
    if (current == null) return;

    if (current.chapters.isEmpty) {
      state = AsyncData(current.copyWith(
        isLoading: false,
        error: '该书没有章节，请检查规则配置',
      ));
      return;
    }
    if (chapterIndex < 0 || chapterIndex >= current.chapters.length) {
      state = AsyncData(current.copyWith(
          isLoading: false, error: '章节索引越界'));
      return;
    }

    state = AsyncData(current.copyWith(isLoading: true, error: null));

    try {
      final db = ref.read(databaseProvider);
      final chapter = current.chapters[chapterIndex];
      String content;
      String bodySelector = '?';

      // Get rule to extract body selector for error messages
      final rules = await db.getRules();
      final matched = rules.where((r) => r.name == current.book!.ruleName);
      if (matched.isNotEmpty) {
        final ruleConfig =
            ref.read(ruleEngineProvider).parse(matched.first.config);
        bodySelector = ruleConfig.content.body.selector;
      }

      if (chapter.content != null && chapter.content!.isNotEmpty) {
        content = chapter.content!;
      } else {
        if (matched.isEmpty) {
          throw Exception('未找到规则: ${current.book!.ruleName}');
        }
        final ruleConfig =
            ref.read(ruleEngineProvider).parse(matched.first.config);
        final fetcher = ref.read(contentFetcherProvider);

        fetcher.debugMode = true;
        fetcher.debug = FetchDebug();

        content = await fetcher
            .fetchContent(chapter.url, ruleConfig)
            .timeout(const Duration(seconds: 20));

        await db.updateChapterContent(chapter.id!, content);

        if (fetcher.debug != null && content.isEmpty) {
          final dbg = fetcher.debug!.summarize();
          if (dbg.isNotEmpty) {
            throw Exception('内容为空\n$dbg');
          }
        }
      }

      if (content.isEmpty) {
        throw Exception(
            '章节内容为空\nURL: ${current.chapters[chapterIndex].url}\n'
            '选择器: $bodySelector');
      }

      final pages = _splitIntoPages(content);

      // Preserve saved page index when reloading same chapter,
      // reset to 0 when navigating to a different chapter
      final savedPage = (chapterIndex == current.currentChapterIndex)
          ? current.currentPageIndex
          : 0;
      final pageIndex = savedPage < pages.length ? savedPage : 0;

      state = AsyncData(current.copyWith(
        currentChapterIndex: chapterIndex,
        contentPages: pages,
        currentPageIndex: pageIndex,
        isLoading: false,
      ));
    } catch (e) {
      state = AsyncData(current.copyWith(
        isLoading: false,
        error: '${e is FormatException ? '编码错误' : '加载失败'}: $e',
      ));
    }
  }

  void nextPage() {
    final s = state.value;
    if (s == null) return;
    if (s.currentPageIndex < s.contentPages.length - 1) {
      final next = s.currentPageIndex + 1;
      state = AsyncData(s.copyWith(currentPageIndex: next));
      _saveProgress(s.currentChapterIndex);
    } else {
      nextChapter();
    }
  }

  void prevPage() {
    final s = state.value;
    if (s == null) return;
    if (s.currentPageIndex > 0) {
      final prev = s.currentPageIndex - 1;
      state = AsyncData(s.copyWith(currentPageIndex: prev));
      _saveProgress(s.currentChapterIndex);
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
    final s = state.value;
    final db = ref.read(databaseProvider);
    await db.saveProgress(ReadingProgress(
      bookId: arg,
      chapterIndex: chapterIndex,
      scrollOffset: s?.currentPageIndex.toDouble() ?? 0,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  List<String> _splitIntoPages(String content, {int charsPerPage = 1000}) {
    // Add Chinese-style first-line indent (two fullwidth spaces) per paragraph
    const indent = '　　';
    final paragraphs = content.split(RegExp(r'\n\s*\n'));
    final indented = paragraphs.map((p) {
      final trimmed = p.trim();
      if (trimmed.isEmpty) return trimmed;
      // Don't indent if already starts with indent or is a section header
      if (trimmed.startsWith(indent) ||
          trimmed.startsWith('第') ||
          trimmed.startsWith('卷')) {
        return trimmed;
      }
      return '$indent$trimmed';
    }).join('\n\n');

    final pages = <String>[];
    final lines = indented.split('\n');
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
