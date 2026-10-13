// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:meta/meta.dart';

/// What the assistant may do with a message it drafted for a contact.
enum DeliveryMode {
  /// Send immediately after the assistant composes it.
  autoSend,

  /// Put it in the drafts tray for the owner to review and send. The default for every
  /// new contact, and for every contact in a high-sensitivity tone.
  draftOnly;

  /// Parses a wire value. Anything unrecognised becomes [draftOnly] — the option that
  /// cannot send something on the owner's behalf by accident.
  static DeliveryMode fromWire(String? value) => switch (value?.toLowerCase()) {
        'auto_send' || 'autosend' || 'send' => DeliveryMode.autoSend,
        _ => DeliveryMode.draftOnly,
      };

  /// The wire value.
  String get wire =>
      this == DeliveryMode.autoSend ? 'auto_send' : 'draft_only';
}

/// A tone profile: how the assistant should write to a given class of contact.
@immutable
class ToneProfile {
  /// Creates a tone profile.
  const ToneProfile({
    required this.id,
    required this.name,
    required this.tag,
    required this.formality,
    required this.warmth,
    required this.verbosity,
    this.emojiAllowed = false,
    this.languageCode = 'auto',
    this.forbiddenTopics = const <String>[],
  });

  /// Identifier.
  final String id;

  /// Display name, e.g. "Teacher".
  final String name;

  /// Machine tag, e.g. `teacher`, `student`, `friend`.
  final String tag;

  /// 0 (casual) to 100 (formal).
  final int formality;

  /// 0 (reserved) to 100 (effusive).
  final int warmth;

  /// 0 (terse) to 100 (detailed).
  final int verbosity;

  /// Whether emoji are acceptable in this tone.
  final bool emojiAllowed;

  /// `auto`, `en`, or `bn`.
  final String languageCode;

  /// Subjects the assistant must not raise with this contact.
  final List<String> forbiddenTopics;

  /// Parses from the wire.
  factory ToneProfile.fromJson(Map<String, Object?> json) => ToneProfile(
        id: json['id']! as String,
        name: (json['name'] ?? '') as String,
        tag: (json['tag'] ?? 'default') as String,
        formality: (json['formality'] as num?)?.toInt() ?? 50,
        warmth: (json['warmth'] as num?)?.toInt() ?? 50,
        verbosity: (json['verbosity'] as num?)?.toInt() ?? 50,
        emojiAllowed: json['emoji'] == true,
        languageCode: (json['language'] ?? 'auto') as String,
        forbiddenTopics: (json['forbidden_topics'] as List<Object?>? ?? const <Object?>[])
            .whereType<String>()
            .toList(growable: false),
      );

  /// Serialises.
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'tag': tag,
        'formality': formality,
        'warmth': warmth,
        'verbosity': verbosity,
        'emoji': emojiAllowed,
        'language': languageCode,
        'forbidden_topics': forbiddenTopics,
      };

  /// Copy with changes.
  ToneProfile copyWith({
    String? id,
    String? name,
    String? tag,
    int? formality,
    int? warmth,
    int? verbosity,
    bool? emojiAllowed,
    String? languageCode,
    List<String>? forbiddenTopics,
  }) =>
      ToneProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        tag: tag ?? this.tag,
        formality: formality ?? this.formality,
        warmth: warmth ?? this.warmth,
        verbosity: verbosity ?? this.verbosity,
        emojiAllowed: emojiAllowed ?? this.emojiAllowed,
        languageCode: languageCode ?? this.languageCode,
        forbiddenTopics: forbiddenTopics ?? this.forbiddenTopics,
      );

  @override
  bool operator ==(Object other) =>
      other is ToneProfile &&
      other.id == id &&
      other.name == name &&
      other.formality == formality &&
      other.warmth == warmth &&
      other.verbosity == verbosity &&
      other.emojiAllowed == emojiAllowed &&
      other.languageCode == languageCode;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        formality,
        warmth,
        verbosity,
        emojiAllowed,
        languageCode,
      );
}

/// A contact the messaging feature knows about.
@immutable
class Contact {
  /// Creates a contact.
  const Contact({
    required this.id,
    required this.displayName,
    required this.toneProfileId,
    required this.deliveryMode,
    this.tag,
    this.channel = 'sms',
    this.blocked = false,
  });

  /// Identifier.
  final String id;

  /// Display name.
  final String displayName;

  /// Tone profile applied to this contact.
  final String toneProfileId;

  /// Whether the assistant may send directly.
  final DeliveryMode deliveryMode;

  /// Free-form tag, e.g. `teacher`.
  final String? tag;

  /// Channel the assistant writes on.
  final String channel;

  /// When true the assistant never writes to this contact at all.
  final bool blocked;

  /// Parses from the wire.
  factory Contact.fromJson(Map<String, Object?> json) => Contact(
        id: json['id']! as String,
        displayName: (json['name'] ?? '') as String,
        toneProfileId: (json['tone_profile_id'] ?? 'default') as String,
        deliveryMode: DeliveryMode.fromWire(json['delivery_mode'] as String?),
        tag: json['tag'] as String?,
        channel: (json['channel'] ?? 'sms') as String,
        blocked: json['blocked'] == true,
      );

  /// Copy with changes.
  Contact copyWith({
    String? id,
    String? displayName,
    String? toneProfileId,
    DeliveryMode? deliveryMode,
    String? tag,
    String? channel,
    bool? blocked,
  }) =>
      Contact(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        toneProfileId: toneProfileId ?? this.toneProfileId,
        deliveryMode: deliveryMode ?? this.deliveryMode,
        tag: tag ?? this.tag,
        channel: channel ?? this.channel,
        blocked: blocked ?? this.blocked,
      );

  @override
  bool operator ==(Object other) =>
      other is Contact &&
      other.id == id &&
      other.displayName == displayName &&
      other.toneProfileId == toneProfileId &&
      other.deliveryMode == deliveryMode &&
      other.blocked == blocked;

  @override
  int get hashCode =>
      Object.hash(id, displayName, toneProfileId, deliveryMode, blocked);
}
