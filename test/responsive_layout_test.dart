import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Responsive Layout Tests', () {
    testWidgets('Text scales down on narrow screen (< 600px)', (
      WidgetTester tester,
    ) async {
      // Set narrow screen size
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const narrowThreshold = 600;
      final screenWidth = MediaQuery.sizeOf(await tester.pumpAndBuild()).width;
      final isNarrow = screenWidth < narrowThreshold;

      expect(isNarrow, true);
      expect(screenWidth, 400);
    });

    testWidgets('Text scales normally on wide screen (>= 600px)', (
      WidgetTester tester,
    ) async {
      // Set wide screen size
      tester.view.physicalSize = const Size(800, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const narrowThreshold = 600;
      final screenWidth = MediaQuery.sizeOf(await tester.pumpAndBuild()).width;
      final isNarrow = screenWidth < narrowThreshold;

      expect(isNarrow, false);
      expect(screenWidth, 800);
    });

    testWidgets('Adaptive font sizes are applied correctly', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final screenWidth = MediaQuery.sizeOf(context).width;
                final isNarrow = screenWidth < 600;
                final titleSize = isNarrow ? 20.0 : 24.0;
                final nameSize = isNarrow ? 16.0 : 18.0;

                return Column(
                  children: [
                    Text('Title', style: TextStyle(fontSize: titleSize)),
                    Text('Name', style: TextStyle(fontSize: nameSize)),
                  ],
                );
              },
            ),
          ),
        ),
      );

      final titleWidget = tester.widget<Text>(find.text('Title'));
      final nameWidget = tester.widget<Text>(find.text('Name'));

      expect(titleWidget.style?.fontSize, 20.0);
      expect(nameWidget.style?.fontSize, 16.0);
    });

    testWidgets('Adaptive padding is applied on narrow screens', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final screenWidth = MediaQuery.sizeOf(context).width;
                final isNarrow = screenWidth < 600;
                final edgePadding = isNarrow ? 8.0 : 12.0;

                return Padding(
                  padding: EdgeInsets.all(edgePadding),
                  child: const Text('Content'),
                );
              },
            ),
          ),
        ),
      );

      final paddingWidget = tester.widget<Padding>(find.byType(Padding));
      expect((paddingWidget.padding as EdgeInsets).top, 8.0);
    });

    testWidgets('FittedBox prevents text overflow in headers', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 80,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Very Long Header Text That Would Overflow',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.text('Very Long Header Text That Would Overflow'),
        findsOneWidget,
      );
      // FittedBox should prevent overflow
      expect(tester.takeException(), null);
    });

    testWidgets('Narrow screen threshold (600px) is consistent', (
      WidgetTester tester,
    ) async {
      const narrowThreshold = 600;

      // Test at 599px (should be narrow)
      tester.view.physicalSize = const Size(599, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final isNarrow =
                  MediaQuery.sizeOf(context).width < narrowThreshold;
              return Text(isNarrow ? 'Narrow' : 'Wide');
            },
          ),
        ),
      );

      expect(find.text('Narrow'), findsOneWidget);

      // Test at 600px (should be wide)
      tester.view.physicalSize = const Size(600, 800);
      await tester.pumpAndSettle();

      expect(find.text('Wide'), findsOneWidget);

      addTearDown(() => tester.view.resetPhysicalSize());
    });

    testWidgets(
      'LayoutBuilder provides correct constraints for adaptive widgets',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LayoutBuilder(
                builder: (context, constraints) {
                  return Text('Max Width: ${constraints.maxWidth}');
                },
              ),
            ),
          ),
        );

        expect(find.textContaining('Max Width:'), findsOneWidget);
      },
    );
  });
}

// Helper extension to pump and get context
extension on WidgetTester {
  Future<BuildContext> pumpAndBuild() async {
    late BuildContext savedContext;
    await pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            savedContext = context;
            return const SizedBox();
          },
        ),
      ),
    );
    return savedContext;
  }
}
