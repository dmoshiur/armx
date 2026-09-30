// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../utils/hex.dart';

/// The raw material of one on-device Ed25519 identity.
///
/// [seedBase64] is the **private** half: it is written straight into
/// `flutter_secure_storage` (`SecureKeys.devicePrivateKey`) and never logged, never
/// persisted elsewhere. [publicKeyBase64] and [fingerprintHex] are public.
@immutable
class DeviceKeyMaterial {
  /// Creates key material.
  const DeviceKeyMaterial({
    required this.seedBase64,
    required this.publicKeyBase64,
    required this.fingerprintHex,
  });

  /// Base64 of the 32-byte Ed25519 seed (secret).
  final String seedBase64;

  /// Base64 of the SPKI DER public key — exactly what `POST /devices/pair` sends.
  final String publicKeyBase64;

  /// Lowercase hex SHA-256 over the SPKI bytes (public; grouped in 4s on screen).
  final String fingerprintHex;
}

/// Ed25519 key-material helpers used by the pairing flow.
///
/// The SPKI encoding (`302a300506032b6570032100` + the raw 32-byte key) matches the
/// `public_key` example in `docs/api.md`.
abstract final class DeviceKeys {
  /// ASN.1 prefix of an Ed25519 SubjectPublicKeyInfo.
  static const List<int> _spkiPrefix = <int>[
    0x30,
    0x2A,
    0x30,
    0x05,
    0x06,
    0x03,
    0x2B,
    0x65,
    0x70,
    0x03,
    0x21,
    0x00,
  ];

  /// Generates a fresh keypair on this device.
  static Future<DeviceKeyMaterial> generate() async {
    final keyPair = await Ed25519().newKeyPair();
    final seed = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    return material(seed: seed, rawPublicKey: publicKey.bytes);
  }

  /// Recomputes the public material from a stored 32-byte seed (base64).
  static Future<DeviceKeyMaterial> fromStoredSeed(String seedBase64) async {
    final seed = base64Decode(seedBase64);
    final keyPair = await Ed25519().newKeyPairFromSeed(seed);
    final publicKey = await keyPair.extractPublicKey();
    return material(seed: seed, rawPublicKey: publicKey.bytes);
  }

  /// Builds the public-facing material for a raw keypair.
  static Future<DeviceKeyMaterial> material({
    required List<int> seed,
    required List<int> rawPublicKey,
  }) async {
    final spki = <int>[..._spkiPrefix, ...rawPublicKey];
    final fingerprintHex = await _fingerprint(spki);
    return DeviceKeyMaterial(
      seedBase64: base64Encode(seed),
      publicKeyBase64: base64Encode(spki),
      fingerprintHex: fingerprintHex,
    );
  }

  /// SHA-256 fingerprint (lowercase hex) of a base64 SPKI public key.
  ///
  /// Used when a stored identity is restored on a later launch.
  static Future<String> fingerprintFromSpkiBase64(String publicKeyBase64) =>
      _fingerprint(base64Decode(publicKeyBase64));

  static Future<String> _fingerprint(List<int> spkiBytes) async {
    final digest = await Sha256().hash(spkiBytes);
    return Hex.encode(digest.bytes);
  }
}
