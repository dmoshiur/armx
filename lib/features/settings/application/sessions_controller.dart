// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import '../../../data/models/admin.dart';

/// The devices currently signed in to this account.
///
/// Revoking is destructive — it signs somebody out — so it is confirmed at the call site and
/// the row is only removed after the backend agrees. The list always comes from the server:
/// a session the server still considers live must not disappear from this screen.
class SessionsController extends AsyncNotifier<List<SessionInfo>> {
  @override
  Future<List<SessionInfo>> build() => ref.watch(armxApiProvider).sessions();

  /// Re-reads the list.
  Future<void> refresh() async {
    state = const AsyncValue<List<SessionInfo>>.loading();
    state = await AsyncValue.guard(build);
  }

  /// Revokes one session.
  Future<void> revoke(String sessionId) async {
    await ref.read(armxApiProvider).revokeSession(sessionId);
    await refresh();
  }

  /// Revokes every session except this one.
  ///
  /// Returns the number that really went. A partial result is reported as partial: claiming
  /// "all other devices signed out" when two of three refused would be a lie about access.
  Future<int> revokeOthers() async {
    final List<SessionInfo> current = state.value ?? const <SessionInfo>[];
    int revoked = 0;
    for (final SessionInfo session
        in current.where((SessionInfo s) => !s.current)) {
      try {
        await ref.read(armxApiProvider).revokeSession(session.id);
        revoked++;
      } on AppException {
        continue;
      }
    }
    await refresh();
    return revoked;
  }
}

/// The signed-in sessions.
final AsyncNotifierProvider<SessionsController, List<SessionInfo>>
    sessionsProvider =
    AsyncNotifierProvider<SessionsController, List<SessionInfo>>(
  SessionsController.new,
);
