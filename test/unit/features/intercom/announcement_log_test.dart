// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/data/db/armx_database.dart';
import 'package:armx_ai/data/models/announcement.dart';
import 'package:armx_ai/data/repositories/announcement_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rule 3 (mutual visibility) is a storage property: both screens read ONE table, so the
/// only way they could disagree is if the table itself were wrong.
void main() {
  late ArmxDatabase database;
  late AnnouncementRepository repository;

  final at = DateTime.utc(2026, 10, 1, 9);
  final later = DateTime.utc(2026, 10, 1, 10);

  Announcement announcement({
    required String id,
    String targetUserId = 'u1',
    AnnouncementStatus status = AnnouncementStatus.delivered,
    DateTime? createdAt,
    bool broadcast = false,
  }) =>
      Announcement(
        id: id,
        fromUserId: 'admin-1',
        fromName: 'Admin',
        scope: broadcast ? AnnouncementScope.broadcast : AnnouncementScope.user,
        targetUserId: targetUserId,
        targetLabel: broadcast ? 'all opted-in devices' : 'Living room tablet',
        durationMs: 400,
        status: status,
        createdAt: createdAt ?? at,
        playedAt: status == AnnouncementStatus.played ? later : null,
      );

  setUp(() {
    database = ArmxDatabase(NativeDatabase.memory());
    repository = AnnouncementRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('saved announcements come back with the same status and timestamps', () async {
    await repository.save(announcement(id: 'a1'));
    final rows = await repository.recent();
    expect(rows.length, 1);
    expect(rows.single.id, 'a1');
    expect(rows.single.status, AnnouncementStatus.delivered);
    expect(rows.single.createdAt, at);
  });

  test('the newest announcement is first, so both views are chronological', () async {
    await repository.save(announcement(id: 'a1', createdAt: at));
    await repository.save(announcement(id: 'a2', createdAt: later));

    final rows = await repository.recent();
    expect(rows.map((Announcement a) => a.id), <String>['a2', 'a1']);
  });

  test('the user view and the admin view read the same rows', () async {
    await repository.save(announcement(id: 'a1', targetUserId: 'u1'));
    await repository.save(announcement(id: 'a2', targetUserId: 'u2'));

    final mine = await repository.recent(targetUserId: 'u1');
    final admins = await repository.recent();

    expect(mine.map((Announcement a) => a.id), <String>['a1']);
    expect(admins.length, 2, reason: 'the admin panel sees every device');
    // Whatever the admin can see about u1, u1 can see about itself.
    expect(mine.single.id, admins.last.id);
  });

  test('saving the same id twice updates the row instead of duplicating it', () async {
    await repository.save(announcement(id: 'a1'));
    await repository.save(announcement(id: 'a1', status: AnnouncementStatus.played));

    final rows = await repository.recent();
    expect(rows.length, 1);
    expect(rows.single.status, AnnouncementStatus.played);
    expect(rows.single.playedAt, later);
  });

  test('markPlayed records the outcome on the shared row', () async {
    await repository.save(announcement(id: 'a1'));
    await repository.markPlayed('a1', later);

    final rows = await repository.recent();
    expect(rows.single.status, AnnouncementStatus.played);
    expect(rows.single.playedAt, later);
  });

  test('a broadcast row is stored once and visible in the unfiltered view', () async {
    await repository.save(announcement(id: 'b1', broadcast: true, targetUserId: ''));
    final rows = await repository.recent();
    expect(rows.length, 1);
    expect(rows.single.isBroadcast, isTrue);
    expect(rows.single.targetSummary, 'all opted-in devices');
  });

  test('a MISSED announcement is kept in the log, not dropped', () async {
    await repository.save(announcement(id: 'm1', status: AnnouncementStatus.missed));
    final rows = await repository.recent();
    expect(rows.single.status, AnnouncementStatus.missed);
  });

  test('clearing the local copy leaves the schema usable', () async {
    await repository.save(announcement(id: 'a1'));
    await repository.clear();
    expect(await repository.recent(), isEmpty);

    await repository.save(announcement(id: 'a2'));
    expect((await repository.recent()).single.id, 'a2');
  });

  test('wipeCaches also clears the announcement log', () async {
    await repository.save(announcement(id: 'a1'));
    await database.wipeCaches();
    expect(await repository.recent(), isEmpty);
  });
}
