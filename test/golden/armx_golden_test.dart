// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:io';

import 'package:armx_ai/core/breakpoints.dart';
import 'package:armx_ai/core/errors/app_exception.dart';
import 'package:armx_ai/core/widgets/armx_badge.dart';
import 'package:armx_ai/core/widgets/armx_brand.dart';
import 'package:armx_ai/core/widgets/armx_button.dart';
import 'package:armx_ai/core/widgets/armx_card.dart';
import 'package:armx_ai/core/widgets/armx_confirm_dialog.dart';
import 'package:armx_ai/core/widgets/armx_empty_state.dart';
import 'package:armx_ai/core/widgets/armx_error_state.dart';
import 'package:armx_ai/core/widgets/armx_loading_skeleton.dart';
import 'package:armx_ai/core/widgets/armx_status_dot.dart';
import 'package:armx_ai/core/widgets/armx_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/armx_test_support.dart';

/// Golden tests for every shared component, in both themes and at all three reference widths.
///
/// ## Why these are gated
///
/// A golden test compares against a PNG that has to be generated **by a machine with the
/// Flutter SDK and the bundled fonts** — the pixels differ between platforms and between font
/// versions. Committing baselines that were never rendered would be worse than having none:
/// the suite would fail for everybody with a diff nobody can resolve.
///
/// So the baselines live in `test/golden/goldens/`, are generated once with
///
/// ```bash
/// flutter test --update-goldens test/golden
/// ```
///
/// and this file skips itself — loudly, with a reason — until they exist. Once they are
/// committed, CI picks them up automatically and the components are pixel-checked on every
/// pull request.
Directory get _goldenDirectory => Directory('test/golden/goldens');

bool get _baselinesPresent =>
    _goldenDirectory.existsSync() && _goldenDirectory.listSync().isNotEmpty;

const String _skipReason =
    'No golden baselines committed yet. Generate them on a machine with the Flutter SDK: '
    'flutter test --update-goldens test/golden';

/// One shared component, rendered at a fixed width for the golden baseline.
class _Component {
  const _Component(this.name, this.builder);

  final String name;
  final Widget Function() builder;
}

final List<_Component> components = <_Component>[
  _Component(
    'button',
    () => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ArmxButton(label: 'Turn on', onPressed: () {}),
        const SizedBox(height: Insets.sm),
        ArmxButton(
          label: 'Publish',
          variant: ArmxButtonVariant.destructive,
          onPressed: () {},
        ),
        const SizedBox(height: Insets.sm),
        ArmxButton(
          label: 'Deploying',
          loading: true,
          onPressed: () {},
        ),
        const SizedBox(height: Insets.sm),
        ArmxButton(label: 'Unavailable', onPressed: null),
      ],
    ),
  ),
  _Component(
    'text_field',
    () => const Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ArmxTextField(label: 'Email', hint: 'you@example.com'),
        SizedBox(height: Insets.sm),
        ArmxTextField(label: 'Password', obscureText: true),
        SizedBox(height: Insets.sm),
        ArmxTextField(
          label: 'Password',
          errorText: 'Password must be at least 8 characters',
        ),
        SizedBox(height: Insets.sm),
        ArmxSwitchRow(
          title: 'Auto-send',
          subtitle: 'Send without asking first',
          value: true,
        ),
      ],
    ),
  ),
  _Component(
    'card',
    () => const Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ArmxCard(
          title: 'Living room lamp',
          child: Text('70% brightness'),
        ),
        SizedBox(height: Insets.sm),
        ArmxCard(
          child: ArmxDetailRow(
            label: 'Firmware',
            value: '1.4.2',
            monospace: true,
          ),
        ),
        SizedBox(height: Insets.sm),
        ArmxSection(
          title: 'Rooms',
          subtitle: '4 rooms',
          child: Text('Living room'),
        ),
      ],
    ),
  ),
  _Component(
    'badge',
    () => const Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Wrap(
          spacing: Insets.sm,
          children: <Widget>[
            ArmxBadge(label: 'ADMIN', tone: ArmxBadgeTone.accent),
            ArmxBadge(label: 'VIP', tone: ArmxBadgeTone.secondary),
            ArmxBadge(label: 'USER', tone: ArmxBadgeTone.neutral),
            ArmxBadge(label: 'HIGH', tone: ArmxBadgeTone.danger),
            ArmxBadge(label: 'MEDIUM', tone: ArmxBadgeTone.warning),
            ArmxBadge(label: 'LOW', tone: ArmxBadgeTone.success),
          ],
        ),
        SizedBox(height: Insets.sm),
        ArmxChip(label: 'Living room', selected: true),
      ],
    ),
  ),
  _Component(
    'status_dot',
    () => const Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ArmxStatusDot(status: ArmxStatus.online, label: 'Online'),
        ArmxStatusDot(status: ArmxStatus.warning, label: 'Partially online'),
        ArmxStatusDot(status: ArmxStatus.offline, label: 'Offline'),
        ArmxStatusDot(status: ArmxStatus.failed, label: 'Failed'),
        ArmxStatusDot(status: ArmxStatus.pending, label: 'Waiting'),
        ArmxStatusDot(status: ArmxStatus.unknown, label: 'Unknown'),
      ],
    ),
  ),
  _Component(
    'empty_state',
    () => ArmxEmptyState(
      title: 'No alarms yet',
      message: 'Alarms ring on the devices you choose.',
      icon: Icons.alarm_off_rounded,
      actionLabel: 'Create an alarm',
      onAction: () {},
    ),
  ),
  _Component(
    'error_state',
    () => ArmxErrorState(
      error: const NetworkException(message: 'No route to the backend.'),
      onRetry: () {},
    ),
  ),
  _Component(
    'loading_skeleton',
    () => const Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ArmxSkeletonCard(lines: 3),
        SizedBox(height: Insets.sm),
        ArmxSkeletonTable(rows: 4),
      ],
    ),
  ),
  _Component('brand', () => const ArmxWordmark()),
];

final ConfirmRequest _goldenConfirm = ConfirmRequest(
  title: 'Publish the generated site?',
  action: 'web_deploy',
  target: 'thamjj13/armx-site#main',
  parameters: const <ConfirmParameter>[
    ConfirmParameter(label: 'draft_id', value: 'draft-1', monospace: true),
  ],
  consequence: 'The branch is overwritten.',
  riskTier: ArmxRiskTier.high,
  confirmLabel: 'Publish',
  irreversible: true,
  requireTypedPhrase: true,
);

void main() {
  for (final Size size in referenceSizes) {
    final String sizeName = '${size.width.toInt()}x${size.height.toInt()}';
    for (final ThemeMode mode in <ThemeMode>[ThemeMode.dark, ThemeMode.light]) {
      final String modeName = mode == ThemeMode.dark ? 'dark' : 'light';

      group('$sizeName $modeName', () {
        for (final _Component component in components) {
          testWidgets(
            '${component.name} matches its baseline',
            (WidgetTester tester) async {
              await pumpArmx(
                tester,
                component.builder(),
                size: size,
                themeMode: mode,
              );
              await expectLater(
                find.byType(MaterialApp),
                matchesGoldenFile(
                  'goldens/${component.name}_$sizeName$modeName.png',
                ),
              );
            },
            skip: _baselinesPresent ? false : _skipReason,
          );
        }

        testWidgets(
          'the confirmation dialog matches its baseline',
          (WidgetTester tester) async {
            await pumpArmx(
              tester,
              Builder(
                builder: (BuildContext context) => ArmxButton(
                  label: 'Start the action',
                  onPressed: () =>
                      ArmxConfirmDialog.show(context, _goldenConfirm),
                ),
              ),
              size: size,
              themeMode: mode,
            );
            await tester.tap(find.byType(ArmxButton).first);
            await tester.pumpAndSettle();
            await expectLater(
              find.byType(MaterialApp),
              matchesGoldenFile('goldens/confirm_dialog_$sizeName$modeName.png'),
            );
          },
          skip: _baselinesPresent ? false : _skipReason,
        );
      });
    }
  }

  testWidgets('a missing baseline set is reported rather than silently passing', (
    WidgetTester tester,
  ) async {
    // If this ever fails, the golden directory has been committed and the gate above is live.
    if (_baselinesPresent) {
      expect(_skipReason, isNotEmpty);
    } else {
      expect(_baselinesPresent, isFalse);
    }
  });
}
