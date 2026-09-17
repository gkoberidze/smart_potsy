// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:smart_potsy/core/constants/app_strings.dart';
import 'package:smart_potsy/core/services/api_service.dart';
import 'package:smart_potsy/core/services/auth_service.dart';
import 'package:smart_potsy/features/settings/screens/settings_screen.dart';
import 'package:smart_potsy/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartPotsyApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Settings screen renders without layout errors', (
    WidgetTester tester,
  ) async {
    final apiService = ApiService();
    final authService = AuthService(apiService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiService>.value(value: apiService),
          ChangeNotifierProvider<AuthService>.value(value: authService),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    expect(find.text('პარამეტრები'), findsOneWidget);
  });

  test('English status labels use correct words', () {
    expect(AppStrings.online, 'online');
    expect(AppStrings.offline, 'offline');
  });
}
