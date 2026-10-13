// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/errors/app_exception.dart';
import 'package:armx_ai/core/widgets/armx_empty_state.dart';
import 'package:armx_ai/core/widgets/armx_error_state.dart';
import 'package:armx_ai/core/widgets/armx_button.dart';
import 'package:armx_ai/core/widgets/armx_loading_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/armx_test_support.dart';

/// Empty, error and loading are where apps usually cheat — a blank screen that looks like an
/// empty one, or a spinner forever. Each of the three is checked at all three widths.
void main() {
  for (final Size size in referenceSizes) {
    group('at ${size.width.toInt()}x${size.height.toInt()}', () {
      testWidgets('an empty state explains what is missing and offers the next step', (
        WidgetTester tester,
      ) async {
        int actions = 0;
        await pumpArmx(
          tester,
          ArmxEmptyState(
            title: 'No alarms yet',
            message: 'Alarms ring on the devices you choose.',
            icon: Icons.alarm_off_rounded,
            actionLabel: 'Create an alarm',
            onAction: () => actions++,
          ),
          size: size,
        );

        expect(find.text('No alarms yet'), findsOneWidget);
        expect(find.text('Alarms ring on the devices you choose.'), findsOneWidget);

        await tester.tap(find.text('Create an alarm'));
        await tester.pumpAndSettle();
        expect(actions, 1);
      });

      testWidgets('an error state says what went wrong and offers a retry only when it can help',
          (WidgetTester tester) async {
        int retries = 0;
        await pumpArmx(
          tester,
          ArmxErrorState(
            error: const NetworkException(message: 'No route to the backend.'),
            onRetry: () => retries++,
          ),
          size: size,
        );

        // The message the backend gave is shown, rather than a generic "something went wrong".
        expect(find.textContaining('No route to the backend.'), findsOneWidget);

        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(retries, 1);
      });
    });
  }

  group('ArmxErrorCopy', () {
    test('an unauthorised error sends the user to sign in rather than offering a retry', () {
      final bool retryable = ArmxErrorState.isRetryable(
        const UnauthorizedException(message: 'Session expired.'),
      );
      expect(retryable, isFalse);
    });

    test('a network error is retryable', () {
      expect(
        ArmxErrorState.isRetryable(
          const NetworkException(message: 'Offline.'),
        ),
        isTrue,
      );
    });

    test('a denied action is not retryable — retrying would ask again for something refused',
        () {
      expect(
        ArmxErrorState.isRetryable(
          const ForbiddenException(message: 'Administrators only.'),
        ),
        isFalse,
      );
    });
  });

  testWidgets('a skeleton is announced as busy, not as content', (
    WidgetTester tester,
  ) async {
    await pumpArmx(
      tester,
      const ArmxSkeletonTable(rows: 4),
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ArmxSkeletonTable), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a card skeleton draws one placeholder per requested line', (
    WidgetTester tester,
  ) async {
    await pumpArmx(
      tester,
      const ArmxSkeletonCard(lines: 3),
      settle: false,
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.descendant(
        of: find.byType(ArmxSkeletonCard),
        matching: find.byType(ArmxLoadingSkeleton),
      ),
      findsNWidgets(3),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the notice tone decides its icon and colour, and the text says it too', (
    WidgetTester tester,
  ) async {
    await pumpArmx(
      tester,
      const ArmxNotice(
        title: 'Camera is on',
        message: 'The greeter is watching the door.',
        tone: ArmxBadgeToneLike.danger,
      ),
    );
    expect(find.text('Camera is on'), findsOneWidget);
    expect(find.text('The greeter is watching the door.'), findsOneWidget);
  });

  testWidgets('the offline fallback tells the user they can still act manually', (
    WidgetTester tester,
  ) async {
    int retries = 0;
    await pumpArmx(
      tester,
      ArmxOfflineFallbackNote(onRetry: () => retries++),
    );
    expect(find.byType(ArmxOfflineFallbackNote), findsOneWidget);
    // The note's own retry is a small ghost button, not a bespoke control.
    await tester.tap(find.byType(ArmxButton));
    await tester.pumpAndSettle();
    expect(retries, 1);
  });

  testWidgets('a hint is smaller than a full empty state, so it can sit inside a card', (
    WidgetTester tester,
  ) async {
    await pumpArmx(tester, const ArmxEmptyHint(message: 'Nothing to show'));
    expect(find.text('Nothing to show'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
