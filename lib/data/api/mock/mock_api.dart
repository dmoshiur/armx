// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.


import 'dart:async';
import 'dart:math';

import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/security/risk_tier.dart';
import '../../../core/utils/clock.dart';
import '../../models/admin.dart';
import '../../models/audit_entry.dart';
import '../../models/auth.dart';
import '../../models/chat.dart';
import '../../models/device.dart';
import '../../models/rules.dart';
import '../../models/unlock.dart';
import '../armx_api.dart';
import '../ws_events.dart';
import 'mock_admin_data.dart';
import 'mock_assistant.dart';
import 'mock_audit_data.dart';
import 'mock_data.dart';
import 'mock_rule_data.dart';
import 'mock_unlock_data.dart';

// The mock is split across part files (auth, devices, admin, unlock, rules, chat) so no
// single source file grows past the 300-line budget. Parts share one library, which is
// what lets every slice touch the same in-memory state.
part 'mock_admin_domain.dart';
part 'mock_auth_domain.dart';
part 'mock_chat_domain.dart';
part 'mock_device_domain.dart';
part 'mock_rule_domain.dart';
part 'mock_unlock_domain.dart';

/// Deterministic outcomes the mock can answer for `POST /devices/pair`.
///
/// The demo/test flips [MockBackendControl.pairingOutcome] between calls, so a
/// `pending` request can be re-polled later and observe the approval — exactly the
/// state machine the pairing screen is built against.
enum MockPairingOutcome {
  /// The owner approves immediately (default).
  approved,

  /// The request stays queued as `pending` until the knob changes.
  pending,

  /// The owner refuses the device (`403 auth_pairing_rejected`).
  rejected,
}

/// Fault-injection and pacing knobs for the mock backend.
///
/// The demo builds wire these to on-screen switches so a tester can watch the app deal with
/// slow, offline and failing servers without touching any code.
class MockBackendControl {
  /// Creates a control block.
  MockBackendControl({
    this.latency = const Duration(milliseconds: 140),
    this.offline = false,
    this.failNext = false,
    this.pairingOutcome = MockPairingOutcome.approved,
    this.toolCallDelay = const Duration(milliseconds: 900),
    this.tokenInterval = const Duration(milliseconds: 45),
  });

  /// Simulated round-trip time for every REST call.
  Duration latency;

  /// When true every call throws [NetworkException] (airplane-mode simulation).
  bool offline;

  /// When true the next call throws a 503 [ApiException], then resets.
  bool failNext;

  /// What `POST /devices/pair` answers; flip `pending → approved` to simulate the
  /// owner tapping Approve in the admin panel.
  MockPairingOutcome pairingOutcome;

  /// Delay before a tool call reports its result.
  Duration toolCallDelay;

  /// Delay between two streamed assistant tokens.
  Duration tokenInterval;
}
/// Deterministic in-memory implementation of [ArmxApi].
///
/// * 4 fake devices, 12 fake audit entries, 6 tool switches, 3 unlock targets, 3 rules;
/// * a fake streaming assistant that emits `assistant.token` frames then `assistant.done`;
/// * realistic risk tiers so the approval and verification flows can be exercised;
/// * mutable state: toggling a relay really changes the device list, the kill-switch really
///   blocks tool decisions and closes the event channel.
class MockArmxApi
    with MockAuthDomain,
        MockDeviceDomain,
        MockAdminDomain,
        MockUnlockDomain,
        MockRuleDomain,
        MockChatDomain
    implements ArmxApi {
  /// Creates the mock backend. Everything it returns derives from [clock] and [random], so
  /// two instances with the same seed behave identically.
  MockArmxApi({
    required this.config,
    required Logger logger,
    required Clock clock,
    required Random random,
    MockBackendControl? control,
    this.localeCode = 'en',
  })  : _logger = logger,
        _clock = clock,
        _random = random,
        control = control ?? MockBackendControl() {
    final anchor = _clock.now().toUtc();
    _devices = MockData.devices(anchor);
    _audit = MockAuditData.audit(anchor);
    _tools = MockAdminData.tools();
    _targets = MockUnlockData.unlockTargets(anchor);
    _rules = MockRuleData.rules(anchor);
  }

  /// A fixed seed so demo data never changes between runs.
  static Random deterministicRandom() => Random(20260101);

  /// Configuration this mock was built from (mock flag, thresholds, latency).
  final AppConfig config;

  /// Pacing/fault-injection knobs, exposed to the diagnostics screen.
  final MockBackendControl control;

  /// Locale used for canned assistant replies (`en` or `bn`).
  String localeCode;

  final Logger _logger;
  final Clock _clock;
  final Random _random;
  final Uuid _uuid = const Uuid();

  late List<ArmxDevice> _devices;
  late List<AuditEntry> _audit;
  late List<ToolToggle> _tools;
  late List<UnlockTarget> _targets;
  late List<AutomationRule> _rules;

  final Map<String, ToolCall> _toolCalls = <String, ToolCall>{};
  StreamController<WsEvent>? _channel;
  bool _assistantEnabled = true;
  bool _killSwitchEngaged = false;
  int _messageCounter = 0;
  int _streamGeneration = 0;
  bool _disposed = false;

  /// Current conversation id used by the mock transcript.
  String get conversationId => MockAssistant.conversationIdFor(1);

  @override
  Future<void> dispose() async {
    _disposed = true;
    _streamGeneration++;
    await _channel?.close();
    _channel = null;
  }

  // ---- Internals -----------------------------------------------------------

  AdminState _adminState() => AdminState(
        assistantEnabled: _assistantEnabled,
        killSwitchEngaged: _killSwitchEngaged,
        tools: List<ToolToggle>.unmodifiable(_tools),
        updatedAt: _clock.now().toUtc(),
        engagedBy: _killSwitchEngaged ? 'owner' : '',
        engagedReason: _killSwitchEngaged ? 'Engaged from the app bar' : '',
      );

  ArmxDevice _applyCommand(
    ArmxDevice device,
    String command,
    Map<String, Object?> parameters,
  ) {
    final separator = command.indexOf(':');
    if (separator < 0) {
      return device;
    }
    final relayId = command.substring(0, separator);
    final value = command.substring(separator + 1).toUpperCase();
    final relays = device.relays
        .map(
          (relay) => relay.id == relayId
              ? relay.copyWith(
                  state: value == 'ON' ? RelayState.on : RelayState.off,
                  lastChangedAt: _clock.now().toUtc(),
                )
              : relay,
        )
        .toList(growable: false);
    return device.copyWith(relays: relays, lastSeenAt: _clock.now().toUtc());
  }

  void _applyToolEffect(ToolCall call) {
    final parameters = call.parameters;
    final deviceId = parameters['device_id'] as String?;
    final payload = parameters['payload'];
    if (deviceId == null || payload is! Map) {
      return;
    }
    final relay = payload['relay']?.toString();
    final state = payload['state']?.toString();
    if (relay == null || state == null) {
      return;
    }
    final index = _devices.indexWhere((device) => device.id == deviceId);
    if (index < 0) {
      return;
    }
    final updated = _applyCommand(_devices[index], '$relay:$state', const <String, Object?>{});
    _devices = List<ArmxDevice>.of(_devices)..[index] = updated;
    _emit(DeviceStateEvent.fromDevice(updated, _clock.now().toUtc()));
  }

  StreamController<WsEvent> _ensureChannel() {
    final existing = _channel;
    if (existing != null && !existing.isClosed) {
      return existing;
    }
    final created = StreamController<WsEvent>.broadcast();
    _channel = created;
    return created;
  }

  void _closeChannel() {
    final channel = _channel;
    _channel = null;
    if (channel != null && !channel.isClosed) {
      unawaited(channel.close());
    }
  }

  void _emit(WsEvent event) {
    final channel = _channel;
    if (_disposed || channel == null || channel.isClosed) {
      return;
    }
    channel.add(event);
  }

  void _guardKillSwitch() {
    if (_killSwitchEngaged) {
      throw const KillSwitchActiveException();
    }
  }

  Future<void> _delay() async {
    if (control.offline) {
      throw const NetworkException('Simulated offline mode (mock backend)');
    }
    if (control.failNext) {
      control.failNext = false;
      throw const ApiException(
        'Simulated server error',
        statusCode: 503,
        serverCode: 'mock_injected_failure',
      );
    }
    if (control.latency > Duration.zero) {
      await Future<void>.delayed(control.latency);
    }
  }
}
