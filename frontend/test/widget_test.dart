import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('App uses TerraWise as application title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TerraWiseApp());

    final materialApp = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );

    expect(materialApp.title, 'TerraWise');
  });
}