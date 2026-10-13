// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../../../../core/breakpoints.dart';
import '../../../../core/l10n/l10n.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/armx_badge.dart';
import '../../../../core/widgets/armx_card.dart';
import '../../../../data/models/web_builder.dart';

/// One generated file, with the lines it adds marked.
///
/// **Generated markup is untrusted output**: it was written by a model from a prompt. It is
/// therefore shown as text — never executed, never rendered in a web view, never turned into
/// a live link inside the app. Publishing sends it to the backend, and the backend is the
/// only component that should ever run it.
///
/// For a modified file the previous contents are known, so added lines get a `+` in the
/// gutter **and** a tint: the marker is the signal, the tint merely agrees with it. A new
/// file says it is new instead of pretending every line is an addition.
class GeneratedFileView extends StatelessWidget {
  /// Creates the view.
  const GeneratedFileView({required this.file, super.key});

  /// The file to show.
  final GeneratedFile file;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    final List<String> lines = file.contents.split('\n');
    final Set<int> added = file.isNew
        ? const <int>{}
        : addedLineIndexes(file.previousContents ?? '', lines);

    return ArmxCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: SelectableText(
                    file.path,
                    style: ArmxTypography.mono(size: 13, color: colors.text),
                  ),
                ),
                ArmxBadge(
                  label: file.isNew
                      ? context.l10n.builderFileNew
                      : context.l10n.builderFileModified,
                  tone: file.isNew ? ArmxBadgeTone.success : ArmxBadgeTone.warning,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.hairline),
          // Horizontal scrolling rather than wrapping: generated code is read by its
          // indentation, and wrapping destroys it.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int index = 0; index < lines.length; index++)
                    _CodeLine(
                      number: index + 1,
                      text: lines[index],
                      added: added.contains(index),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Line indexes present in [next] but not in [previous].
///
/// A longest-common-subsequence over lines, so inserting a paragraph above unchanged code
/// marks the insertion rather than the whole file. Exposed for the unit test that pins the
/// behaviour on a small, checkable example.
Set<int> addedLineIndexes(String previous, List<String> next) {
  final List<String> old = previous.split('\n');
  final List<List<int>> table = List<List<int>>.generate(
    old.length + 1,
    (_) => List<int>.filled(next.length + 1, 0),
    growable: false,
  );
  for (int i = old.length - 1; i >= 0; i--) {
    for (int j = next.length - 1; j >= 0; j--) {
      table[i][j] = old[i] == next[j]
          ? table[i + 1][j + 1] + 1
          : (table[i + 1][j] >= table[i][j + 1]
              ? table[i + 1][j]
              : table[i][j + 1]);
    }
  }

  final Set<int> added = <int>{};
  int i = 0;
  int j = 0;
  while (i < old.length && j < next.length) {
    if (old[i] == next[j]) {
      i++;
      j++;
    } else if (table[i + 1][j] >= table[i][j + 1]) {
      i++;
    } else {
      added.add(j);
      j++;
    }
  }
  while (j < next.length) {
    added.add(j);
    j++;
  }
  return added;
}

class _CodeLine extends StatelessWidget {
  const _CodeLine({
    required this.number,
    required this.text,
    required this.added,
  });

  final int number;
  final String text;
  final bool added;

  @override
  Widget build(BuildContext context) {
    final ArmxColors colors = ArmxColors.of(context);
    return ColoredBox(
      color: added ? colors.success.withValues(alpha: 0.10) : colors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 40,
              child: Text(
                '$number',
                textAlign: TextAlign.end,
                style: ArmxTypography.mono(size: 12, color: colors.textMuted),
              ),
            ),
            SizedBox(
              width: 18,
              child: Text(
                added ? '+' : '',
                textAlign: TextAlign.center,
                style: ArmxTypography.mono(size: 12, color: colors.successText),
              ),
            ),
            SelectableText(
              text,
              style: ArmxTypography.mono(size: 12, color: colors.text),
            ),
          ],
        ),
      ),
    );
  }
}

/// The file chooser.
///
/// A wrapping row of chips rather than a dropdown or a tab bar: generated paths are long and
/// similar, and a wrapping list keeps every path readable at 360 dp.
class GeneratedFilePicker extends StatelessWidget {
  /// Creates the picker.
  const GeneratedFilePicker({
    required this.files,
    required this.selectedPath,
    required this.onSelected,
    super.key,
  });

  /// Files in the draft.
  final List<GeneratedFile> files;

  /// Currently shown path.
  final String? selectedPath;

  /// Called when the user picks a file.
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      children: <Widget>[
        for (final GeneratedFile file in files)
          ArmxChip(
            label: file.path,
            selected: file.path == selectedPath,
            icon: file.isNew ? Icons.note_add_outlined : Icons.edit_note_rounded,
            onSelected: (_) => onSelected(file.path),
            semanticLabel: '${file.path}, '
                '${file.isNew ? context.l10n.builderFileNew : context.l10n.builderFileModified}',
          ),
      ],
    );
  }
}
