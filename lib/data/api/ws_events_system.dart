// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

part of 'ws_events.dart';

/// A device reported new state.
final class DeviceStateEvent extends WsEvent {
  /// Creates a device state event.
  const DeviceStateEvent({
    required super.receivedAt,
    required this.deviceId,
    required this.online,
    required this.relayStates,
    required this.payload,
  });

  /// Device id.
  final String deviceId;

  /// Online flag.
  final bool online;

  /// Relay id → state (`ON`/`OFF`/`UNKNOWN`).
  final Map<String, String> relayStates;

  /// Raw payload, kept so the device list can merge partial updates.
  final Map<String, Object?> payload;

  /// Builds an event from a full device model (mock backend convenience).
  factory DeviceStateEvent.fromDevice(ArmxDevice device, DateTime receivedAt) => DeviceStateEvent(
        receivedAt: receivedAt,
        deviceId: device.id,
        online: device.online,
        relayStates: <String, String>{
          for (final relay in device.relays) relay.id: relay.state.name.toUpperCase(),
        },
        payload: device.toJson(),
      );

  @override
  String get type => WsEventType.deviceState;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        'device': <String, Object?>{
          'id': deviceId,
          'online': online,
          'relays': <Map<String, Object?>>[
            for (final entry in relayStates.entries)
              <String, Object?>{'id': entry.key, 'state': entry.value},
          ],
          ...payload,
        },
      };
}

/// The global kill-switch changed state.
final class SystemKilledEvent extends WsEvent {
  /// Creates a kill-switch event.
  const SystemKilledEvent({
    required super.receivedAt,
    required this.engaged,
    required this.reason,
    required this.actor,
  });

  /// True when the assistant is now disabled.
  final bool engaged;

  /// Why it was engaged/released.
  final String reason;

  /// Who triggered it.
  final String actor;

  @override
  String get type => WsEventType.systemKilled;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': type,
        'engaged': engaged,
        'reason': reason,
        'actor': actor,
      };
}

/// Keep-alive frame.
final class HeartbeatEvent extends WsEvent {
  /// Creates a heartbeat.
  const HeartbeatEvent({required super.receivedAt});

  @override
  String get type => WsEventType.heartbeat;

  @override
  Map<String, Object?> toJson() => <String, Object?>{'type': type};
}

/// An event this client version does not understand. Kept, never acted upon.
final class UnknownEvent extends WsEvent {
  /// Creates an unknown event.
  const UnknownEvent({
    required super.receivedAt,
    required this.rawType,
    required this.payload,
  });

  /// The `type` value exactly as received.
  final String rawType;

  /// Full decoded payload, for diagnostics only.
  final Map<String, Object?> payload;

  @override
  String get type => WsEventType.unknown;

  @override
  Map<String, Object?> toJson() => <String, Object?>{'type': type, ...payload};
}
