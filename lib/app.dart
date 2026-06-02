import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wildread/pages/bookshelf_page.dart';
import 'package:wildread/pages/add_book_page.dart';
import 'package:wildread/pages/reader_page.dart';
import 'package:wildread/pages/rules_page.dart';
import 'package:wildread/pages/rule_editor_page.dart';
import 'package:wildread/pages/toc_page.dart';

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

class WildReadApp extends ConsumerWidget {
  const WildReadApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'WildRead',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
