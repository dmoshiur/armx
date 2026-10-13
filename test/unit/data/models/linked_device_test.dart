// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/data/models/linked_device.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LinkStatus', () {
    test('active and offline both mean the device has access', () {
      expect(LinkStatus.active.hasAccess, isTrue);
      expect(LinkStatus.offline.hasAccess, isTrue);
    });

    test('revoked, expired and pending approval all mean it does not', () {
      expect(LinkStatus.revoked.hasAccess, isFalse);
      expect(LinkStatus.expired.hasAccess, isFalse);
      expect(LinkStatus.pendingApproval.hasAccess, isFalse);
    });

    test('only pending approval is still open', () {
      expect(LinkStatus.pendingApproval.isOpen, isTrue);
      expect(LinkStatus.active.isOpen, isFalse);
    });

    test('round-trips through the wire', () {
      for (final LinkStatus status in LinkStatus.values) {
        expect(LinkStatus.fromWire(status.wire), status);
      }
    });

    test('an unknown status is not access; fail closed', () {
      expect(LinkStatus.fromWire('mystery').hasAccess, isFalse);
      expect(LinkStatus.fromWire(null).hasAccess, isFalse);
    });
  });

  group('LinkedDevice', () {
    test('parses a linked desktop', () {
      final LinkedDevice device = LinkedDevice.fromJson(const <String, Object?>{
        'id': 'd-1',
        'name': 'Study PC',
        'platform': 'windows',
        'status': 'active',
        'owner_email': 'mohi@thamjj13.top',
        'link_method': 'qr',
        'is_current_device': false,
      });
      expect(device.name, 'Study PC');
      expect(device.status, LinkStatus.active);
      expect(device.ownerEmail, 'mohi@thamjj13.top');
      expect(device.linkMethod, LinkMethod.qr);
      expect(device.isCurrentDevice, isFalse);
    });

    test('a device with no owner reported is not assumed to be the user\'s own', () {
      final LinkedDevice device = LinkedDevice.fromJson(const <String, Object?>{
        'id': 'd-2',
        'name': 'Unknown',
        'status': 'pending_approval',
      });
      expect(device.ownerEmail, isNull);
      expect(device.status.isOpen, isTrue);
    });

    test('the current device is identified, because unlinking it signs the user out', () {
      final LinkedDevice device = LinkedDevice.fromJson(const <String, Object?>{
        'id': 'd-3',
        'name': 'This phone',
        'status': 'active',
        'is_current_device': true,
      });
      expect(device.isCurrentDevice, isTrue);
    });
  });

  group('PairingOffer', () {
    test('carries the code and the QR payload and the expiry', () {
      final PairingOffer offer = PairingOffer.fromJson(const <String, Object?>{
        'code': 'ABCD-EFGH',
        'expires_at': '2026-10-13T12:00:00Z',
        'device_name': 'Study PC',
        'qr_payload': 'armx://pair?code=ABCD-EFGH',
      });
      expect(offer.code, 'ABCD-EFGH');
      expect(offer.qrPayload, contains('ABCD-EFGH'));
      expect(offer.expiresAt.isBefore(DateTime.utc(2026, 10, 13, 12, 0, 1)), isTrue);
    });
  });

  group('LinkMethod', () {
    test('a QR link round-trips, and the words a human would use map to the QR link', () {
      expect(LinkMethod.fromWire(LinkMethod.qr.wire), LinkMethod.qr);
      expect(LinkMethod.fromWire('qrcode'), LinkMethod.qr);
      expect(LinkMethod.fromWire('qr_code'), LinkMethod.qr);
    });

    test('a typed code and the older `manual` spelling both mean the code link', () {
      // The hand-typed path is the fallback when there is no camera, so an older record that
      // says "manual" must still render as the code link rather than as a QR one.
      expect(LinkMethod.fromWire('code'), LinkMethod.code);
      expect(LinkMethod.fromWire('manual'), LinkMethod.code);
    });
  });
}
