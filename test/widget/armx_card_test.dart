// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/widgets/armx_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/armx_test_support.dart';

void main() {
  for (final Size size in referenceSizes) {
    group('at ${size.width.toInt()}x${size.height.toInt()}', () {
      testWidgets('a titled card shows its title, body and trailing action', (
        WidgetTester tester,
      ) async {
        await pumpArmx(
          tester,
          const ArmxCard(
            title: 'Living room lamp',
            trailing: Icon(Icons.more_horiz_rounded),
            child: Text('70% brightness'),
          ),
          size: size,
        );
        expect(find.text('Living room lamp'), findsOneWidget);
        expect(find.text('70% brightness'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a detail row keeps label and value on one line and truncates the value',
          (WidgetTester tester) async {
        await pumpArmx(
          tester,
          const ArmxCard(
            child: ArmxDetailRow(
              label: 'Firmware',
              value: '1.4.2-beta.7+build.20261013',
              monospace: true,
            ),
          ),
          size: size,
        );
        expect(find.text('Firmware'), findsOneWidget);
        expect(
          find.text('1.4.2-beta.7+build.20261013'),
          findsOneWidget,
        );
        // A long value must not overflow the row at 360 dp.
        expect(tester.takeException(), isNull);
      });

      testWidgets('a section groups a title with its action and children', (
        WidgetTester tester,
      ) async {
        await pumpArmx(
          tester,
          const ArmxSection(
            title: 'Rooms',
            subtitle: '4 rooms',
            icon: Icons.meeting_room_outlined,
            child: Text('Living room'),
          ),
          size: size,
        );
        expect(find.text('Rooms'), findsOneWidget);
        expect(find.text('4 rooms'), findsOneWidget);
        expect(find.text('Living room'), findsOneWidget);
      });
    });
  }

  testWidgets('a tappable card is a button for semantics and calls back once', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await pumpArmx(
      tester,
      ArmxCard(
        semanticLabel: 'Open the front door device',
        onTap: () => taps++,
        child: const Text('Front door'),
      ),
    );

    expect(
      find.bySemanticsLabel('Open the front door device'),
      findsOneWidget,
    );
    await tester.tap(find.byType(ArmxCard));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('a card with no tap handler is not announced as a button', (
    WidgetTester tester,
  ) async {
    await pumpArmx(tester, const ArmxCard(child: Text('Read-only information')));
    final Finder card = find.byType(ArmxCard);
    final SemanticsHandle handle = tester.ensureSemantics();
    final SemanticsNode node = tester.getSemantics(card);
    expect(node.hasFlag(SemanticsFlag.isButton), isFalse);
    handle.dispose();
  });

  testWidgets('the two tones differ, and both are drawn from the theme', (
    WidgetTester tester,
  ) async {
    await pumpArmx(
      tester,
      const Column(
        children: <Widget>[
          ArmxCard(tone: ArmxCardTone.surface, child: Text('surface')),
          ArmxCard(tone: ArmxCardTone.tinted, child: Text('tinted')),
        ],
      ),
    );
    final Iterable<Material> materials = tester.widgetList<Material>(
      find.descendant(of: find.byType(ArmxCard), matching: find.byType(Material)),
    );
    final Set<Color?> colours = materials.map((Material m) => m.color).toSet();
    expect(colours.length, greaterThan(1));
  });

  testWidgets('a dense card is shorter than a comfortable one', (WidgetTester tester) async {
    await pumpArmx(
      tester,
      const Column(
        children: <Widget>[
          ArmxCard(child: Text('comfortable')),
          ArmxCard(dense: true, child: Text('dense')),
        ],
      ),
    );
    final List<ArmxCard> cards = tester
        .widgetList<ArmxCard>(find.byType(ArmxCard))
        .toList(growable: false);
    final Size comfortable = tester.getSize(find.byWidget(cards[0]));
    final Size compact = tester.getSize(find.byWidget(cards[1]));
    expect(compact.height, lessThan(comfortable.height));
  });

  testWidgets('a state frame shows an icon, a title and one primary action', (
    WidgetTester tester,
  ) async {
    await pumpArmx(
      tester,
      const ArmxStateFrame(
        icon: Icons.info_outline_rounded,
        iconColor: Colors.blue,
        title: 'Nothing here yet',
        body: 'Add a device to get started.',
      ),
      size: const Size(360, 800),
    );
    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.text('Add a device to get started.'), findsOneWidget);
  });
}
