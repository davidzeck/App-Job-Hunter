import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:job_scout/features/career/career_screen.dart';

/// The radar rows pack a name, a bar, a percentage and a status chip into one
/// line — this renders the real screen (demo mode) at a small phone width,
/// where an overflow would fail the test.
void main() {
  testWidgets('the market radar card renders at phone width', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: CareerScreen()));
    await tester.pump(const Duration(seconds: 1)); // mock API delays
    await tester.pump(const Duration(seconds: 1)); // fade-ins

    expect(find.text('What engineering roles ask for'), findsOneWidget);
    expect(find.textContaining('postings · 9 companies'), findsOneWidget);
    expect(find.textContaining('You cover'), findsOneWidget);
  });
}
