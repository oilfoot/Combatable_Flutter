import 'package:combatable_flutter/models/unity_step_indicator_state.dart';
import 'package:combatable_flutter/widgets/unity_step_indicator_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses normalized indicator data from Unity', () {
    final state = UnityStepIndicatorState.fromJson({
      'ready': true,
      'focused': true,
      'viewportStart': 0.2,
      'viewportEnd': 0.55,
      'focusedRangeKey': 'range-1',
      'contentKey': 'sequence-a',
      'transitionDuration': 0.44,
      'transitionCenter': 0.42,
      'transitionSpeed': 12,
      'markers': [
        {'key': 'step-1', 'position': 0.25},
        {'key': 'step-2', 'position': 0.75},
      ],
      'ranges': [
        {'key': 'range-1', 'start': 0.1, 'end': 0.6},
      ],
    });

    expect(state.ready, isTrue);
    expect(state.focused, isTrue);
    expect(state.viewportStart, 0.2);
    expect(state.viewportEnd, 0.55);
    expect(state.focusedRangeKey, 'range-1');
    expect(state.contentKey, 'sequence-a');
    expect(state.transitionDuration, 0.44);
    expect(state.transitionCenter, 0.42);
    expect(state.markers, hasLength(2));
    expect(state.markers.last.position, 0.75);
    expect(state.ranges.single.start, 0.1);
    expect(state.ranges.single.end, 0.6);
  });

  test('clamps malformed positions to the visible timeline', () {
    final state = UnityStepIndicatorState.fromJson({
      'transitionCenter': 2,
      'markers': [
        {'key': 'before', 'position': -1},
        {'key': 'after', 'position': 4},
      ],
      'ranges': [
        {'key': 'reversed', 'start': 0.8, 'end': 0.2},
      ],
    });

    expect(state.transitionCenter, 1);
    expect(state.markers.first.position, 0);
    expect(state.markers.last.position, 1);
    expect(state.ranges.single.start, 0.8);
    expect(state.ranges.single.end, 0.8);
  });

  testWidgets('renders the indicator overlay inside the timeline bounds', (
    tester,
  ) async {
    const state = UnityStepIndicatorState(
      ready: true,
      markers: [UnityStepIndicatorMarker(key: 'step', position: 0.5)],
      ranges: [UnityStepIndicatorRange(key: 'range', start: 0.1, end: 0.9)],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 16,
            child: UnityStepIndicatorOverlay(state: state),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('animates between full and focused timeline viewports', (
    tester,
  ) async {
    const fullState = UnityStepIndicatorState(
      ready: true,
      markers: [
        UnityStepIndicatorMarker(key: 'left', position: 0.1),
        UnityStepIndicatorMarker(key: 'focus-start', position: 0.4),
        UnityStepIndicatorMarker(key: 'focus-end', position: 0.7),
      ],
      ranges: [UnityStepIndicatorRange(key: 'focused', start: 0.4, end: 0.7)],
    );
    final focusedState = UnityStepIndicatorState(
      ready: true,
      focused: true,
      viewportStart: 0.4,
      viewportEnd: 0.7,
      focusedRangeKey: 'focused',
      markers: fullState.markers,
      ranges: fullState.ranges,
    );

    Widget subject(UnityStepIndicatorState state) {
      return MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 16,
            child: UnityStepIndicatorOverlay(state: state),
          ),
        ),
      );
    }

    await tester.pumpWidget(subject(fullState));
    await tester.pumpWidget(subject(focusedState));
    await tester.pump(const Duration(milliseconds: 170));
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('scope markers follow Unity timeline in screen space', (
    tester,
  ) async {
    const markerPosition = 0.55;
    const fullState = UnityStepIndicatorState(
      ready: true,
      markers: [
        UnityStepIndicatorMarker(key: 'current', position: markerPosition),
      ],
    );
    const focusedState = UnityStepIndicatorState(
      ready: true,
      focused: true,
      viewportStart: 0.4,
      viewportEnd: 0.7,
      transitionDuration: 0.42,
      markers: [
        UnityStepIndicatorMarker(key: 'current', position: markerPosition),
      ],
    );

    Widget subject(UnityStepIndicatorState state) {
      return MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 16,
            child: UnityStepIndicatorOverlay(state: state),
          ),
        ),
      );
    }

    await tester.pumpWidget(subject(fullState));
    await tester.pumpAndSettle();
    await tester.pumpWidget(subject(focusedState));
    await tester.pump(const Duration(milliseconds: 210));

    final overlay = find.byType(UnityStepIndicatorOverlay);
    final paintFinder = find.descendant(
      of: overlay,
      matching: find.byType(CustomPaint),
    );
    final customPaint = tester.widget<CustomPaint>(paintFinder);
    final dynamic painter = customPaint.painter;
    final viewportStart = painter.viewportStart as double;
    final viewportEnd = painter.viewportEnd as double;
    final displayedPosition =
        (markerPosition - viewportStart) / (viewportEnd - viewportStart);

    // Unity moves from 0.55 to the focused 0.50 position. At half of the
    // shared ease-in-out transition, Flutter must therefore also be at 0.525.
    expect(displayedPosition, closeTo(0.525, 0.001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not restart scope-in for a duplicate rebuilt target', (
    tester,
  ) async {
    const markers = [
      UnityStepIndicatorMarker(key: 'left', position: 0.1),
      UnityStepIndicatorMarker(key: 'focus-start', position: 0.4),
      UnityStepIndicatorMarker(key: 'focus-end', position: 0.7),
    ];
    const ranges = [
      UnityStepIndicatorRange(key: 'focused', start: 0.4, end: 0.7),
    ];
    const fullState = UnityStepIndicatorState(
      ready: true,
      contentKey: 'sequence',
      markers: markers,
      ranges: ranges,
    );
    const focusedState = UnityStepIndicatorState(
      ready: true,
      focused: true,
      viewportStart: 0.4,
      viewportEnd: 0.7,
      contentKey: 'sequence',
      markers: markers,
      ranges: ranges,
    );
    const rebuiltFocusedState = UnityStepIndicatorState(
      ready: true,
      focused: true,
      viewportStart: 0.4,
      viewportEnd: 0.7,
      contentKey: 'sequence-after-local-clip-rebuild',
      markers: markers,
      ranges: ranges,
    );

    Widget subject(UnityStepIndicatorState state) {
      return MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 16,
            child: UnityStepIndicatorOverlay(state: state),
          ),
        ),
      );
    }

    await tester.pumpWidget(subject(fullState));
    await tester.pumpWidget(subject(focusedState));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(subject(rebuiltFocusedState));
    await tester.pump(const Duration(milliseconds: 340));

    final overlay = find.byType(UnityStepIndicatorOverlay);
    final paintFinder = find.descendant(
      of: overlay,
      matching: find.byType(CustomPaint),
    );
    final customPaint = tester.widget<CustomPaint>(paintFinder);
    final dynamic painter = customPaint.painter;

    expect(painter.viewportStart as double, closeTo(0.4, 0.001));
    expect(painter.viewportEnd as double, closeTo(0.7, 0.001));
    expect(tester.takeException(), isNull);
  });
}
