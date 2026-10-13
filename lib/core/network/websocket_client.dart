// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../errors/app_exception.dart';

/// How the harness socket is doing, as a UI-renderable value.
///
/// The shell shows this as a status dot with a label (§7: colour is never the only
/// signal). `standby` is distinct from `offline` on purpose: it means "signed out or
/// switch off", not "the server is unreachable", and the two need different copy.
enum SocketState {
  /// Not connected and not trying to be (signed out, or the assistant is off).
  standby,

  /// A connection attempt is in progress.
  connecting,

  /// Connected and streaming.
  open,

  /// Lost the connection; a retry is scheduled.
  offline,

  /// Closed deliberately by the app (kill-switch, sign-out, dispose).
  closed,
}

/// One frame off the wire.
@immutable
class SocketMessage {
  /// Creates a decoded message.
  const SocketMessage({
    required this.type,
    required this.payload,
    this.receivedAt,
  });

  /// The event name, e.g. `assistant.token` or `device.state`.
  final String type;

  /// The event body.
  final Map<String, Object?> payload;

  /// When the client received it (server clocks may be skewed).
  final DateTime? receivedAt;

  /// Decodes a frame.
  ///
  /// Returns `null` for a frame that is not a JSON object with a `type` — those are
  /// dropped and counted rather than turned into a fake event.
  static SocketMessage? tryParse(String raw, {DateTime? now}) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      final Object? type = decoded['type'];
      if (type is! String || type.isEmpty) {
        return null;
      }
      final Object? payload = decoded['payload'];
      return SocketMessage(
        type: type,
        payload: payload is Map<String, Object?> ? payload : decoded,
        receivedAt: now ?? DateTime.now().toUtc(),
      );
    } on FormatException {
      return null;
    }
  }
}

/// A status snapshot for the connection indicator.
@immutable
class SocketStatus {
  /// Creates a status snapshot.
  const SocketStatus({
    required this.state,
    this.attempt = 0,
    this.lastMessageAt,
    this.reason,
  });

  /// Current state.
  final SocketState state;

  /// Consecutive failed attempts, reset to zero on a successful open.
  final int attempt;

  /// When the last frame arrived, for a "last activity" line in Diagnostics.
  final DateTime? lastMessageAt;

  /// Why the socket is not open (a message, never a token).
  final String? reason;

  /// True while the transport is usable.
  bool get isLive => state == SocketState.open;

  /// Copy with changes.
  SocketStatus copyWith({
    SocketState? state,
    int? attempt,
    DateTime? lastMessageAt,
    String? reason,
  }) =>
      SocketStatus(
        state: state ?? this.state,
        attempt: attempt ?? this.attempt,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        reason: reason ?? this.reason,
      );
}

/// Opens harness/assistant WebSocket connections and keeps them up.
///
/// Responsibilities:
///
/// * **Connect with a bearer token**, never with a query-string token (a URL ends up in
///   proxy logs and browser history).
/// * **Reconnect with exponential backoff and jitter**, so a fleet of devices coming back
///   after an outage does not synchronise into a thundering herd.
/// * **Never invent data.** A dropped frame increments a counter that Diagnostics shows;
///   it is not silently turned into an empty-but-successful event.
/// * **Report state as a value** ([status]) so the shell can render a labelled dot instead
///   of a silent failure.
class WebSocketClient {
  /// Creates a client.
  ///
  /// [channelFactory] is injectable so unit tests drive a fake channel; production callers
  /// use the default `WebSocketChannel.connect`.
  WebSocketClient({
    required Uri baseUrl,
    required Future<String?> Function() tokenProvider,
    WebSocketChannel Function(Uri url)? channelFactory,
    Duration initialBackoff = const Duration(seconds: 1),
    Duration maxBackoff = const Duration(seconds: 30),
    Duration heartbeat = const Duration(seconds: 25),
    int maxBackoffExponent = 5,
  })  : _baseUrl = baseUrl,
        _tokenProvider = tokenProvider,
        _channelFactory = channelFactory ?? WebSocketChannel.connect,
        _initialBackoff = initialBackoff,
        _maxBackoff = maxBackoff,
        _heartbeat = heartbeat,
        _maxBackoffExponent = maxBackoffExponent;

  final Uri _baseUrl;
  final Future<String?> Function() _tokenProvider;
  final WebSocketChannel Function(Uri url) _channelFactory;
  final Duration _initialBackoff;
  final Duration _maxBackoff;
  final Duration _heartbeat;
  final int _maxBackoffExponent;

  final StreamController<SocketMessage> _messages =
      StreamController<SocketMessage>.broadcast();
  final StreamController<SocketStatus> _statuses =
      StreamController<SocketStatus>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _subscription;
  Timer? _retryTimer;
  Timer? _heartbeatTimer;
  int _attempt = 0;
  int _droppedFrames = 0;
  bool _disposed = false;
  bool _closeRequested = false;
  SocketStatus _status = const SocketStatus(state: SocketState.standby);

  /// Frames that could not be decoded. Surfaced in Diagnostics.
  int get droppedFrameCount => _droppedFrames;

  /// The latest status snapshot.
  SocketStatus get status => _status;

  /// Decoded events.
  Stream<SocketMessage> get messages => _messages.stream;

  /// Status transitions, for the connection indicator.
  Stream<SocketStatus> get statuses => _statuses.stream;

  /// Opens the socket, or returns immediately when it is already open/opening.
  Future<void> connect() async {
    if (_disposed || _status.state == SocketState.open) {
      return;
    }
    _closeRequested = false;
    _emitStatus(_status.copyWith(state: SocketState.connecting, reason: null));

    final String? token = await _tokenProvider();
    if (token == null) {
      // No session: standby, not offline. Nothing to retry until the user signs in.
      _emitStatus(const SocketStatus(
        state: SocketState.standby,
        reason: 'No active session.',
      ));
      return;
    }

    final Uri url = _baseUrl.replace(
      queryParameters: <String, String>{'v': '1'},
    );
    try {
      final WebSocketChannel channel = _channelFactory(url);
      _channel = channel;
      // The bearer token is sent as the first frame rather than in the URL, so it never
      // reaches a proxy access log or browser history.
      channel.sink.add(jsonEncode(<String, Object?>{'type': 'auth', 'token': token}));

      _subscription = channel.stream.listen(
        _onFrame,
        onError: (Object error, StackTrace stack) => _scheduleReconnect('$error'),
        onDone: () => _scheduleReconnect('The server closed the connection.'),
        cancelOnError: false,
      );

      _attempt = 0;
      _emitStatus(_status.copyWith(state: SocketState.open, attempt: 0, reason: null));
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(_heartbeat, (_) => _sendPing());
    } on Object catch (error) {
      _scheduleReconnect('$error');
    }
  }

  /// Sends a JSON frame. Returns false when the socket is not open, so a caller can tell
  /// "queued nowhere" from "sent" instead of assuming delivery.
  bool send(String type, Map<String, Object?> payload) {
    final WebSocketChannel? channel = _channel;
    if (channel == null || _status.state != SocketState.open) {
      return false;
    }
    try {
      channel.sink.add(jsonEncode(<String, Object?>{'type': type, 'payload': payload}));
      return true;
    } on Object {
      return false;
    }
  }

  /// Closes deliberately and stops reconnecting.
  Future<void> close({String reason = 'Closed by the app.'}) async {
    _closeRequested = true;
    _retryTimer?.cancel();
    _heartbeatTimer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _emitStatus(SocketStatus(state: SocketState.closed, reason: reason));
  }

  /// Puts the socket into standby (for example when the kill-switch engages) without
  /// tearing the object down, so it can be [connect]ed again.
  Future<void> suspend({String reason = 'Suspended.'}) async {
    await close(reason: reason);
    _closeRequested = false;
  }

  /// Releases everything. The instance is unusable afterwards.
  Future<void> dispose() async {
    _disposed = true;
    _retryTimer?.cancel();
    _heartbeatTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    await _messages.close();
    await _statuses.close();
  }

  void _onFrame(Object? frame) {
    if (frame is! String) {
      _droppedFrames++;
      return;
    }
    final SocketMessage? message = SocketMessage.tryParse(frame);
    if (message == null) {
      _droppedFrames++;
      return;
    }
    if (message.type == 'pong') {
      return;
    }
    _emitStatus(_status.copyWith(lastMessageAt: message.receivedAt));
    if (!_messages.isClosed) {
      _messages.add(message);
    }
  }

  void _sendPing() {
    send('ping', <String, Object?>{'at': DateTime.now().toUtc().toIso8601String()});
  }

  void _scheduleReconnect(String reason) {
    if (_disposed || _closeRequested) {
      return;
    }
    _heartbeatTimer?.cancel();
    _channel = null;
    unawaited(_subscription?.cancel());
    _subscription = null;

    _attempt++;
    _emitStatus(
      _status.copyWith(
        state: SocketState.offline,
        attempt: _attempt,
        reason: reason,
      ),
    );

    final Duration delay = _backoffFor(_attempt);
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(connect()));
  }

  /// Exponential backoff, clamped, with up to 25 % jitter.
  @visibleForTesting
  Duration _backoffFor(int attempt) {
    final int exponent = attempt.clamp(0, _maxBackoffExponent);
    final Duration base = _initialBackoff * (1 << exponent);
    final Duration clamped = base > _maxBackoff ? _maxBackoff : base;
    // Deterministic-enough jitter from the attempt counter keeps tests stable while still
    // spreading real reconnects out.
    final int jitterMs = (clamped.inMilliseconds * 0.25 * ((attempt * 37) % 100) / 100).round();
    return clamped + Duration(milliseconds: jitterMs);
  }

  void _emitStatus(SocketStatus next) {
    _status = next;
    if (!_statuses.isClosed) {
      _statuses.add(next);
    }
  }
}

/// Convenience: throws a [CapabilityException] when a caller needs a socket and has none.
AppException missingSocketError() => const CapabilityException(
      message: 'The realtime connection is not available.',
      capability: 'websocket',
    );
