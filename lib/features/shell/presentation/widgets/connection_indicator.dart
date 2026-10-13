// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n.dart';
import '../../../../core/network/websocket_client.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/armx_status_dot.dart';

/// Live transport state, as a labelled status dot.
///
/// The label is the point: `standby` ("not listening"), `connecting`, `open`
/// ("connected"), `offline` ("reconnecting") and `closed` are five different situations
/// and a colour alone would collapse them into two. Screen readers get the same sentence.
class ConnectionIndicator extends ConsumerWidget {
  /// Creates the indicator.
  const ConnectionIndicator({this.compact = false, super.key});

  /// Tightens the type for the rail footer.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppConfig config = ref.watch(appConfigProvider);
    final Stream<SocketStatus> statuses = ref.watch(webSocketProvider).statuses;
    final SocketStatus status = ref.watch(_socketStatusProvider(statuses));

    final (ArmxStatus dotStatus, String label) = switch (status.state) {
      SocketState.open => (ArmxStatus.online, context.l10n.shellConnectionOnline),
      SocketState.connecting => (
          ArmxStatus.pending,
          context.l10n.shellConnectionConnecting,
        ),
      SocketState.offline => (ArmxStatus.failed, context.l10n.shellConnectionRetrying),
      SocketState.closed => (ArmxStatus.stopped, context.l10n.statusDisconnected),
      SocketState.standby => (ArmxStatus.unknown, context.l10n.statusInactive),
    };

    return Tooltip(
      message: config.useMockBackend
          ? '$label · ${context.l10n.commonSimulated}'
          : label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Insets.xs, vertical: Insets.xs),
        child: ArmxStatusDot(
          status: dotStatus,
          // A mock build says so, in the label, everywhere the state is shown — the app
          // never implies a live backend it does not have.
          label: config.useMockBackend
              ? '$label · ${context.l10n.commonSimulated}'
              : label,
          pulse: status.state == SocketState.open,
          compact: compact,
        ),
      ),
    );
  }
}

/// Turns the socket's status stream into a watchable value with a sane initial state.
final _socketStatusProvider = StreamProvider.family<SocketStatus, Stream<SocketStatus>>(
  (Ref ref, Stream<SocketStatus> stream) => stream,
);
