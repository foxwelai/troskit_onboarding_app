import 'package:flutter_test/flutter_test.dart';
import 'package:troskit_onboarding_app/main.dart';

void main() {
  testWidgets('TroskitOnboardingApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TroskitOnboardingApp());
    expect(find.byType(TroskitOnboardingApp), findsOneWidget);
  });
}
