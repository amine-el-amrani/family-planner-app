import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:family_planner/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FamilyPlannerApp());
    expect(find.byType(MaterialApp), findsNothing); // uses MaterialApp.router
  });
}
