import 'dart:convert';

import 'package:flutter/material.dart';
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
  final String rawContent;
  final List<String> contentPages;
  final int currentPageIndex;
  final bool isLoading;
  final String? error;
  final String? debugInfo;

  const ReaderState({
    this.book,
    this.chapters = const [],
    this.currentChapterIndex = 0,
    this.rawContent = '',
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
    String? rawContent,
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
        rawContent: rawContent ?? this.rawContent,
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

      // Update the chapter in the list to reflect cached content
      final updatedChapters = current.chapters.toList();
      updatedChapters[chapterIndex] = Chapter(
        id: chapter.id,
        bookId: chapter.bookId,
        title: chapter.title,
        url: chapter.url,
        index: chapter.index,
        content: content,
        pages: chapter.pages,
      );

      state = AsyncData(current.copyWith(
        chapters: updatedChapters,
        currentChapterIndex: chapterIndex,
        rawContent: content,
        contentPages: const [],
        isLoading: false,
      ));
    } catch (e) {
      state = AsyncData(current.copyWith(
        isLoading: false,
        error: '${e is FormatException ? '编码错误' : '加载失败'}: $e',
      ));
    }
  }

  /// Paginate raw content into screen-sized pages.
  /// Called by the UI after content is loaded or when font/size changes.
  void repaginate({
    required double fontSize,
    required double pageWidth,
    required double pageHeight,
  }) {
    final s = state.value;
    if (s == null || s.rawContent.isEmpty || pageWidth <= 0 || pageHeight <= 0) return;

    // Check cached page offsets first
    final chapter = s.chapters[s.currentChapterIndex];
    final cacheKey = _cacheKey(fontSize, pageWidth, pageHeight);
    final cachedPages = _pagesFromCache(s.rawContent, chapter.pages, cacheKey);
    if (cachedPages != null) {
      final pageIndex = s.currentPageIndex < cachedPages.length
          ? s.currentPageIndex
          : cachedPages.length - 1;
      state = AsyncData(s.copyWith(
        contentPages: cachedPages,
        currentPageIndex: pageIndex.clamp(0, cachedPages.length - 1),
      ));
      return;
    }

    final pages = _paginateContent(
      s.rawContent,
      fontSize: fontSize,
      pageWidth: pageWidth,
      pageHeight: pageHeight,
    );

    final pageIndex = s.currentPageIndex < pages.length
        ? s.currentPageIndex
        : pages.length - 1;

    state = AsyncData(s.copyWith(
      contentPages: pages,
      currentPageIndex: pageIndex.clamp(0, pages.length - 1),
    ));

    // Persist page offsets to DB in background
    _savePagesToDb(chapter.id, pages, cacheKey);
  }

  /// Try to reconstruct pages from cached offsets. Returns null on cache miss.
  List<String>? _pagesFromCache(String rawContent, String? cacheJson, String expectedKey) {
    if (cacheJson == null) return null;
    try {
      final cached = json.decode(cacheJson) as Map<String, dynamic>;
      if (cached['key'] != expectedKey) return null;
      final offsets = (cached['offsets'] as List).cast<int>();
      final processed = _preprocessContent(rawContent);
      final pages = <String>[];
      for (var i = 0; i < offsets.length; i++) {
        final start = offsets[i];
        final end = i + 1 < offsets.length ? offsets[i + 1] : processed.length;
        pages.add(processed.substring(start, end));
      }
      return pages;
    } catch (_) {
      return null; // corrupt cache
    }
  }

  /// Persist page boundary offsets to DB for future reads.
  void _savePagesToDb(int? chapterId, List<String> pages, String cacheKey) {
    if (chapterId == null) return;
    final offsets = <int>[0];
    var pos = 0;
    for (var i = 0; i < pages.length - 1; i++) {
      pos += pages[i].length;
      offsets.add(pos);
    }
    final cacheJson = json.encode({'key': cacheKey, 'offsets': offsets});
    ref.read(databaseProvider).updateChapterPages(chapterId, cacheJson);
  }

  /// Generate a cache key from pagination parameters.
  String _cacheKey(double fontSize, double pageWidth, double pageHeight) =>
      '${fontSize.toStringAsFixed(1)}|${pageWidth.toStringAsFixed(1)}|${pageHeight.toStringAsFixed(1)}';

  void setPageIndex(int index) {
    final s = state.value;
    if (s == null || index < 0 || index >= s.contentPages.length) return;
    state = AsyncData(s.copyWith(currentPageIndex: index));
    _saveProgress(s.currentChapterIndex);
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
        rawContent: '',
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
        rawContent: '',
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
      rawContent: '',
      contentPages: const [],
      currentPageIndex: 0,
    ));
    await loadChapterContent(chapterIndex);
    await _saveProgress(chapterIndex);
  }

  /// Clear cache for the given chapter and re-fetch if it's the current one.
  Future<void> refreshChapter(int chapterIndex) async {
    final s = state.value;
    if (s == null) return;
    final db = ref.read(databaseProvider);
    final ch = s.chapters[chapterIndex];
    if (ch.id == null) return;
    await db.clearChapterCache(ch.id!);

    // Update in-memory chapter to reflect cleared cache
    final updated = s.chapters.toList();
    updated[chapterIndex] = Chapter(
      id: ch.id,
      bookId: ch.bookId,
      title: ch.title,
      url: ch.url,
      index: ch.index,
    );
    state = AsyncData(s.copyWith(chapters: updated));

    if (chapterIndex == s.currentChapterIndex) {
      await loadChapterContent(chapterIndex);
    }
  }

  /// Clear cache for all chapters of the current book, then re-fetch current.
  Future<void> refreshAllChapters() async {
    final s = state.value;
    if (s == null) return;
    final db = ref.read(databaseProvider);
    await db.clearBookCache(arg);

    final updated = s.chapters
        .map((ch) => Chapter(
              id: ch.id,
              bookId: ch.bookId,
              title: ch.title,
              url: ch.url,
              index: ch.index,
            ))
        .toList();
    state = AsyncData(s.copyWith(
      chapters: updated,
      rawContent: '',
      contentPages: const [],
    ));

    if (updated.isNotEmpty) {
      await loadChapterContent(s.currentChapterIndex);
    }
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

  /// Pre-process raw content: add Chinese-style paragraph indentation.
  String _preprocessContent(String content) {
    const indent = '　　';
    final paragraphs = content.split(RegExp(r'\n\s*\n'));
    return paragraphs.map((p) {
      final trimmed = p.trim();
      if (trimmed.isEmpty) return trimmed;
      if (trimmed.startsWith(indent) ||
          trimmed.startsWith('第') ||
          trimmed.startsWith('卷')) {
        return trimmed;
      }
      return '$indent$trimmed';
    }).join('\n\n');
  }

  /// Split text into pages that each fit exactly within [pageHeight] at the
  /// given [fontSize] and [pageWidth], using TextPainter for accurate layout.
  /// Layouts the full text once, then finds page boundaries via getPositionForOffset.
  List<String> _paginateContent(
    String rawText, {
    required double fontSize,
    required double pageWidth,
    required double pageHeight,
  }) {
    final processed = _preprocessContent(rawText);
    if (processed.isEmpty) return [''];

    final style = TextStyle(fontSize: fontSize, height: 1.8);
    final tp = TextPainter(
      text: TextSpan(text: processed, style: style),
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: pageWidth);

    if (tp.height <= pageHeight) return [processed];

    final pages = <String>[];
    double y = 0;

    while (y < tp.height) {
      final nextY = y + pageHeight;
      if (nextY >= tp.height) {
        final pos = tp.getPositionForOffset(Offset(0, y));
        final chunk = processed.substring(pos.offset);
        if (chunk.isNotEmpty) pages.add(chunk);
        break;
      }
      final startPos = tp.getPositionForOffset(Offset(0, y));
      final endPos = tp.getPositionForOffset(Offset(0, nextY));
      if (endPos.offset > startPos.offset) {
        pages.add(processed.substring(startPos.offset, endPos.offset));
      }
      y = nextY;
    }

    return pages.isEmpty ? [processed] : pages;
  }
}
