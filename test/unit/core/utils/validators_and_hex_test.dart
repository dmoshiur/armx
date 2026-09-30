// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:typed_data';

import 'package:armx_ai/core/utils/hex.dart';
import 'package:armx_ai/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators.serverUrl', () {
    test('accepts a well formed https URL', () {
      expect(Validators.serverUrl('https://armx.example.com'), isNull);
      expect(Validators.serverUrl('https://armx.example.com:8443/base'), isNull);
    });

    test('rejects empty, relative and unsupported schemes', () {
      expect(Validators.serverUrl(''), ValidationIssue.empty);
      expect(Validators.serverUrl('armx.example.com'), ValidationIssue.notAbsoluteUrl);
      expect(Validators.serverUrl('ftp://armx.example.com'), ValidationIssue.unsupportedScheme);
    });

    test('rejects cleartext when TLS is required (release builds)', () {
      expect(
        Validators.serverUrl('http://192.168.0.10:8080'),
        ValidationIssue.cleartextNotAllowed,
      );
      expect(
        Validators.serverUrl('http://192.168.0.10:8080', requireTls: false),
        isNull,
      );
    });

    test('rejects impossible ports and hostless URLs', () {
      expect(Validators.serverUrl('https://armx.example.com:70000'), ValidationIssue.badPort);
      expect(Validators.serverUrl('https://:8443'), ValidationIssue.missingHost);
    });

    test('normalises a trailing slash', () {
      expect(Validators.normaliseServerUrl('https://armx.example.com/').toString(),
          'https://armx.example.com');
    });
  });

  group('Validators.deviceKey', () {
    test('accepts base64url-ish keys of the right length', () {
      expect(Validators.deviceKey(List<String>.filled(32, 'A').join()), isNull);
      expect(Validators.deviceKey('mockkey_0123456789abcdef0123456789abcdef'), isNull);
    });

    test('rejects short or malformed keys', () {
      expect(Validators.deviceKey('short'), ValidationIssue.badDeviceKey);
      expect(Validators.deviceKey('has spaces in it 0123456789012345678901'),
          ValidationIssue.badDeviceKey);
    });
  });

  group('Validators thresholds and wake word', () {
    test('face threshold band', () {
      expect(Validators.matchThreshold(0.72), isNull);
      expect(Validators.matchThreshold(0.05), ValidationIssue.badThreshold);
      expect(Validators.matchThreshold(1.0), ValidationIssue.badThreshold);
    });

    test('wake word', () {
      expect(Validators.wakeWord('Armex'), isNull);
      expect(Validators.wakeWord('A'), ValidationIssue.badWakeWord);
      expect(Validators.wakeWord('Armex!'), ValidationIssue.badWakeWord);
      expect(Validators.wakeWord(''), ValidationIssue.empty);
    });
  });

  group('Hex', () {
    test('round-trips bytes', () {
      final bytes = Uint8List.fromList(<int>[0, 15, 16, 255, 128]);
      final encoded = Hex.encode(bytes);
      expect(encoded, '000f10ff80');
      expect(Hex.decode(encoded), bytes);
      expect(Hex.decode('00:0F-10 FF 80'), bytes);
    });

    test('rejects malformed input', () {
      expect(() => Hex.decode('abc'), throwsFormatException);
      expect(() => Hex.decode('zz'), throwsFormatException);
    });

    test('groups a fingerprint for human comparison', () {
      expect(Hex.group('0011223344556677', maxGroups: 2), '0011 2233');
    });

    test('compares in constant time', () {
      expect(Hex.constantTimeEquals(<int>[1, 2, 3], <int>[1, 2, 3]), isTrue);
      expect(Hex.constantTimeEquals(<int>[1, 2, 3], <int>[1, 2, 4]), isFalse);
      expect(Hex.constantTimeEquals(<int>[1, 2], <int>[1, 2, 3]), isFalse);
    });
  });
}
