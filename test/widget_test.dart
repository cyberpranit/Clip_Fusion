import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clip_fusion/main.dart';

void main() {
  testWidgets('ClipFusion App Smoke Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // Verify that the title 'ClipFusion' is displayed.
    expect(find.text('ClipFusion'), findsOneWidget);

    // Verify that the bottom navigation bar has the correct tabs.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('WhatsApp'), findsNWidgets(2));
  });
}
