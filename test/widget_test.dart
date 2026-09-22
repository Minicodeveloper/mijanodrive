// Test básico de humo para Mijano Drive.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mijano_drive_app/main.dart';

void main() {
  testWidgets('La app arranca sin crashear', (WidgetTester tester) async {
    await tester.pumpWidget(const MijanoDriveApp());
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Como Pasajero'), findsOneWidget);
  });
}
