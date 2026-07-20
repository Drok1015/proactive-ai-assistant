import 'package:flutter_test/flutter_test.dart';

import 'package:proactive_ai_assistant/main.dart';

void main() {
  testWidgets('renders the proactive task tab', (WidgetTester tester) async {
    await tester.pumpWidget(const ProactiveAiApp());
    expect(find.text('主动任务'), findsOneWidget);
  });
}
