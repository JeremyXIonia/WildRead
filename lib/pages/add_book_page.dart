import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wildread/engine/content_fetcher.dart';
import 'package:wildread/providers/books_provider.dart';
import 'package:wildread/providers/rules_provider.dart';

class AddBookPage extends ConsumerStatefulWidget {
  const AddBookPage({super.key});

  @override
  ConsumerState<AddBookPage> createState() => _AddBookPageState();
}

class _AddBookPageState extends ConsumerState<AddBookPage> {
  final _urlController = TextEditingController();
  String? _selectedRule;
  bool _isFetching = false;
  String? _error;
  String? _debugInfo;
  BookInfo? _preview;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetchPreview() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || _selectedRule == null) {
      setState(() => _error = '请输入 URL 并选择规则');
      return;
    }

    setState(() {
      _isFetching = true;
      _error = null;
      _preview = null;
      _debugInfo = null;
    });

    try {
      final rules = ref.read(rulesProvider).value ?? [];
      final ruleJson =
          rules.firstWhere((r) => r.name == _selectedRule).config;
      final rule = ref.read(ruleEngineProvider).parse(ruleJson);
      final fetcher = ref.read(contentFetcherProvider);

      // Enable debug mode
      fetcher.debugMode = true;
      fetcher.debug = FetchDebug();

      final info = await fetcher.fetchBookInfo(url, rule);
      setState(() {
        _preview = info;
        _debugInfo = fetcher.debug?.summarize();
      });
    } catch (e) {
      final fetcher = ref.read(contentFetcherProvider);
      setState(() {
        _error = '抓取失败: $e';
        _debugInfo = fetcher.debug?.summarize();
      });
    } finally {
      setState(() => _isFetching = false);
    }
  }

  Future<void> _addToBookshelf() async {
    if (_preview == null) return;
    try {
      await ref.read(booksProvider.notifier).addBook(
            _urlController.text.trim(),
            _selectedRule!,
          );
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = '添加失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(rulesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('添加图书')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: '图书详情页 URL',
                hintText: 'https://...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),

            rulesAsync.when(
              data: (rules) => DropdownButtonFormField<String>(
                initialValue: _selectedRule,
                decoration: const InputDecoration(
                  labelText: '选择规则',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.rule),
                ),
                hint: const Text('选择网站适配规则'),
                items: rules
                    .map((r) => DropdownMenuItem(
                        value: r.name, child: Text(r.name)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedRule = v),
              ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('加载规则失败: $e'),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _isFetching ? null : _fetchPreview,
              icon: const Icon(Icons.search),
              label: const Text('抓取预览'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 16),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    Text(_error!, style: const TextStyle(color: Colors.red)),
              ),

            if (_isFetching)
              const Center(child: CircularProgressIndicator()),

            // Debug panel
            if (_debugInfo != null && _debugInfo!.isNotEmpty)
              _DebugPanel(info: _debugInfo!),

            if (_preview != null) ...[
              const Divider(height: 32),
              Text('书名: ${_preview!.title}',
                  style: Theme.of(context).textTheme.titleLarge),
              if (_preview!.author != null)
                Text('作者: ${_preview!.author}'),
              if (_preview!.description != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_preview!.description!,
                      maxLines: 5, overflow: TextOverflow.ellipsis),
                ),
              if (_preview!.chapters.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('共 ${_preview!.chapters.length} 章'),
                ),
              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: _addToBookshelf,
                icon: const Icon(Icons.add),
                label: const Text('加入书架'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DebugPanel extends StatelessWidget {
  final String info;
  const _DebugPanel({required this.info});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      color: Colors.grey.shade900,
      child: ExpansionTile(
        title: const Text('🔍 调试信息',
            style: TextStyle(color: Colors.greenAccent, fontSize: 14)),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              info,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
