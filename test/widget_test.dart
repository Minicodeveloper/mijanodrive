import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mijano_drive_app/main.dart';

void main() {
  testWidgets('La app muestra la pantalla inicial sin crashear',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MijanoDriveApp());

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Retiramos la pantalla antes de que intente navegar al login.
    await tester.pumpWidget(const SizedBox.shrink());

    // Dejamos finalizar el temporizador de 3 segundos.
    await tester.pump(const Duration(seconds: 3));
  });
}