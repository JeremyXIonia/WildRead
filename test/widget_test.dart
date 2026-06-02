import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wildread/app.dart';

void main() {
  testWidgets('App renders bookshelf page', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: WildReadApp()));
    await tester.pumpAndSettle();
    expect(find.text('书架'), findsOneWidget);
  });
}
