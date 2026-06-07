import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wildread/providers/reader_provider.dart';

class TocPage extends ConsumerWidget {
  final int bookId;
  const TocPage({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readerAsync = ref.watch(readerProvider(bookId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('目录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新全部章节',
            onPressed: () => _confirmRefreshAll(context, ref),
          ),
        ],
      ),
      body: readerAsync.when(
        data: (state) {
          final chapters = state.chapters;
          final current = state.currentChapterIndex;

          return ListView.builder(
            itemCount: chapters.length,
            itemBuilder: (context, index) {
              final ch = chapters[index];
              final isCurrent = index == current;
              final isCached = ch.content != null && ch.content!.isNotEmpty;
              return ListTile(
                leading: Text('${index + 1}',
                    style: TextStyle(
                      color: isCurrent
                          ? Theme.of(context).primaryColor
                          : null,
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                    )),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        ch.title,
                        style: TextStyle(
                          color: isCurrent
                              ? Theme.of(context).primaryColor
                              : null,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isCached && !isCurrent)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(Icons.cloud_done,
                            size: 14,
                            color: Colors.grey.withAlpha(153)),
                      ),
                  ],
                ),
                trailing: isCurrent
                    ? Icon(Icons.play_arrow,
                        color: Theme.of(context).primaryColor)
                    : null,
                onTap: () {
                  final target = index;
                  context.pop();
                  ref
                      .read(readerProvider(bookId).notifier)
                      .goToChapter(target);
                },
                onLongPress: () =>
                    _showChapterMenu(context, ref, index, ch.title),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载目录失败: $e')),
      ),
    );
  }

  void _confirmRefreshAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刷新全部章节'),
        content: const Text('将清除本书所有已缓存内容并重新抓取当前章节，确定继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(readerProvider(bookId).notifier).refreshAllChapters();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showChapterMenu(
      BuildContext context, WidgetRef ref, int index, String title) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('刷新本章'),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(readerProvider(bookId).notifier).refreshChapter(index);
              },
            ),
          ],
        ),
      ),
    );
  }
}
