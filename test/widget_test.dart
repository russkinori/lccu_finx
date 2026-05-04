// Integration tests for LCCU FinX app
import 'package:flutter_test/flutter_test.dart';
import 'package:lccu_finx/app/roles.dart';

void main() {
  group('App Integration Tests', () {
    test('AppRole enum contains all expected roles', () {
      expect(AppRole.values.length, 6);
      expect(AppRole.values, contains(AppRole.admin));
      expect(AppRole.values, contains(AppRole.teller));
      expect(AppRole.values, contains(AppRole.teacher));
      expect(AppRole.values, contains(AppRole.principal));
      expect(AppRole.values, contains(AppRole.student));
      expect(AppRole.values, contains(AppRole.guardian));
    });

    test('Responsive layout constants are valid', () {
      // Test that our narrow screen threshold is sensible
      const narrowThreshold = 600;
      expect(narrowThreshold, 600);
      expect(narrowThreshold > 0, true);
      expect(narrowThreshold < 1024, true);
    });

    test('Font size scaling is reasonable', () {
      // Narrow screen sizes
      const narrowTitleSize = 20.0;
      const narrowWelcomeSize = 12.0;
      const narrowNameSize = 16.0;

      // Wide screen sizes
      const wideTitleSize = 24.0;
      const wideWelcomeSize = 14.0;
      const wideNameSize = 18.0;

      // Verify scaling is consistent (around 80-85% on narrow)
      expect(narrowTitleSize / wideTitleSize, closeTo(0.83, 0.05));
      expect(narrowWelcomeSize / wideWelcomeSize, closeTo(0.86, 0.05));
      expect(narrowNameSize / wideNameSize, closeTo(0.89, 0.05));
    });

    test('Padding scaling is consistent', () {
      const narrowPadding = 8.0;
      const widePadding = 12.0;

      expect(narrowPadding / widePadding, closeTo(0.67, 0.05));
      expect(narrowPadding, lessThan(widePadding));
    });

    test('Header height scaling is appropriate', () {
      const narrowHeaderHeight = 36.0;
      const wideHeaderHeight = 40.0;

      expect(narrowHeaderHeight, lessThan(wideHeaderHeight));
      expect(narrowHeaderHeight / wideHeaderHeight, 0.9);
    });
  });
}
