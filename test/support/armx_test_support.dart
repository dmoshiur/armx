// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/breakpoints.dart';
import 'package:armx_ai/core/theme/app_theme.dart';
import 'package:armx_ai/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// The three reference sizes every screen and every shared widget is checked at.
///
/// They are the sizes the master prompt names: a 360 × 800 phone, an 800 × 1280 tablet and a
/// 1440 × 900 desktop window. Tests iterate this list rather than repeating the numbers, so a
/// widget that has only ever been looked at on a phone cannot pass by accident.
const List<Size> referenceSizes = <Size>[
  Size(360, 800),
  Size(800, 1280),
  Size(1440, 900),
];

/// The breakpoint each reference size lands in, used to assert the *layout*, not just that
/// nothing threw.
const Map<Size, Breakpoint> referenceBreakpoints = <Size, Breakpoint>{
  Size(360, 800): Breakpoint.compact,
  Size(800, 1280): Breakpoint.medium,
  Size(1440, 900): Breakpoint.expanded,
};

/// Wraps [child] in the minimum app scaffolding a widget test needs: the real theme, the real
/// localizations, and a surface the size of the reference device.
///
/// The theme is the production one on purpose. A test that pumps a widget under
/// `ThemeData()` passes while the app's own theme is missing a token, which is the failure
/// most worth catching.
Future<void> pumpArmx(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(360, 800),
  ThemeMode themeMode = ThemeMode.dark,
  Locale locale = const Locale('en'),
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Center(
          // A fixed-width host would hide overflow; the widget gets the real width instead.
          child: SizedBox(width: size.width, child: child),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
}

/// Fails unless [finder] is at least [minimum] tall — the touch-target rule, expressed once.
void expectTouchTarget(WidgetTester tester, Finder finder,
    {double minimum = Insets.minTouchTarget}) {
  final Size size = tester.getSize(finder);
  expect(
    size.height >= minimum - 0.01,
    isTrue,
    reason: 'touch target is ${size.height} dp tall, below the $minimum dp minimum',
  );
}
