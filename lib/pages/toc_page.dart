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
                      color: isCurrent
                          ? Theme.of(context).primaryColor
                          : null,
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                    )),
                title: Text(
                  chapters[index].title,
                  style: TextStyle(
                    color: isCurrent
                        ? Theme.of(context).primaryColor
                        : null,
                    fontWeight: isCurrent
                        ? FontWeight.bold
                        : FontWeight.normal,
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
