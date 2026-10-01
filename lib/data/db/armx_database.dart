// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'armx_database.g.dart';

/// Local SQLite database (drift) used for preferences, offline caches and the outbox.
///
/// Opened lazily: constructing the database does not touch the file system, the first
/// query does (drift runs it on a background isolate). That keeps `main()` synchronous.
@DriftDatabase(
  tables: <Type>[
    SettingsEntries,
    ChatMessagesCache,
    AuditCache,
    DeviceCache,
    RuleCache,
    OutboxEntries,
  ],
)
class ArmxDatabase extends _$ArmxDatabase {
  /// Creates a database over an existing executor (tests inject `NativeDatabase.memory()`).
  ArmxDatabase(super.e);

  /// Opens the production database file (`armx_ai.sqlite`) via `drift_flutter`.
  ArmxDatabase.open() : super(driftDatabase(name: 'armx_ai'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        beforeOpen: (OpeningDetails details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // ---- Preferences ---------------------------------------------------------

  /// Reads a single preference value.
  Future<String?> readSetting(String key) async {
    final row = await (select(settingsEntries)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Reads every preference as a plain map.
  Future<Map<String, String>> readAllSettings() async {
    final rows = await select(settingsEntries).get();
    return <String, String>{for (final row in rows) row.key: row.value};
  }

  /// Writes (or overwrites) a preference.
  Future<void> writeSetting(String key, String value) async {
    await into(settingsEntries).insertOnConflictUpdate(
      SettingsEntriesCompanion.insert(
        key: key,
        value: value,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
  }

  /// Removes a preference.
  Future<void> deleteSetting(String key) async {
    await (delete(settingsEntries)..where((t) => t.key.equals(key))).go();
  }

  // ---- Chat cache ----------------------------------------------------------

  /// Most recent messages of [conversationId], oldest first.
  Future<List<ChatMessagesCacheData>> recentMessages(
    String conversationId, {
    int limit = 200,
  }) async {
    final query = select(chatMessagesCache)
      ..where((t) => t.conversationId.equals(conversationId))
      ..orderBy(<OrderClauseGenerator<$ChatMessagesCacheTable>>[
        ($ChatMessagesCacheTable t) => OrderingTerm.desc(t.at),
      ])
      ..limit(limit);
    final rows = await query.get();
    return rows.reversed.toList(growable: false);
  }

  /// Deletes every cached message of a conversation (used by "clear chat").
  Future<int> clearConversation(String conversationId) =>
      (delete(chatMessagesCache)..where((t) => t.conversationId.equals(conversationId))).go();

  /// Conversation id of the newest cached row, or `null` when the cache is empty.
  ///
  /// Lets the chat screen resume the previous transcript instead of silently
  /// starting a new conversation on every cold start.
  Future<String?> mostRecentConversationId() async {
    final query = select(chatMessagesCache)
      ..orderBy(<OrderClauseGenerator<$ChatMessagesCacheTable>>[
        ($ChatMessagesCacheTable t) => OrderingTerm.desc(t.at),
      ])
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row?.conversationId;
  }

  // ---- Audit cache ---------------------------------------------------------

  /// Cached audit entries, newest first.
  Future<List<AuditCacheData>> cachedAudit({int limit = 100}) {
    final query = select(auditCache)
      ..orderBy(<OrderClauseGenerator<$AuditCacheTable>>[
        ($AuditCacheTable t) => OrderingTerm.desc(t.at),
      ])
      ..limit(limit);
    return query.get();
  }

  /// Deletes every cached audit row.
  Future<int> clearAudit() => delete(auditCache).go();

  // ---- Outbox --------------------------------------------------------------

  /// Pending outbox entries, oldest first.
  Future<List<OutboxEntry>> pendingOutbox() {
    final query = select(outboxEntries)
      ..orderBy(<OrderClauseGenerator<$OutboxEntriesTable>>[
        ($OutboxEntriesTable t) => OrderingTerm.asc(t.createdAt),
      ]);
    return query.get();
  }

  /// Enqueues a side effect for retry.
  Future<int> enqueueOutbox({
    required String kind,
    required String payload,
  }) =>
      into(outboxEntries).insert(
        OutboxEntriesCompanion.insert(
          kind: kind,
          payload: payload,
          createdAt: DateTime.now().toUtc(),
        ),
      );

  /// Removes an outbox entry after it succeeded.
  Future<void> completeOutbox(int id) async {
    await (delete(outboxEntries)..where((t) => t.id.equals(id))).go();
  }

  /// Records a failed attempt with its error message.
  Future<void> failOutbox(int id, String error) async {
    await (update(outboxEntries)..where((t) => t.id.equals(id))).write(
      OutboxEntriesCompanion(
        attempts: const Value<int>(1),
        lastError: Value<String>(error),
      ),
    );
  }

  // ---- Wipe ----------------------------------------------------------------

  /// Erases every cached row. Used by the "delete local data" privacy action.
  Future<void> wipeCaches() async {
    await transaction(() async {
      await clearChat();
      await clearAudit();
      await delete(deviceCache).go();
      await delete(ruleCache).go();
      await delete(outboxEntries).go();
    });
  }

  /// Deletes all cached chat messages across conversations.
  Future<int> clearChat() => delete(chatMessagesCache).go();
}
