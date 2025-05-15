import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:su_gym/main.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mockito/mockito.dart';

// Firebase'i mock için bir setup fonksiyonu
Future<void> setupFirebaseForTesting() async {
  // TestWidgetsFlutterBinding.ensureInitialized() çağrısı yapılmalı
  TestWidgetsFlutterBinding.ensureInitialized();

  // Firebase'i test için mocklamak gerekiyor
  await Firebase.initializeApp();
}

void main() {
  // Test öncesi Firebase mocklaması
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  testWidgets('Counter increments test', (WidgetTester tester) async {
    // Firebase Analytics mock'u oluştur
    final analytics = FirebaseAnalytics.instance;

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(analytics: analytics));

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
