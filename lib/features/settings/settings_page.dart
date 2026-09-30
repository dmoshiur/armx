// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

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
                  subtitle: l10n.orbStateListening,
                  trailing: stepBadge(context, 4),
                ),
                ArmxTile(
                  title: l10n.navChat,
                  subtitle: '${AppInfo.wakeWord} · ${prefs.wakeWordEnabled ? 'on' : 'off'}',
                  leading: const Icon(Icons.record_voice_over_outlined),
                  trailing: Switch(
                    value: prefs.wakeWordEnabled,
                    onChanged: repository.setWakeWordEnabled,
                  ),
                ),
                ArmxTile(
                  title: 'Wake word sensitivity',
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
                ArmxTile(
                  title: 'Speak replies automatically',
                  leading: const Icon(Icons.volume_up_outlined),
                  trailing: Switch(
                    value: prefs.ttsAutoSpeak,
                    onChanged: repository.setTtsAutoSpeak,
                  ),
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
                  title: 'App lock (biometric or PIN)',
                  subtitle: 'Uses the platform authenticator; no A.R.M.X PIN is stored',
                  leading: const Icon(Icons.fingerprint_rounded),
                  trailing: Switch(
                    value: prefs.appLockEnabled,
                    onChanged: repository.setAppLockEnabled,
                  ),
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
}
