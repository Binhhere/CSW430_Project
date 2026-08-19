import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:relay_av_demo/app/relay_ui.dart';
import 'package:relay_av_demo/app/theme.dart';
import 'package:relay_av_demo/shared/ledger_widgets.dart';

void main() {
  test('relay breakpoints classify operational window sizes consistently', () {
    expect(RelayAdaptiveSize.fromWidth(599), RelayWindowSize.compact);
    expect(RelayAdaptiveSize.fromWidth(600), RelayWindowSize.medium);
    expect(RelayAdaptiveSize.fromWidth(839), RelayWindowSize.medium);
    expect(RelayAdaptiveSize.fromWidth(840), RelayWindowSize.expanded);
    expect(
      RelayAdaptiveSize.fromWidth(1024),
      RelayWindowSize.largeProductivity,
    );
  });

  test('relayRoute returns the shared page route wrapper', () {
    final route =
        relayRoute<void>(
              fullscreenDialog: true,
              builder: (_) => const Placeholder(),
            )
            as RelayPageRoute<void>;

    expect(route, isA<RelayPageRoute<void>>());
    expect(route.fullscreenDialog, isTrue);
  });

  testWidgets('relay press feedback suppresses scale in reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        size: const Size(390, 844),
        disableAnimations: true,
        child: const Center(
          child: RelayPressScale(child: SizedBox(width: 80, height: 40)),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(SizedBox).first),
    );
    await tester.pump();

    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 1);
    expect(scale.duration, Duration.zero);

    await gesture.up();
  });

  testWidgets(
    'relay adaptive list detail switches layouts by productivity width',
    (tester) async {
      await tester.pumpWidget(
        _host(
          size: const Size(800, 900),
          child: const RelayAdaptiveListDetail(
            listPane: Text('List pane'),
            detailPane: Text('Detail pane'),
          ),
        ),
      );

      expect(find.text('List pane'), findsOneWidget);
      expect(find.text('Detail pane'), findsNothing);

      await tester.pumpWidget(
        _host(
          size: const Size(1200, 900),
          child: const RelayAdaptiveListDetail(
            listPane: Text('List pane'),
            detailPane: Text('Detail pane'),
          ),
        ),
      );

      expect(find.text('List pane'), findsOneWidget);
      expect(find.text('Detail pane'), findsOneWidget);
    },
  );

  testWidgets(
    'relay adaptive list detail preserves list and selection state across resize',
    (tester) async {
      final size = ValueNotifier<Size>(const Size(1200, 900));

      await tester.pumpWidget(_AdaptiveHarness(size: size));

      await tester.enterText(find.byType(TextField), 'serialized mixer');
      await tester.tap(find.text('Select item'));
      await tester.pumpAndSettle();

      expect(find.text('serialized mixer'), findsOneWidget);
      expect(find.text('Detail: selected'), findsOneWidget);

      size.value = const Size(500, 900);
      await tester.pumpAndSettle();

      expect(find.text('serialized mixer'), findsOneWidget);
      expect(find.text('Detail: selected'), findsNothing);

      size.value = const Size(1200, 900);
      await tester.pumpAndSettle();

      expect(find.text('serialized mixer'), findsOneWidget);
      expect(find.text('Detail: selected'), findsOneWidget);
    },
  );
}

Widget _host({
  required Size size,
  required Widget child,
  bool disableAnimations = false,
}) => MaterialApp(
  theme: relayLightTheme(),
  home: MediaQuery(
    data: MediaQueryData(size: size, disableAnimations: disableAnimations),
    child: Scaffold(body: child),
  ),
);

class _AdaptiveHarness extends StatefulWidget {
  const _AdaptiveHarness({required this.size});

  final ValueNotifier<Size> size;

  @override
  State<_AdaptiveHarness> createState() => _AdaptiveHarnessState();
}

class _AdaptiveHarnessState extends State<_AdaptiveHarness> {
  final _controller = TextEditingController();
  bool _selected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Size>(
    valueListenable: widget.size,
    builder: (context, size, _) => MaterialApp(
      theme: relayLightTheme(),
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(
          body: RelayAdaptiveListDetail(
            listPane: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(controller: _controller),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => setState(() => _selected = true),
                  child: const Text('Select item'),
                ),
              ],
            ),
            detailPane: _selected ? const Text('Detail: selected') : null,
          ),
        ),
      ),
    ),
  );
}
