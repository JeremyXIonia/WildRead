import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wildread/models/rule.dart';
import 'package:wildread/providers/database_provider.dart';

final rulesProvider =
    AsyncNotifierProvider<RulesNotifier, List<Rule>>(RulesNotifier.new);

class RulesNotifier extends AsyncNotifier<List<Rule>> {
  @override
  Future<List<Rule>> build() async {
    final db = ref.read(databaseProvider);
    return db.getRules();
  }

  Future<void> saveRule(String name, String config) async {
    final db = ref.read(databaseProvider);
    final existing = await db.getRules();
    final match = existing.where((r) => r.name == name).toList();

    if (match.isNotEmpty) {
      await db.updateRule(Rule(
        id: match.first.id,
        name: name,
        config: config,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ));
    } else {
      await db.insertRule(Rule(
        name: name,
        config: config,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ));
    }
    ref.invalidateSelf();
  }

  Future<void> deleteRule(int id) async {
    final db = ref.read(databaseProvider);
    await db.deleteRule(id);
    ref.invalidateSelf();
  }
}
