// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';

import '../theme/armx_colors.dart';
import '../theme/armx_typography.dart';

/// Renders **untrusted** assistant/tool text with a deliberately tiny Markdown subset.
///
/// Security rules enforced here (see `docs/security.md`):
/// * no HTML, no images, no widgets and no autolinks are ever created;
/// * `[label](url)` is rendered as `label (url)` in plain text, so a hostile model cannot
///   trick the user into opening a link by tapping a message;
/// * fenced code is shown verbatim in the monospace family and is never executed;
/// * parsing is total and bounded — 400 blocks and 20 000 characters maximum.
class SanitizedMarkdown extends StatelessWidget {
  /// Creates the renderer for [text].
  const SanitizedMarkdown({required this.text, this.textStyle, super.key});

  /// Raw text received from the assistant or from a tool result.
  final String text;

  /// Base style; defaults to the theme's body style.
  final TextStyle? textStyle;

  /// Maximum number of rendered blocks.
  static const int maxBlocks = 400;

  /// Maximum number of characters considered.
  static const int maxCharacters = 20000;

  static final RegExp _bullet = RegExp(r'^\s*[-*•]\s+');
  static final RegExp _ordered = RegExp(r'^\s*\d+[.)]\s+');
  static final RegExp _heading = RegExp(r'^(#{1,3})\s+(.*)$');
  static final RegExp _quote = RegExp(r'^\s*>\s?(.*)$');
  static final RegExp _codeFence = RegExp(r'^\s*```');

  @override
  Widget build(BuildContext context) {
    final colors = ArmxColors.of(context);
    final base = textStyle ??
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final source = text.length > maxCharacters ? text.substring(0, maxCharacters) : text;

    final blocks = <Widget>[];
    final lines = source.split('\n');
    var inCode = false;
    final codeBuffer = StringBuffer();
    final paragraphBuffer = StringBuffer();

    void flushParagraph() {
      if (paragraphBuffer.isEmpty) {
        return;
      }
      blocks.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text.rich(
            TextSpan(children: _inlineSpans(paragraphBuffer.toString(), base, colors)),
            style: base,
            softWrap: true,
          ),
        ),
      );
      paragraphBuffer.clear();
    }

    void flushCode() {
      if (codeBuffer.isEmpty) {
        return;
      }
      blocks.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.panel2.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: SelectableText(
            codeBuffer.toString(),
            style: ArmxTypography.mono(size: 12.5, color: colors.text),
          ),
        ),
      );
      codeBuffer.clear();
    }

    for (final line in lines) {
      if (blocks.length >= maxBlocks) {
        break;
      }
      if (_codeFence.hasMatch(line)) {
        flushParagraph();
        if (inCode) {
          flushCode();
        }
        inCode = !inCode;
        continue;
      }
      if (inCode) {
        codeBuffer
          ..write(line)
          ..write('\n');
        continue;
      }
      final heading = _heading.firstMatch(line);
      if (heading != null) {
        flushParagraph();
        final level = heading.group(1)!.length;
        final style = switch (level) {
          1 => ArmxTypography.inter(size: 20, weight: 700, color: colors.text),
          2 => ArmxTypography.inter(size: 17, weight: 700, color: colors.text),
          _ => ArmxTypography.inter(size: 15, weight: 600, color: colors.text),
        };
        blocks.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(heading.group(2)!, style: style),
          ),
        );
        continue;
      }
      final quote = _quote.firstMatch(line);
      if (quote != null) {
        flushParagraph();
        blocks.add(
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.only(left: 12),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: colors.cyan, width: 3)),
            ),
            child: Text(
              quote.group(1)!,
              style: base.copyWith(color: colors.muted, fontStyle: FontStyle.italic),
            ),
          ),
        );
        continue;
      }
      if (_bullet.hasMatch(line)) {
        flushParagraph();
        blocks.add(
          _BulletRow(
            bullet: '•',
            color: colors.cyan,
            child: Text.rich(
              TextSpan(children: _inlineSpans(_bullet.replaceFirst(line, ''), base, colors)),
              style: base,
            ),
          ),
        );
        continue;
      }
      if (_ordered.hasMatch(line)) {
        flushParagraph();
        final marker = line.trim().split(RegExp(r'\s+')).first;
        blocks.add(
          _BulletRow(
            bullet: marker,
            color: colors.violet,
            child: Text.rich(
              TextSpan(children: _inlineSpans(_ordered.replaceFirst(line, ''), base, colors)),
              style: base,
            ),
          ),
        );
        continue;
      }
      if (line.trim().isEmpty) {
        flushParagraph();
        continue;
      }
      if (paragraphBuffer.isNotEmpty) {
        paragraphBuffer.write(' ');
      }
      paragraphBuffer.write(line.trim());
    }

    flushParagraph();
    flushCode();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }

  /// Splits a line into styled spans: `**bold**`, `*italic*`, `` `code` `` and links→text.
  static List<InlineSpan> _inlineSpans(String input, TextStyle base, ArmxColors colors) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`|\[[^\]]+\]\([^)]+\))');
    var cursor = 0;
    for (final match in pattern.allMatches(input)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: input.substring(cursor, match.start)));
      }
      final raw = match.group(0)!;
      if (raw.startsWith('**')) {
        spans.add(
          TextSpan(
            text: raw.substring(2, raw.length - 2),
            style: base.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else if (raw.startsWith('`')) {
        spans.add(
          TextSpan(
            text: raw.substring(1, raw.length - 1),
            style: ArmxTypography.mono(size: (base.fontSize ?? 14) * 0.92, color: colors.cyan),
          ),
        );
      } else if (raw.startsWith('[')) {
        // Never create a tappable link: show the label and the URL as inert text.
        final separator = raw.indexOf('](');
        final label = raw.substring(1, separator);
        final url = raw.substring(separator + 2, raw.length - 1);
        spans.add(TextSpan(text: '$label ($url)'));
      } else {
        spans.add(
          TextSpan(
            text: raw.substring(1, raw.length - 1),
            style: base.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < input.length) {
      spans.add(TextSpan(text: input.substring(cursor)));
    }
    return spans;
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.bullet, required this.child, required this.color});

  final String bullet;
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 22,
            child: Text(
              bullet,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
