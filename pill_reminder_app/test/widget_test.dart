import 'package:flutter_test/flutter_test.dart';
import 'package:pill_reminder_app/main.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PillReminderApp());

    // Verify app title is present
    expect(find.text("Today's Reminders"), findsOneWidget);
  });
}
