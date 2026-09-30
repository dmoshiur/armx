// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

part of 'mock_api.dart';

/// MockDeviceDomain — one slice of [MockArmxApi].
///
/// Declared as a mixin in a part file so the mock backend stays split across small
/// files while every slice keeps access to the shared in-memory state.
mixin MockDeviceDomain on MockArmxApi {
  // ---- Devices -------------------------------------------------------------

  @override
  Future<List<ArmxDevice>> devices() async {
    await _delay();
    return List<ArmxDevice>.unmodifiable(_devices);
  }

  @override
  Future<DeviceCommandResult> sendCommand({
    required String deviceId,
    required String command,
    Map<String, Object?> parameters = const <String, Object?>{},
    RiskTier? riskTier,
  }) async {
    await _delay();
    _guardKillSwitch();
    final index = _devices.indexWhere((device) => device.id == deviceId);
    if (index < 0) {
      throw ApiException('Unknown device', statusCode: 404, serverCode: 'device_not_found');
    }
    final device = _devices[index];
    if (!device.online) {
      throw ApiException(
        'Device is offline; the command was queued by the mock.',
        statusCode: 409,
        serverCode: 'device_offline',
      );
    }
    final updated = _applyCommand(device, command, parameters);
    _devices = List<ArmxDevice>.of(_devices)..[index] = updated;
    _emit(DeviceStateEvent.fromDevice(updated, _clock.now().toUtc()));
    _logger.i('mock: command "$command" applied to ${device.id}');
    return DeviceCommandResult(
      deviceId: deviceId,
      accepted: true,
      at: _clock.now().toUtc(),
      message: 'Applied "$command"',
      commandId: 'cmd-${_uuid.v4().substring(0, 8)}',
    );
  }

  @override
  Future<void> activateScene(String sceneId) async {
    await _delay();
    _guardKillSwitch();
    _logger.i('mock: scene $sceneId activated');
  }
}
