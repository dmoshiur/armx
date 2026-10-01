// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_info.dart';
import '../../core/l10n/l10n.dart';
import '../../core/providers.dart';
import '../../core/router/routes.dart';
import '../../core/security/security_constants.dart';
import '../../core/theme/armx_colors.dart';
import '../../core/widgets/ambient_background.dart';
import '../../core/widgets/armx_controls.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/status_pill.dart';
import '../../data/models/preferences.dart';
import '../../features/assistant_mode/assistant_listening_status_panel.dart';
import '../../features/desktop/desktop_controller.dart';
import '../../features/intercom/intercom_controller.dart';
import '../auth/lock/app_lock_controller.dart';
import '../auth/session/auth_controller.dart';
import '../voice/voice_controller.dart';

/// Settings: language, theme, voice, privacy and the security switches.
///
/// Everything on this screen writes straight into the preferences table, which the app
/// watches reactively — flipping the theme here re-themes every open route immediately.
class SettingsPage extends ConsumerWidget {
  /// Creates the settings screen.
  const SettingsPage({super.key});

  /// Marks a control whose behaviour is completed in a later delivery step.
  static Widget stepBadge(BuildContext context, int step) => StatusPill(
        label: 'step $step',
        tone: SeverityTone.warning,
        compact: true,
        icon: Icons.schedule_rounded,
      );

  /// Desktop background mode only exists on Windows/macOS/Linux.
  static Widget _desktopOnly(BuildContext context) {
    final desktop = AppInfo.isDesktop;
    return desktop
        ? const SizedBox.shrink()
        : StatusPill(
            label: context.l10n.desktopOnly,
            tone: SeverityTone.neutral,
            compact: true,
          );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesProvider);
    final repository = ref.watch(preferencesRepositoryProvider);
    final l10n = context.l10n;
    final colors = ArmxColors.of(context);

    return Scaffold(
      appBar: ArmxAppBar(title: l10n.navSettings),
      body: ArmxBackground(
        child: ArmxPageBody(
          child: preferences.when(
            loading: () => const LoadingView(),
            error: (error, stackTrace) => ErrorView(
              error: error is Exception
                  ? StorageException('Preferences unavailable: ${error.runtimeType}')
                  : StorageException('Preferences unavailable'),
              onRetry: () => ref.invalidate(appPreferencesProvider),
            ),
            data: (prefs) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionHeader(title: l10n.themeTitle),
                GlassPanel(
                  child: Column(
                    children: <Widget>[
                      SegmentedButton<ThemeMode>(
                        segments: <ButtonSegment<ThemeMode>>[
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.system,
                            label: Text(l10n.themeSystem),
                            icon: const Icon(Icons.brightness_auto_outlined),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            label: Text(l10n.themeLight),
                            icon: const Icon(Icons.light_mode_outlined),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            label: Text(l10n.themeDark),
                            icon: const Icon(Icons.dark_mode_outlined),
                          ),
                        ],
                        selected: <ThemeMode>{
                          switch (prefs.themeMode) {
                            'light' => ThemeMode.light,
                            'dark' => ThemeMode.dark,
                            _ => ThemeMode.system,
                          },
                        },
                        onSelectionChanged: (selection) => repository
                            .setThemeMode(selection.first.name),
                        showSelectedIcon: false,
                      ),
                    ],
                  ),
                ),
                SectionHeader(title: l10n.languageTitle),
                // Deliberately not RadioListTile: the Material radio API is being
                // migrated (RadioGroup) and the tile pattern keeps the look consistent.
                for (final language in AppLanguage.values)
                  ArmxTile(
                    title: language.label(l10n),
                    leading: Icon(
                      AppLanguage.fromCode(prefs.language) == language
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                    ),
                    accent: AppLanguage.fromCode(prefs.language) == language
                        ? colors.cyan
                        : colors.muted,
                    onTap: () => repository.setLanguage(language.code),
                  ),
                SectionHeader(
                  title: l10n.settingsVoiceSection,
                  subtitle: l10n.voiceSubtitle,
                ),
                ArmxTile(
                  title: l10n.voiceOpenTitle,
                  subtitle: l10n.voiceOpenSubtitle,
                  leading: const Icon(Icons.graphic_eq_rounded),
                  accent: colors.cyan,
                  onTap: () => context.push(AppRoutes.voice),
                ),
                ArmxTile(
                  title: l10n.voiceWakeWordTitle,
                  subtitle:
                      '${AppInfo.wakeWord} · ${prefs.wakeWordEnabled ? l10n.desktopAutostartOn : l10n.desktopAutostartOff}',
                  leading: const Icon(Icons.record_voice_over_outlined),
                  // Routed through the voice controller (never straight to preferences):
                  // arming must start the platform's visible background listener, and
                  // disarming must stop it.
                  trailing: Switch(
                    value: prefs.wakeWordEnabled,
                    onChanged: (value) => ref
                        .read(voiceControllerProvider.notifier)
                        .setWakeWordEnabled(value),
                  ),
                ),
                ArmxTile(
                  title: l10n.voiceWakeWordSensitivityTitle,
                  subtitle: prefs.wakeWordSensitivity.toStringAsFixed(2),
                  leading: const Icon(Icons.hearing_outlined),
                  trailing: SizedBox(
                    width: 140,
                    child: Slider(
                      value: prefs.wakeWordSensitivity.clamp(0.0, 1.0),
                      onChanged: repository.setWakeWordSensitivity,
                    ),
                  ),
                ),
                SectionHeader(
                  title: l10n.assistantModeSection,
                  subtitle: l10n.assistantModeSubtitle,
                ),
                const AssistantListeningStatusPanel(),
                ArmxTile(
                  title: l10n.voiceAutoSpeakTitle,
                  subtitle: l10n.voiceAutoSpeakSubtitle,
                  leading: const Icon(Icons.volume_up_outlined),
                  trailing: Switch(
                    value: prefs.ttsAutoSpeak,
                    onChanged: ref.read(voiceControllerProvider.notifier).setAutoSpeak,
                  ),
                ),
                SectionHeader(
                  title: l10n.desktopBackgroundSection,
                  subtitle: l10n.desktopBackgroundSubtitle,
                  trailing: _desktopOnly(context),
                ),
                ArmxTile(
                  title: l10n.desktopAutostartTitle,
                  subtitle: l10n.desktopAutostartSubtitle,
                  leading: const Icon(Icons.login_rounded),
                  trailing: Switch(
                    value: prefs.autostartEnabled,
                    onChanged: (bool enabled) => unawaited(
                      ref.read(desktopControllerProvider.notifier).setLaunchAtLogin(enabled),
                    ),
                  ),
                ),
                ArmxTile(
                  title: l10n.desktopHotkeyTitle,
                  subtitle: prefs.desktopHotkey,
                  leading: const Icon(Icons.keyboard_command_key_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.desktopReadiness),
                ),
                ArmxTile(
                  title: l10n.desktopReadinessTitle,
                  subtitle: l10n.desktopReadinessFootnote,
                  leading: const Icon(Icons.fact_check_outlined),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.desktopReadiness),
                ),
                SectionHeader(
                  title: l10n.intercomEnabledTitle,
                  subtitle: l10n.intercomEnabledSubtitle,
                ),
                ArmxTile(
                  title: l10n.intercomConsentTitle,
                  subtitle: prefs.intercomConsent
                      ? l10n.desktopAutostartOn
                      : l10n.desktopAutostartOff,
                  leading: const Icon(Icons.record_voice_over_outlined),
                  trailing: Switch(
                    value: prefs.intercomConsent,
                    onChanged: (bool enabled) => unawaited(
                      ref.read(intercomControllerProvider.notifier).setConsent(
                            enabled: enabled,
                            allowWhileLocked: prefs.intercomConsentLocked,
                          ),
                    ),
                  ),
                ),
                ArmxTile(
                  title: l10n.intercomConsentLockedTitle,
                  subtitle: l10n.intercomConsentLockedBody,
                  leading: const Icon(Icons.lock_outline_rounded),
                  trailing: Switch(
                    value: prefs.intercomConsentLocked,
                    onChanged: prefs.intercomConsent
                        ? (bool enabled) => unawaited(
                              ref.read(intercomControllerProvider.notifier).setConsent(
                                    enabled: true,
                                    allowWhileLocked: enabled,
                                  ),
                            )
                        : null,
                  ),
                ),
                ArmxTile(
                  title: l10n.intercomTalkTitle,
                  subtitle: l10n.intercomRecipientsSubtitle,
                  leading: const Icon(Icons.campaign_outlined),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.intercomTalk),
                ),
                ArmxTile(
                  title: l10n.intercomMyActivityTitle,
                  subtitle: l10n.intercomMyActivitySubtitle,
                  leading: const Icon(Icons.history_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.intercomActivity),
                ),
                SectionHeader(
                  title: l10n.settingsVisionSection,
                  trailing: stepBadge(context, 7),
                ),
                ArmxTile(
                  title: 'Camera enabled',
                  subtitle: prefs.cameraEnabled ? l10n.commonEnable : l10n.commonDisable,
                  leading: Icon(
                    prefs.cameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                  ),
                  accent: prefs.cameraEnabled ? colors.green : colors.muted,
                  trailing: Switch(
                    value: prefs.cameraEnabled,
                    onChanged: repository.setCameraEnabled,
                  ),
                ),
                ArmxTile(
                  title: 'Microphone enabled',
                  leading: const Icon(Icons.mic_none_rounded),
                  trailing: Switch(
                    value: prefs.microphoneEnabled,
                    onChanged: repository.setMicrophoneEnabled,
                  ),
                ),
                ArmxTile(
                  title: 'Palm gesture (open palm to wake/stop)',
                  leading: const Icon(Icons.pan_tool_outlined),
                  trailing: Switch(
                    value: prefs.palmGestureEnabled,
                    onChanged: repository.setPalmGestureEnabled,
                  ),
                ),
                ArmxTile(
                  title: 'Face match threshold',
                  subtitle: prefs.faceMatchThreshold.toStringAsFixed(2),
                  leading: const Icon(Icons.tune_rounded),
                  trailing: SizedBox(
                    width: 140,
                    child: Slider(
                      min: SecurityConstants.minFaceThreshold,
                      max: SecurityConstants.maxFaceThreshold,
                      value: prefs.faceMatchThreshold.clamp(
                        SecurityConstants.minFaceThreshold,
                        SecurityConstants.maxFaceThreshold,
                      ),
                      onChanged: repository.setFaceMatchThreshold,
                    ),
                  ),
                ),
                SectionHeader(title: l10n.settingsSecuritySection),
                ArmxTile(
                  title: l10n.appLockSettingTitle,
                  subtitle: l10n.appLockSettingSubtitle,
                  leading: const Icon(Icons.fingerprint_rounded),
                  trailing: Switch(
                    value: prefs.appLockEnabled,
                    onChanged: (value) => _setAppLock(ref, prefs, value),
                  ),
                ),
                ArmxTile(
                  title: l10n.appLockTimeoutTitle,
                  subtitle: _autoLockLabel(l10n, prefs.autoLockTimeoutSeconds),
                  leading: const Icon(Icons.timer_outlined),
                ),
                GlassPanel(
                  child: SegmentedButton<int>(
                    segments: <ButtonSegment<int>>[
                      ButtonSegment<int>(
                        value: SecurityConstants.autoLockTimeoutOptions[0],
                        label: Text(l10n.appLockTimeoutImmediate),
                        icon: const Icon(Icons.flash_off_outlined),
                      ),
                      ButtonSegment<int>(
                        value: SecurityConstants.autoLockTimeoutOptions[1],
                        label: Text(l10n.appLockTimeout30s),
                        icon: const Icon(Icons.timer_outlined),
                      ),
                      ButtonSegment<int>(
                        value: SecurityConstants.autoLockTimeoutOptions[2],
                        label: Text(l10n.appLockTimeout60s),
                        icon: const Icon(Icons.hourglass_bottom_rounded),
                      ),
                      ButtonSegment<int>(
                        value: SecurityConstants.autoLockTimeoutOptions[3],
                        label: Text(l10n.appLockTimeout300s),
                        icon: const Icon(Icons.schedule_rounded),
                      ),
                    ],
                    selected: <int>{
                      SecurityConstants.autoLockTimeoutOptions
                              .contains(prefs.autoLockTimeoutSeconds)
                          ? prefs.autoLockTimeoutSeconds
                          : SecurityConstants.defaultAutoLockSeconds,
                    },
                    onSelectionChanged: (selection) =>
                        _setAutoLockTimeout(ref, prefs, selection.first),
                    showSelectedIcon: false,
                  ),
                ),
                ArmxTile(
                  title: l10n.sessionSignOut,
                  subtitle: l10n.sessionSignOutSubtitle,
                  leading: const Icon(Icons.logout_rounded),
                  onTap: () => _confirmSignOut(context, ref),
                ),
                ArmxTile(
                  title: l10n.sessionUnpair,
                  subtitle: l10n.sessionUnpairSubtitle,
                  leading: const Icon(Icons.link_off_rounded),
                  accent: colors.red,
                  onTap: () => _confirmUnpair(context, ref),
                ),
                SectionHeader(
                  title: l10n.settingsPrivacySection,
                  trailing: stepBadge(context, 10),
                ),
                ArmxTile(
                  title: 'Delete all biometric data',
                  subtitle: 'Face templates and voice prints only ever exist on this device',
                  leading: const Icon(Icons.delete_forever_outlined),
                  accent: colors.red,
                  onTap: () => _confirmBiometricDeletion(context, ref),
                ),
                SectionHeader(title: l10n.aboutTitle),
                ArmxTile(
                  title: l10n.aboutTitle,
                  subtitle: '${AppInfo.productName} · v${AppInfo.versionLabel}',
                  leading: const Icon(Icons.info_outline_rounded),
                  onTap: () => context.push(AppRoutes.about),
                ),
                ArmxTile(
                  title: l10n.diagnosticsTitle,
                  leading: const Icon(Icons.monitor_heart_outlined),
                  onTap: () => context.push(AppRoutes.diagnostics),
                ),
                ArmxTile(
                  title: l10n.designSystemTitle,
                  subtitle: l10n.designSystemSubtitle,
                  leading: const Icon(Icons.palette_outlined),
                  onTap: () => context.push(AppRoutes.designSystem),
                ),
                const SizedBox(height: 28),
                Center(
                  child: Text(
                    AppInfo.credit,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: colors.muted),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Persists the app-lock toggle and re-configures the live gate in one step.
  Future<void> _setAppLock(WidgetRef ref, AppPreferences prefs, bool enabled) async {
    await ref.read(preferencesRepositoryProvider).setAppLockEnabled(enabled);
    await ref
        .read(appLockControllerProvider.notifier)
        .configure(enabled: enabled, timeoutSeconds: prefs.autoLockTimeoutSeconds);
  }

  /// Persists the auto-lock timeout and re-configures the live gate.
  Future<void> _setAutoLockTimeout(WidgetRef ref, AppPreferences prefs, int seconds) async {
    await ref.read(preferencesRepositoryProvider).setAutoLockTimeout(seconds);
    await ref
        .read(appLockControllerProvider.notifier)
        .configure(enabled: prefs.appLockEnabled, timeoutSeconds: seconds);
  }

  /// Localized label for the stored auto-lock timeout (unknown values fall back
  /// to the default option so the selector never renders an empty selection).
  String _autoLockLabel(AppLocalizations l10n, int seconds) {
    final safe = SecurityConstants.autoLockTimeoutOptions.contains(seconds)
        ? seconds
        : SecurityConstants.defaultAutoLockSeconds;
    return switch (safe) {
      0 => l10n.appLockTimeoutImmediate,
      30 => l10n.appLockTimeout30s,
      60 => l10n.appLockTimeout60s,
      _ => l10n.appLockTimeout300s,
    };
  }

  Future<void> _confirmBiometricDeletion(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ArmxColors.of(context).panel,
        title: Text(l10n.commonDelete),
        content: const Text(
          'This erases the encrypted face template and voice print, and clears the '
          'owner-assertion key. Tokens and pairings are kept.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(preferencesRepositoryProvider).setCameraEnabled(false);
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ArmxColors.of(context).panel,
        title: Text(l10n.sessionSignOutTitle),
        content: Text(l10n.sessionSignOutBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.sessionSignOut),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(authControllerProvider.notifier).signOut();
      if (context.mounted) {
        context.go(AppRoutes.login);
      }
    }
  }

  Future<void> _confirmUnpair(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ArmxColors.of(context).panel,
        title: Text(l10n.sessionUnpairTitle),
        content: Text(l10n.sessionUnpairBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.sessionUnpair),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(authControllerProvider.notifier).unpair();
      if (context.mounted) {
        context.go(AppRoutes.pairing);
      }
    }
  }
}
