// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/core/utils/validators.dart';
import 'package:armx_ai/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Validation is the last thing between a typo and a failed request; the pure helpers are
/// tested directly, and the localized messages are tested by loading both bundles.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isEmail', () {
    test('accepts ordinary addresses', () {
      for (final String value in <String>[
        'mohi@thamjj13.top',
        'rafi@example.com',
        'a.b+tag@sub.domain.co.uk',
      ]) {
        expect(Validators.isEmail(value), isTrue, reason: value);
      }
    });

    test('rejects what a person would actually mistype', () {
      for (final String value in <String>[
        '',
        'mohi',
        'mohi@',
        '@thamjj13.top',
        'mohi@thamjj13',
        'mohi @thamjj13.top',
        'mohi@@thamjj13.top',
        'mohi@thamjj13..top',
      ]) {
        expect(Validators.isEmail(value), isFalse, reason: value);
      }
    });
  });

  group('pairing codes', () {
    test('normalisation removes what a human adds when copying a code', () {
      expect(Validators.normalizePairingCode(' abcd-efgh '), 'ABCDEFGH');
      expect(Validators.normalizePairingCode('abcd efgh'), 'ABCDEFGH');
      expect(Validators.normalizePairingCode('aBcDeFgH'), 'ABCDEFGH');
    });

    test('formatting groups the code for reading, not for storage', () {
      expect(Validators.formatPairingCode('ABCDEFGH'), 'ABCD-EFGH');
      expect(Validators.formatPairingCode('ABCDEFGH', groupSize: 2), 'AB-CD-EF-GH');
      // A short code is left alone rather than padded into something that looks complete.
      expect(Validators.formatPairingCode('ABC'), 'ABC');
    });
  });

  group('localized validators', () {
    late AppLocalizations en;
    late AppLocalizations bn;

    setUpAll(() async {
      en = await AppLocalizations.delegate.load(const Locale('en'));
      bn = await AppLocalizations.delegate.load(const Locale('bn'));
    });

    test('a required field explains itself in both languages', () {
      expect(Validators.requiredText('', en), isNotNull);
      expect(Validators.requiredText('   ', en), isNotNull);
      expect(Validators.requiredText('ok', en), isNull);

      final String? bengaliMessage = Validators.requiredText('', bn);
      expect(bengaliMessage, isNotNull);
      expect(
        bengaliMessage == Validators.requiredText('', en),
        isFalse,
        reason: 'Bengali must not fall back to the English sentence',
      );
    });

    test('a password must reach the stated minimum length', () {
      final String short = 'a' * (Validators.minPasswordLength - 1);
      final String exact = 'a' * Validators.minPasswordLength;
      expect(Validators.password(short, en), isNotNull);
      expect(Validators.password(exact, en), isNull);
    });

    test('confirmation must match, and the message says so', () {
      expect(Validators.confirmPassword('secret12', 'secret12', en), isNull);
      expect(Validators.confirmPassword('secret12', 'secret13', en), isNotNull);
    });

    test('the email validator agrees with the pure helper', () {
      expect(Validators.email('mohi@thamjj13.top', en), isNull);
      expect(Validators.email('mohi', en), isNotNull);
      expect(Validators.email('', en), isNotNull);
    });

    test('a placeholder-carrying message interpolates in both languages', () {
      final int min = Validators.minPasswordLength;
      expect(en.validatorPasswordTooShort(min), contains('\$min'));
      expect(bn.validatorPasswordTooShort(min), contains('\$min'));
    });

    test('both bundles load at runtime, not just in the ARB files', () {
      // The static check compares keys; this proves the generated class actually exposes
      // Bengali strings, which is what a user in Dhaka reads.
      expect(en.settingsTitle.isNotEmpty, isTrue);
      expect(bn.settingsTitle.isNotEmpty, isTrue);
      expect(en.appName.isNotEmpty, isTrue);
      expect(bn.appName.isNotEmpty, isTrue);
    });
  });
}
