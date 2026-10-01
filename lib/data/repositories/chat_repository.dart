// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:drift/drift.dart' show Value;

import '../db/armx_database.dart';
import '../models/chat.dart';

/// Persists the chat transcript in the local Drift cache.
///
/// The cache is the offline half of the chat: the transcript survives an app
/// restart and is wiped by the "delete local data" privacy action through
/// [ArmxDatabase.wipeCaches]. Rows use the same wire values as the API contract
/// (`USER`/`ASSISTANT`/`SYSTEM`/`TOOL`, `SENDING`/`STREAMING`/`SENT`/…), so the
/// mapping is a straight `toJson`/`fromJson` round-trip on [ChatMessage].
///
/// Tool-role rows are intentionally **not** written: an approval card is live
/// interaction state (its decision, verification and result arrive over the
/// socket), not history. A restored transcript therefore shows user, assistant
/// and system bubbles, and the next assistant turn re-raises any tool card the
/// server still considers pending.
class ChatRepository {
  /// Creates a repository over [database].
  const ChatRepository(this._database);

  final ArmxDatabase _database;

  /// Maximum number of messages restored into a transcript.
  static const int historyLimit = 200;

  /// Most recent messages of [conversationId], oldest first.
  Future<List<ChatMessage>> recent(String conversationId) async {
    final rows = await _database.recentMessages(conversationId, limit: historyLimit);
    return rows.map(_toMessage).toList(growable: false);
  }

  /// Inserts or updates one message. Tool-role messages are skipped.
  Future<void> save(ChatMessage message) async {
    if (message.role == ChatRole.tool) {
      return;
    }
    final json = message.toJson();
    await _database.into(_database.chatMessagesCache).insertOnConflictUpdate(
          ChatMessagesCacheCompanion.insert(
            id: json['id'] as String,
            conversationId: json['conversation_id'] as String,
            role: json['role'] as String,
            body: json['text'] as String,
            at: DateTime.parse(json['at'] as String),
            status: json['status'] as String,
            riskTier: Value<String?>(json['risk_tier'] as String?),
            toolCallId: Value<String?>(json['tool_call_id'] as String?),
            pending: const Value<bool>(false),
          ),
        );
  }

  /// Deletes every cached message of [conversationId] ("clear chat").
  Future<void> clear(String conversationId) => _database.clearConversation(conversationId);

  /// The conversation id of the newest cached row, or `null` for a fresh install.
  ///
  /// Used to resume the same transcript instead of starting a new one on every
  /// cold start.
  Future<String?> mostRecentConversationId() => _database.mostRecentConversationId();

  ChatMessage _toMessage(ChatMessagesCacheData row) => ChatMessage.fromJson(<String, Object?>{
        'id': row.id,
        'role': row.role,
        'text': row.body,
        'at': row.at.toIso8601String(),
        'status': row.status,
        'risk_tier': row.riskTier,
        'tool_call_id': row.toolCallId,
        'conversation_id': row.conversationId,
      });
}
