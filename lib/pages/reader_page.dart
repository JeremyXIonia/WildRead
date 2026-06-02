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

  @override
  void initState() {
    super.initState();
    // Defer content load to after first frame, when provider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadIfReady());
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

  @override
  Widget build(BuildContext context) {
    final readerAsync = ref.watch(readerProvider(widget.bookId));

    final bgColor = _isDarkMode ? Colors.grey.shade900 : Colors.white;
    final textColor =
        _isDarkMode ? Colors.grey.shade200 : Colors.black87;

    // Attempt to load content when data becomes available
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
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final pages = state.contentPages;
            final hasContent =
                pages.isNotEmpty && pages.any((p) => p.trim().isNotEmpty);
            final currentContent =
                hasContent ? pages[state.currentPageIndex] : '';

            return Stack(
              children: [
                // Content area (bottom layer)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () =>
                        setState(() => _menuVisible = !_menuVisible),
                    child: hasContent
                        ? SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
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
                                      key: ValueKey(
                                          '${state.currentChapterIndex}-${state.currentPageIndex}'),
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
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (state.error != null) ...[
                                    const Icon(Icons.error_outline,
                                        size: 48, color: Colors.red),
                                    const SizedBox(height: 16),
                                    SelectableText(state.error!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.red,
                                            fontSize: 13)),
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

                // Left zone: prev page (ABOVE content, so it gets taps first)
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  width: MediaQuery.of(context).size.width / 3,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => ref
                        .read(readerProvider(widget.bookId).notifier)
                        .prevPage(),
                  ),
                ),

                // Right zone: next page (ABOVE content)
                Positioned(
                  right: 0, top: 0, bottom: 0,
                  width: MediaQuery.of(context).size.width / 3,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => ref
                        .read(readerProvider(widget.bookId).notifier)
                        .nextPage(),
                  ),
                ),

                // Menu overlay (top layer)
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
