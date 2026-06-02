import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wildread/database/database_helper.dart';

final databaseProvider = Provider<DatabaseHelper>((ref) {
  final db = DatabaseHelper();
  ref.onDispose(() => db.close());
  return db;
});
