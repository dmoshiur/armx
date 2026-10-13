// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/data/models/messaging.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeliveryMode', () {
    test('draft-only is the default, and it is the safe one', () {
      // If a per-contact preference is missing, the assistant must draft rather than send.
      expect(DeliveryMode.fromWire(null), DeliveryMode.draftOnly);
      expect(DeliveryMode.fromWire('unsure'), DeliveryMode.draftOnly);
    });

    test('the auto-send spellings are recognised', () {
      expect(DeliveryMode.fromWire('auto_send'), DeliveryMode.autoSend);
      expect(DeliveryMode.fromWire('send'), DeliveryMode.autoSend);
      expect(DeliveryMode.fromWire('automatic'), DeliveryMode.autoSend);
    });

    test('round-trips through the wire', () {
      for (final DeliveryMode mode in DeliveryMode.values) {
        expect(DeliveryMode.fromWire(mode.wire), mode);
      }
    });
  });

  group('ToneProfile', () {
    test('parses a tone with its numeric knobs', () {
      final ToneProfile tone = ToneProfile.fromJson(const <String, Object?>{
        'id': 't-1',
        'name': 'Formal Bengali',
        'tag': 'work',
        'formality': 5,
        'warmth': 2,
        'verbosity': 3,
        'emoji_allowed': false,
        'language_code': 'bn',
        'forbidden_topics': <Object?>['politics'],
      });
      expect(tone.formality, 5);
      expect(tone.emojiAllowed, isFalse);
      expect(tone.languageCode, 'bn');
      expect(tone.forbiddenTopics, contains('politics'));
    });

    test('knobs that arrive out of range are clamped, so a slider cannot go off the scale',
        () {
      final ToneProfile tone = ToneProfile.fromJson(const <String, Object?>{
        'id': 't-2',
        'name': 'Extreme',
        'formality': 99,
        'warmth': -4,
        'verbosity': 1000,
      });
      for (final int knob in <int>[tone.formality, tone.warmth, tone.verbosity]) {
        expect(knob, inInclusiveRange(1, 5));
      }
    });
  });

  group('Contact', () {
    test('parses a contact with its tone and delivery mode', () {
      final Contact contact = Contact.fromJson(const <String, Object?>{
        'id': 'c-1',
        'display_name': 'Rafi',
        'tone_profile_id': 't-1',
        'delivery_mode': 'auto_send',
        'channel': 'sms',
      });
      expect(contact.displayName, 'Rafi');
      expect(contact.deliveryMode, DeliveryMode.autoSend);
      expect(contact.channel, 'sms');
      expect(contact.blocked, isFalse);
    });

    test('a contact with no delivery mode reported falls back to draft-only', () {
      final Contact contact = Contact.fromJson(const <String, Object?>{
        'id': 'c-2',
        'display_name': 'Someone',
      });
      expect(contact.deliveryMode, DeliveryMode.draftOnly);
    });

    test('a blocked contact stays blocked and is not quietly unblocked by a fallback', () {
      final Contact contact = Contact.fromJson(const <String, Object?>{
        'id': 'c-3',
        'display_name': 'Unwanted',
        'blocked': true,
      });
      expect(contact.blocked, isTrue);
    });
  });
}
