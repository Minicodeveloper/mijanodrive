// Test básico de humo para Mijano Drive.
import 'package:flutter_test/flutter_test.dart';
import 'package:mijano_drive_app/main.dart';

void main() {
  testWidgets('La app arranca sin crashear', (WidgetTester tester) async {
    await tester.pumpWidget(const MijanoDriveApp());
    expect(find.text('MIJANO DRIVE'), findsOneWidget);
  });
}
