// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:drift/drift.dart';

/// Key/value table for app preferences (theme, locale, wake word, thresholds).
///
/// Preferences are **not** secrets, so they live in the SQLite database rather than in
/// secure storage — that keeps `flutter_secure_storage` free for tokens and key material
/// and lets the same file drive the Diagnostics screen.
@TableIndex(name: 'settings_updated_at', columns: {#updatedAt})
class SettingsEntries extends Table {
  /// Preference key (namespaced, for example `armx.theme.mode`).
  TextColumn get key => text().withLength(min: 1, max: 128)();

  /// Serialized value (JSON-aware, stored as text).
  TextColumn get value => text()();

  /// When the entry was last written (UTC).
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

/// Offline cache of chat messages so a conversation survives a restart and a flight.
@TableIndex(name: 'chat_messages_conversation', columns: {#conversationId, #at})
class ChatMessagesCache extends Table {
  /// Message id (client-generated UUID or server id).
  TextColumn get id => text()();

  /// Conversation this message belongs to.
  TextColumn get conversationId => text()();

  /// `USER`, `ASSISTANT`, `SYSTEM` or `TOOL` (wire value of `ChatRole`).
  TextColumn get role => text()();

  /// Message body as plain text.
  TextColumn get body => text()();

  /// Creation instant (UTC).
  DateTimeColumn get at => dateTime()();

  /// Delivery status (`SENDING`, `STREAMING`, `SENT`, `FAILED`, `BLOCKED` — wire
  /// value of `ChatMessageStatus`).
  TextColumn get status => text()();

  /// Risk tier of an attached tool call, if any (`LOW`/`MEDIUM`/`HIGH`).
  TextColumn get riskTier => text().nullable()();

  /// Tool-call id when this message renders a tool result.
  TextColumn get toolCallId => text().nullable()();

  /// True when the row still needs to be pushed to the server.
  BoolColumn get pending => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Offline cache of the audit log (admin viewer + dashboard "recent" list).
@TableIndex(name: 'audit_at', columns: {#at})
class AuditCache extends Table {
  /// Audit entry id.
  TextColumn get id => text()();

  /// Event time (UTC).
  DateTimeColumn get at => dateTime()();

  /// Who triggered the action.
  TextColumn get actor => text()();

  /// Action verb.
  TextColumn get action => text()();

  /// Affected target (device, tool, user).
  TextColumn get target => text()();

  /// Risk tier wire value.
  TextColumn get riskTier => text()();

  /// Outcome wire value.
  TextColumn get outcome => text()();

  /// Free-form detail.
  TextColumn get detail => text()();

  /// Full JSON payload, so model changes never require a migration.
  TextColumn get payload => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Offline cache of device state.
class DeviceCache extends Table {
  /// Device id.
  TextColumn get id => text()();

  /// Display name.
  TextColumn get name => text()();

  /// Site/group.
  TextColumn get site => text()();

  /// Device kind wire value.
  TextColumn get kind => text()();

  /// Last known online flag.
  BoolColumn get online => boolean().withDefault(const Constant(false))();

  /// Risk tier wire value.
  TextColumn get riskTier => text()();

  /// Last seen instant (UTC).
  DateTimeColumn get lastSeenAt => dateTime()();

  /// Full JSON payload.
  TextColumn get payload => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Offline cache of automation rules.
class RuleCache extends Table {
  /// Rule id.
  TextColumn get id => text()();

  /// Rule name.
  TextColumn get name => text()();

  /// Whether the rule is enabled.
  BoolColumn get enabled => boolean().withDefault(const Constant(false))();

  /// Whether the rule only simulates (dry run).
  BoolColumn get dryRun => boolean().withDefault(const Constant(true))();

  /// Risk tier wire value.
  TextColumn get riskTier => text()();

  /// Full JSON payload.
  TextColumn get payload => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Queued side effects that must reach the server (chat send, command, unlock request).
///
/// The outbox is what makes the UI honest offline: actions are accepted locally, marked
/// pending, and either drained on reconnect or rolled back with a visible error.
class OutboxEntries extends Table {
  /// Local id.
  IntColumn get id => integer().autoIncrement()();

  /// Discriminator (`chat.send`, `device.command`, `unlock.request`, …).
  TextColumn get kind => text()();

  /// JSON body to POST once connectivity returns.
  TextColumn get payload => text()();

  /// When the entry was queued (UTC).
  DateTimeColumn get createdAt => dateTime()();

  /// Attempts so far (exponential backoff lives in the outbox repository).
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Last failure message, shown on the failed-action banner.
  TextColumn get lastError => text().nullable()();
}
