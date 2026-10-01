// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Outcome of trying to become the app's single running instance.
enum SingleInstanceResult {
  /// This process now owns the lock and must serve the tray/hotkey.
  primary,

  /// Another process is already running; this one must signal it and exit.
  secondary,
}

/// Single-instance guard with an "activate" channel.
///
/// Why not a package: `single_instance`-style plugins cover Windows and macOS but leave
/// Linux to a lock file only, which cannot tell the running copy to show itself. This
/// implementation uses the same primitive on all three:
///
/// 1. the lock file is opened and `File.lock()`ed exclusively — a second process fails the
///    lock immediately;
/// 2. the primary writes its loopback TCP port into the file;
/// 3. a secondary process reads that port, connects, sends `activate`, and exits.
///
/// The hotkey press therefore focuses the existing popup instead of spawning a second
/// copy, and a double-click on the file/launcher behaves the same way.
class SingleInstanceGuard {
  SingleInstanceGuard._({
    required this.result,
    required this.port,
    RandomAccessFile? handle,
  }) : _handle = handle;

  /// Whether this process owns the app.
  final SingleInstanceResult result;

  /// Loopback port the primary listens on (`0` for a secondary process).
  final int port;

  final RandomAccessFile? _handle;
  ServerSocket? _server;

  /// True when this process is the one that must run.
  bool get isPrimary => result == SingleInstanceResult.primary;

  /// Acquires the guard, creating [lockPath] and its directory if needed.
  ///
  /// Never throws: any filesystem failure degrades to "primary" so the app still starts
  /// (a read-only home directory must not brick launch-at-login).
  static Future<SingleInstanceGuard> acquire(String lockPath) async {
    try {
      final file = File(lockPath);
      await file.parent.create(recursive: true);
      final handle = file.openSync(mode: FileMode.append);
      try {
        handle.lockSync();
      } on FileSystemException {
        await handle.close();
        return _signalExisting(file);
      }
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      await handle.truncate(0);
      await handle.writeString(utf8.encode(jsonEncode(<String, Object?>{'port': port})));
      await handle.flush();
      final guard = SingleInstanceGuard._(
        result: SingleInstanceResult.primary,
        port: port,
        handle: handle,
      );
      guard._server = server;
      server.listen((Socket socket) {
        socket
          ..listen((List<int> data) {
            if (utf8.decode(data).trim() == 'activate') {
              _activateCallback?.call();
            }
          })
          ..done.then((_) {});
      });
      return guard;
    } on Object catch (error) {
      debugPrint('single-instance: lock unavailable ($error), running as primary');
      return SingleInstanceGuard._(result: SingleInstanceResult.primary, port: 0);
    }
  }

  static Future<SingleInstanceGuard> _signalExisting(File file) async {
    try {
      final raw = await file.readAsString();
      final port = (jsonDecode(raw) as Map<String, Object?>)['port'];
      if (port is int && port > 0) {
        final socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
          timeout: const Duration(seconds: 2),
        );
        socket.add(utf8.encode('activate'));
        await socket.flush();
        await socket.close();
      }
    } on Object {
      // The primary is shutting down; treating this process as secondary would leave the
      // user with nothing running, so fall through to primary.
      return SingleInstanceGuard._(result: SingleInstanceResult.primary, port: 0);
    }
    return SingleInstanceGuard._(result: SingleInstanceResult.secondary, port: 0);
  }

  /// Called when another process asks this one to activate (set by the bootstrap).
  static void Function()? _activateCallback;

  /// Registers the handler for an "activate" message from a second launch.
  set onActivate(void Function()? callback) => _activateCallback = callback;

  /// Releases the lock and closes the socket. Safe to call twice.
  Future<void> release() async {
    await _server?.close();
    _server = null;
    try {
      await _handle?.close();
    } on Object {
      // Releasing the OS lock is best effort.
    }
  }
}
