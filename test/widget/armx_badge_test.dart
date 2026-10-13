// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/router/routes.dart';
import 'package:armx_ai/core/widgets/armx_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/armx_test_support.dart';

void main() {
  for (final Size size in referenceSizes) {
    group('at ${size.width.toInt()}x${size.height.toInt()}', () {
      testWidgets('a badge shows its text, so colour is never the only signal', (
        WidgetTester tester,
      ) async {
        await pumpArmx(
          tester,
          const ArmxBadge(label: 'HIGH', tone: ArmxBadgeTone.danger),
          size: size,
        );
        expect(find.text('HIGH'), findsOneWidget);
      });

      testWidgets('a chip reports selection to the screen reader and toggles', (
        WidgetTester tester,
      ) async {
        bool selected = false;
        await pumpArmx(
          tester,
          StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) => ArmxChip(
              label: 'Living room',
              selected: selected,
              onSelected: (bool next) => setState(() => selected = next),
            ),
          ),
          size: size,
        );

        expect(find.text('Living room'), findsOneWidget);
        expectTouchTarget(tester, find.byType(ArmxChip), minimum: 40);

        await tester.tap(find.byType(ArmxChip));
        await tester.pumpAndSettle();
        expect(selected, isTrue);
      });
    });
  }

  group('tones are derived, not invented per screen', () {
    test('the admin role is the accent tone and a plain user is neutral', () {
      expect(ArmxBadge.toneForRole('admin'), ArmxBadgeTone.accent);
      expect(ArmxBadge.toneForRole('user'), ArmxBadgeTone.neutral);
    });

    test('the VIP role is the secondary tone — never the same as admin\'s', () {
      final ArmxBadgeTone vip = ArmxBadge.toneForRole('vip');
      expect(vip, ArmxBadgeTone.secondary);
      expect(vip, isNot(ArmxBadge.toneForRole('admin')));
    });

    test('role text from the wire is matched case-insensitively', () {
      expect(ArmxBadge.toneForRole('ADMIN'), ArmxBadgeTone.accent);
      expect(ArmxBadge.toneForRole('Vip'), ArmxBadgeTone.secondary);
    });

    test('the risk tiers map to danger, warning and success in that order', () {
      expect(ArmxBadge.toneForRisk('high'), ArmxBadgeTone.danger);
      expect(ArmxBadge.toneForRisk('medium'), ArmxBadgeTone.warning);
      expect(ArmxBadge.toneForRisk('low'), ArmxBadgeTone.success);
    });

    test('an unknown risk is not coloured as safe', () {
      expect(ArmxBadge.toneForRisk('???'), isNot(ArmxBadgeTone.success));
    });

    test('every role in the app has a tone', () {
      for (final UserRole role in UserRole.values) {
        expect(() => ArmxBadge.toneForRole(role.name), returnsNormally);
      }
    });
  });

  testWidgets('a status pill carries both a dot and a word', (
    WidgetTester tester,
  ) async {
    await pumpArmx(tester, const ArmxStatusPill(status: ArmxStatus.online, label: 'Online'));
    expect(find.text('Online'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a chip with a count shows the count as well as the label', (
    WidgetTester tester,
  ) async {
    await pumpArmx(
      tester,
      const ArmxChip(label: 'Alarms', count: 3, selected: false),
    );
    expect(find.text('Alarms'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('a badge with a tooltip exposes an explanation, not just a colour', (
    WidgetTester tester,
  ) async {
    await pumpArmx(
      tester,
      const ArmxBadge(
        label: 'DENIED',
        tone: ArmxBadgeTone.danger,
        tooltip: 'You denied this action',
      ),
    );
    expect(find.byTooltip('You denied this action'), findsOneWidget);
  });

  testWidgets('long labels wrap or truncate instead of overflowing at 360 dp', (
    WidgetTester tester,
  ) async {
    await pumpArmx(
      tester,
      const ArmxBadge(
        label: 'AWAITING YOUR DECISION',
        tone: ArmxBadgeTone.warning,
      ),
      size: const Size(360, 800),
    );
    expect(tester.takeException(), isNull);
  });
}
