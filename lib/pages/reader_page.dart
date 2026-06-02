import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wildread/providers/reader_provider.dart';
import 'package:wildread/widgets/reader_menu.dart';

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
  bool _contentLoaded = false;

  late PageController _pageController;
  int _controllerChapterIdx = -1;
  int _lastPageCount = 0;

  /// Page layout dimensions, computed from MediaQuery each build.
  double _pageWidth = 0;
  double _pageHeight = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadIfReady());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadIfReady() {
    if (_contentLoaded) return;
    final reader = ref.read(readerProvider(widget.bookId));
    if (reader.hasValue && reader.value!.chapters.isNotEmpty) {
      _contentLoaded = true;
      final index = reader.value!.currentChapterIndex;
      ref
          .read(readerProvider(widget.bookId).notifier)
          .loadChapterContent(index);
    }
  }

  void _retry() {
    _contentLoaded = false;
    _loadIfReady();
  }

  void _repaginateIfNeeded({bool force = false}) {
    // Avoid duplicate pagination if pages already computed
    if (!force) {
      final s = ref.read(readerProvider(widget.bookId)).value;
      if (s == null || s.rawContent.isEmpty || s.contentPages.isNotEmpty) {
        return;
      }
    }
    if (_pageWidth > 0 && _pageHeight > 0) {
      ref.read(readerProvider(widget.bookId).notifier).repaginate(
        fontSize: _fontSize,
        pageWidth: _pageWidth,
        pageHeight: _pageHeight,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final readerAsync = ref.watch(readerProvider(widget.bookId));

    final bgColor = _isDarkMode ? Colors.grey.shade900 : Colors.white;
    final textColor = _isDarkMode ? Colors.grey.shade200 : Colors.black87;

    // Compute page dimensions from screen metrics
    final media = MediaQuery.of(context);
    final safeTop = media.padding.top;
    final safeBottom = media.padding.bottom;
    const chromeHeight = 76.0; // title(~28) + bottom bar(~48)
    _pageWidth = media.size.width - 40; // horizontal padding 20×2
    _pageHeight = media.size.height - safeTop - safeBottom - chromeHeight;

    if (readerAsync.hasValue &&
        !_contentLoaded &&
        readerAsync.value!.chapters.isNotEmpty &&
        !readerAsync.value!.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadIfReady());
    }

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
            // Content loaded but not yet paginated → trigger pagination
            if (state.rawContent.isNotEmpty &&
                state.contentPages.isEmpty &&
                !state.isLoading) {
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _repaginateIfNeeded());
            }

            if (state.isLoading ||
                (state.rawContent.isNotEmpty && state.contentPages.isEmpty)) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    if (state.rawContent.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('正在排版…',
                          style: TextStyle(
                              color: textColor.withAlpha(128),
                              fontSize: 13)),
                    ],
                  ],
                ),
              );
            }

            final pages = state.contentPages;
            final hasContent =
                pages.isNotEmpty && pages.any((p) => p.trim().isNotEmpty);

            // Recreate PageController when chapter or page count changes
            if (hasContent &&
                (state.currentChapterIndex != _controllerChapterIdx ||
                 pages.length != _lastPageCount)) {
              _pageController.dispose();
              _pageController = PageController(
                  initialPage:
                      state.currentPageIndex.clamp(0, pages.length - 1));
              _controllerChapterIdx = state.currentChapterIndex;
              _lastPageCount = pages.length;
            }

            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _menuVisible = !_menuVisible),
                    child: hasContent
                        ? SafeArea(
                            child: Column(
                              children: [
                                // Chapter title
                                if (state.chapters.isNotEmpty &&
                                    state.currentChapterIndex <
                                        state.chapters.length)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 4, bottom: 4),
                                    child: Text(
                                      state
                                          .chapters[
                                              state.currentChapterIndex]
                                          .title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: textColor.withAlpha(128),
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                // Pages — horizontally swipeable, no vertical scroll
                                Expanded(
                                  child: PageView.builder(
                                    key: ValueKey(
                                        'pager-${state.currentChapterIndex}'),
                                    controller: _pageController,
                                    itemCount: pages.length,
                                    onPageChanged: (index) {
                                      ref
                                          .read(readerProvider(
                                                  widget.bookId)
                                              .notifier)
                                          .setPageIndex(index);
                                    },
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20),
                                        child: Text(
                                          pages[index],
                                          style: TextStyle(
                                            fontSize: _fontSize,
                                            height: 1.8,
                                            color: textColor,
                                          ),
                                          maxLines: null,
                                          overflow: TextOverflow.clip,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                // Bottom bar
                                Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 12, left: 20, right: 20),
                                  child: Row(
                                    children: [
                                      if (state.currentPageIndex == 0 &&
                                          state.currentChapterIndex > 0)
                                        TextButton.icon(
                                          onPressed: () {
                                            ref
                                                .read(readerProvider(
                                                        widget.bookId)
                                                    .notifier)
                                                .prevChapter();
                                          },
                                          icon: const Icon(
                                              Icons.arrow_back_ios,
                                              size: 12),
                                          label: const Text('上一章',
                                              style:
                                                  TextStyle(fontSize: 12)),
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                textColor.withAlpha(153),
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(0, 32),
                                          ),
                                        )
                                      else
                                        const SizedBox(width: 60),
                                      Expanded(
                                        child: Text(
                                          '${state.currentPageIndex + 1} / ${pages.length} 页',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                textColor.withAlpha(128),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      if (state.currentPageIndex ==
                                              pages.length - 1 &&
                                          state.currentChapterIndex <
                                              state.chapters.length - 1)
                                        TextButton.icon(
                                          onPressed: () {
                                            ref
                                                .read(readerProvider(
                                                        widget.bookId)
                                                    .notifier)
                                                .nextChapter();
                                          },
                                          icon: const Icon(
                                              Icons.arrow_forward_ios,
                                              size: 12),
                                          label: const Text('下一章',
                                              style:
                                                  TextStyle(fontSize: 12)),
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                textColor.withAlpha(153),
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(0, 32),
                                          ),
                                        )
                                      else
                                        const SizedBox(width: 60),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (state.error != null) ...[
                                    const Icon(Icons.error_outline,
                                        size: 48, color: Colors.red),
                                    const SizedBox(height: 16),
                                    SelectableText(
                                      state.error!,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 13),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _retry,
                                      child: const Text('重试'),
                                    ),
                                  ] else ...[
                                    const Text('暂无内容',
                                        style: TextStyle(
                                            color: Colors.grey)),
                                    if (state.chapters.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                          '共 ${state.chapters.length} 章，点击下方目录选择章节',
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12)),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: () => context
                                            .push('/toc/${widget.bookId}'),
                                        icon: const Icon(Icons.list),
                                        label: const Text('目录'),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
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
                      onFontSizeChanged: (v) {
                        setState(() => _fontSize = v);
                        WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _repaginateIfNeeded(force: true));
                      },
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
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
              child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('加载失败: $e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                    onPressed: _retry, child: const Text('重试')),
              ],
            ),
          )),
        ),
      ),
    );
  }
}
