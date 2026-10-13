// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/breakpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Breakpoint.fromWidth', () {
    test('a 360 dp phone is compact', () {
      expect(Breakpoint.fromWidth(360), Breakpoint.compact);
    });

    test('599 dp is still compact, 600 dp is medium: the boundary is inclusive below', () {
      expect(Breakpoint.fromWidth(599), Breakpoint.compact);
      expect(Breakpoint.fromWidth(600), Breakpoint.medium);
    });

    test('1023 dp is medium, 1024 dp is expanded', () {
      expect(Breakpoint.fromWidth(1023), Breakpoint.medium);
      expect(Breakpoint.fromWidth(1024), Breakpoint.expanded);
    });

    test('a 2560 dp web window is expanded rather than something new', () {
      expect(Breakpoint.fromWidth(2560), Breakpoint.expanded);
    });

    test('zero and absurd widths do not fall outside the enum', () {
      expect(Breakpoint.fromWidth(0), Breakpoint.compact);
      expect(Breakpoint.fromWidth(20000), Breakpoint.expanded);
    });
  });

  test('the content cap is 1200 dp, per the spec', () {
    expect(Breakpoint.maxContentWidth, 1200);
  });

  test('the breakpoints are the specified 600 / 1024', () {
    expect(Breakpoint.compactMax, 600);
    expect(Breakpoint.mediumMax, 1024);
  });
}
