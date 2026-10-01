// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_info.dart';
import '../../core/errors/app_exception.dart';
import '../../core/l10n/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme/armx_colors.dart';
import '../../core/widgets/ambient_background.dart';
import '../../core/widgets/armx_controls.dart';
import '../../core/widgets/state_views.dart';
import '../../data/api/mock/mock_api.dart';
import '../bootstrap/bootstrap.dart';

/// Diagnostics: redacted configuration, bootstrap warnings, mock-backend controls and the
/// recent log lines captured by the in-memory ring buffer.
///
/// Nothing on this screen ever shows a token, key or biometric value — the logger redacts
/// before a line is stored.
class DiagnosticsPage extends ConsumerWidget {
  /// Creates the diagnostics screen.
  DiagnosticsPage({super.key});

  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ArmxColors.of(context);
    final l10n = context.l10n;
    final buffer = ref.watch(logBufferProvider);
    final bootstrap = ref.watch(bootstrapProvider);

    return Scaffold(
      appBar: ArmxAppBar(
        title: l10n.diagnosticsTitle,
        actions: <Widget>[
          IconButton(
            tooltip: l10n.diagnosticsClearLogs,
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: buffer.clear,
          ),
        ],
      ),
      body: ArmxBackground(
        child: ArmxPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SectionHeader(title: l10n.diagnosticsConfiguration),
              bootstrap.when(
                loading: () => const LoadingView(compact: true),
                error: (error, stackTrace) => ErrorView(
                  error: error is AppException
                      ? error
                      : StorageException('Bootstrap failed: ${error.runtimeType}'),
                ),
                data: (report) => GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _MonoLine(text: report.config.describe()),
                      const Divider(height: 20),
                      _MonoLine(
                        text: 'secureStorage=${report.secureStorageAvailable} '
                            'mock=${report.config.useMockBackend} '
                            'startup=${report.duration.inMilliseconds}ms',
                      ),
                      const Divider(height: 20),
                      _MonoLine(text: 'version=${AppInfo.versionLabel} release=${AppInfo.isRelease}'),
                      if (report.warnings.isNotEmpty) ...<Widget>[
                        const Divider(height: 20),
                        for (final warning in report.warnings)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Icon(Icons.warning_amber_rounded, size: 16, color: colors.amber),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    warning,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              SectionHeader(
                title: l10n.a11yLoading,
                subtitle: 'Mock backend controls (only present with USE_MOCK=true)',
              ),
              _MockControls(),
              SectionHeader(
                title: l10n.diagnosticsLogLines,
                subtitle: '${buffer.records.length} line(s)',
                trailing: TextButton.icon(
                  onPressed: () async {
                    final text = buffer.records
                        .map((record) => '${record.time.toIso8601String()} ${record.level} '
                            '${record.message}')
                        .join('\n');
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.commonCopied)),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: Text(l10n.diagnosticsCopyLogs),
                ),
              ),
              GlassPanel(
                child: buffer.records.isEmpty
                    ? Text(l10n.commonEmpty, style: Theme.of(context).textTheme.bodySmall)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (final record in buffer.records.reversed.take(60))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${record.level.padRight(5)} ${record.message}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontFamily: 'JetBrainsMono',
                                      fontSize: 11.5,
                                      color: switch (record.level) {
                                        'ERROR' || 'FATAL' => colors.red,
                                        'WARN ' => colors.amber,
                                        _ => colors.muted,
                                      },
                                    ),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _MockControls extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(armxApiProvider);
    if (api is! MockArmxApi) {
      return GlassPanel(
        child: Text(
          'A real backend is configured; mock controls are hidden.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    final control = api.control;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Latency ${control.latency.inMilliseconds} ms',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Switch(
                value: control.offline,
                onChanged: (value) => control.offline = value,
              ),
              const SizedBox(width: 8),
              Text('Offline', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          Slider(
            min: 0,
            max: 1200,
            divisions: 12,
            value: control.latency.inMilliseconds.toDouble(),
            onChanged: (value) =>
                control.latency = Duration(milliseconds: value.round()),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Fail the next REST call with HTTP 503',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: () => control.failNext = true,
                child: const Text('Inject'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonoLine extends StatelessWidget {
  const _MonoLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontFamily: 'JetBrainsMono',
            fontSize: 12,
          ),
    );
  }
}
