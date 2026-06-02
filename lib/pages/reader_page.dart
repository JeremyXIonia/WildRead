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
    final current =
        ref.read(readerProvider(widget.bookId)).value?.currentChapterIndex ?? 0;
    await notifier.loadChapterContent(current);
  }

  @override
  Widget build(BuildContext context) {
    final readerAsync = ref.watch(readerProvider(widget.bookId));

    final bgColor = _isDarkMode ? Colors.grey.shade900 : Colors.white;
    final textColor =
        _isDarkMode ? Colors.grey.shade200 : Colors.black87;

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
            final currentContent =
                hasContent ? pages[state.currentPageIndex] : '';

            return Stack(
              children: [
                // Left zone: previous page
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: MediaQuery.of(context).size.width / 3,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => ref
                        .read(readerProvider(widget.bookId).notifier)
                        .prevPage(),
                  ),
                ),

                // Right zone: next page
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: MediaQuery.of(context).size.width / 3,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => ref
                        .read(readerProvider(widget.bookId).notifier)
                        .nextPage(),
                  ),
                ),

                // Content area
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () =>
                        setState(() => _menuVisible = !_menuVisible),
                    child: hasContent
                        ? SafeArea(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 32),
                              child: Column(
                                children: [
                                  if (state.chapters.isNotEmpty &&
                                      state.currentChapterIndex <
                                          state.chapters.length)
                                    Text(
                                      state
                                          .chapters[
                                              state.currentChapterIndex]
                                          .title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color:
                                            textColor.withAlpha(128),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  const SizedBox(height: 16),

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

                                  Padding(
                                    padding:
                                        const EdgeInsets.only(top: 16),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment
                                              .spaceBetween,
                                      children: [
                                        Text(
                                          '${state.currentPageIndex + 1} / ${pages.length}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textColor
                                                .withAlpha(128),
                                          ),
                                        ),
                                        Text(
                                          '${state.currentChapterIndex + 1} / ${state.chapters.length} 章',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textColor
                                                .withAlpha(128),
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
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('加载阅读器失败: $e')),
        ),
      ),
    );
  }
}
