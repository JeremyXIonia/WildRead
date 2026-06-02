import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wildread/engine/rule_engine.dart';
import 'package:wildread/providers/rules_provider.dart';

class RuleEditorPage extends ConsumerStatefulWidget {
  final String ruleId;
  const RuleEditorPage({super.key, required this.ruleId});

  @override
  ConsumerState<RuleEditorPage> createState() => _RuleEditorPageState();
}

class _RuleEditorPageState extends ConsumerState<RuleEditorPage> {
  final _nameController = TextEditingController();
  final _configController = TextEditingController();
  String? _validationError;
  final _engine = RuleEngine();

  bool get _isEditing => widget.ruleId != 'new';

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadRule();
    }
  }

  Future<void> _loadRule() async {
    final rules = ref.read(rulesProvider).value ?? [];
    final rule =
        rules.where((r) => r.id.toString() == widget.ruleId).firstOrNull;
    if (rule != null) {
      _nameController.text = rule.name;
      _configController.text = rule.config;
    }
  }

  void _validate() {
    final error = _engine.validate(_configController.text);
    setState(() => _validationError = error.isEmpty ? null : error);
    if (error.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('规则校验通过'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final config = _configController.text.trim();
    if (name.isEmpty) {
      setState(() => _validationError = '请输入规则名称');
      return;
    }
    final error = _engine.validate(config);
    if (error.isNotEmpty) {
      setState(() => _validationError = error);
      return;
    }
    try {
      await ref.read(rulesProvider.notifier).saveRule(name, config);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _validationError = '保存失败: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _configController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑规则' : '新建规则'),
        actions: [
          TextButton(
            onPressed: _save,
            child:
                const Text('保存', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '规则名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _configController,
                decoration: InputDecoration(
                  labelText: 'JSON 配置',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                  errorText: _validationError,
                ),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _validate,
              icon: const Icon(Icons.check),
              label: const Text('校验 JSON'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
