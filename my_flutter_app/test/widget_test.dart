import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:job_scout/core/providers/auth_provider.dart';
import 'package:job_scout/core/theme/theme_provider.dart';
import 'package:job_scout/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ],
        child: const JobScoutApp(),
      ),
    );
    await tester.pump();
    // Splash screen shows app name
    expect(find.text('Job Scout'), findsOneWidget);
  });
}
