// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:drift/drift.dart';

import '../db/armx_database.dart';
import '../models/announcement.dart';

/// Local copy of the announcement log.
///
/// Both the Admin's per-user view and the user's own "My Activity" view read this table,
/// which is the whole point of rule 3: one store, two readers, no drift. Nothing is written
/// here that the owning user cannot also read on their own device.
class AnnouncementRepository {
  /// Creates a repository over [database].
  const AnnouncementRepository(this._database);

  final ArmxDatabase _database;

  /// Announcements for [targetUserId] (empty = every row, used by the Admin view).
  Future<List<Announcement>> recent({String targetUserId = '', int limit = 200}) async {
    final rows = await _database.announcements(targetUserId: targetUserId, limit: limit);
    return rows.map(_toAnnouncement).toList(growable: false);
  }

  /// Saves (or updates) one announcement.
  Future<void> save(Announcement announcement) => _database.upsertAnnouncement(
        AnnouncementsCacheCompanion.insert(
          id: announcement.id,
          fromUserId: announcement.fromUserId,
          fromName: announcement.fromName,
          scope: announcement.scope.name.toUpperCase(),
          targetUserId: announcement.targetUserId,
          targetLabel: announcement.targetLabel,
          audioPath: '',
          durationMs: Value<int>(announcement.durationMs),
          status: announcement.status.name.toUpperCase(),
          at: announcement.createdAt,
          playedAt: Value<DateTime?>(announcement.playedAt),
        ),
      );

  /// Records where the downloaded audio lives so a replay needs no second download.
  Future<void> setAudioPath(String id, String path) async {
    await (update(_database.announcementsCache)..where((t) => t.id.equals(id))).write(
      AnnouncementsCacheCompanion(audioPath: Value<String>(path)),
    );
  }

  /// Local path of the cached audio, or `null` when it has not been downloaded yet.
  Future<String?> audioPath(String id) async {
    final rows = await _database.announcements(limit: 200);
    for (final row in rows) {
      if (row.id == id) {
        return row.audioPath.isEmpty ? null : row.audioPath;
      }
    }
    return null;
  }

  /// Marks playback as finished.
  Future<void> markPlayed(String id, DateTime playedAt) =>
      _database.markAnnouncementPlayed(id, playedAt);

  /// Deletes every cached announcement.
  Future<void> clear() => _database.clearAnnouncements();

  Announcement _toAnnouncement(AnnouncementsCacheData row) => Announcement(
        id: row.id,
        fromUserId: row.fromUserId,
        fromName: row.fromName,
        scope: row.scope == 'BROADCAST' ? AnnouncementScope.broadcast : AnnouncementScope.user,
        targetUserId: row.targetUserId,
        targetLabel: row.targetLabel,
        audioUrl: '',
        durationMs: row.durationMs,
        status: _statusFromWire(row.status),
        createdAt: row.at,
        playedAt: row.playedAt,
      );

  static AnnouncementStatus _statusFromWire(String wire) => switch (wire) {
        'DELIVERED' => AnnouncementStatus.delivered,
        'PLAYED' => AnnouncementStatus.played,
        'MISSED' => AnnouncementStatus.missed,
        'REVOKED' => AnnouncementStatus.revoked,
        _ => AnnouncementStatus.queued,
      };
}
