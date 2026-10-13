// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/data/models/guest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GreeterCameraState', () {
    test('only `live` means the camera is capturing', () {
      expect(GreeterCameraState.live.isCapturing, isTrue);
      for (final GreeterCameraState state in GreeterCameraState.values) {
        if (state == GreeterCameraState.live) {
          continue;
        }
        expect(
          state.isCapturing,
          isFalse,
          reason: '$state must not read as a running camera',
        );
      }
    });

    test('an unknown state is not capturing — fail closed on a camera', () {
      expect(GreeterCameraState.fromWire('recording-ish').isCapturing, isFalse);
      expect(GreeterCameraState.fromWire(null).isCapturing, isFalse);
    });

    test('round-trips through the wire', () {
      for (final GreeterCameraState state in GreeterCameraState.values) {
        expect(GreeterCameraState.fromWire(state.wire), state);
      }
    });
  });

  group('GuestProfile', () {
    test('parses an enrolled guest, including the consent version they agreed to', () {
      final GuestProfile guest = GuestProfile.fromJson(const <String, Object?>{
        'id': 'g-1',
        'display_name': 'Nadia',
        'enrolled_at': '2026-10-01T09:00:00Z',
        'note': 'Neighbour',
        'consent_text_version': 'v2-2026-08',
        'encrypted_template_ref': 'tpl-9',
      });
      expect(guest.displayName, 'Nadia');
      expect(guest.consentTextVersion, 'v2-2026-08');
      expect(guest.encryptedTemplateRef, 'tpl-9');
    });

    test('a guest enrolled under an older consent version keeps that record', () {
      // Deleting or upgrading the record silently would make the audit trail a lie.
      final GuestProfile guest = GuestProfile.fromJson(const <String, Object?>{
        'id': 'g-2',
        'display_name': 'Old',
        'consent_text_version': 'v1-2025-01',
      });
      expect(guest.consentTextVersion, 'v1-2025-01');
    });

    test('the encrypted template reference is the only identity material on the client',
        () {
      // There is no face image, no embedding and no template bytes in the model — only a
      // reference the backend resolves. That is assertion-worthy, not incidental.
      final GuestProfile guest = GuestProfile.fromJson(const <String, Object?>{
        'id': 'g-3',
        'display_name': 'Rafi',
      });
      expect(guest.encryptedTemplateRef, isNull);
    });
  });

  group('GreeterEvent', () {
    test('a greeting that was spoken says so; one that was only detected does not', () {
      final GreeterEvent spoken = GreeterEvent.fromJson(const <String, Object?>{
        'id': 'e-1',
        'occurred_at': '2026-10-13T04:30:00Z',
        'guest_name': 'Nadia',
        'confidence': 0.92,
        'greeting_spoken': true,
      });
      expect(spoken.greetingSpoken, isTrue);
      expect(spoken.confidence, closeTo(0.92, 0.001));

      final GreeterEvent silent = GreeterEvent.fromJson(const <String, Object?>{
        'id': 'e-2',
        'guest_name': 'Unknown visitor',
      });
      expect(silent.greetingSpoken, isFalse);
      expect(silent.confidence, isNull);
      expect(silent.guestName, isNotEmpty);
    });

    test('an event without a name is labelled rather than left blank', () {
      final GreeterEvent event = GreeterEvent.fromJson(const <String, Object?>{
        'id': 'e-3',
      });
      expect(event.guestName.trim(), isNotEmpty);
    });
  });
}
