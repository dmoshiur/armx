// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/breakpoints.dart';
import '../../../core/confirm/confirm_policy.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/armx_badge.dart';
import '../../../core/widgets/armx_button.dart';
import '../../../core/widgets/armx_card.dart';
import '../../../core/widgets/armx_confirm_dialog.dart';
import '../../../core/widgets/armx_empty_state.dart';
import '../../../core/widgets/armx_error_state.dart';
import '../../../core/widgets/armx_loading_skeleton.dart';
import '../../../core/widgets/armx_status_dot.dart';
import '../../../core/widgets/armx_text_field.dart';
import '../../../data/models/web_builder.dart';
import '../application/web_builder_controller.dart';
import 'widgets/generated_file_view.dart';

/// The web builder: prompt, review, publish.
///
/// ## The flow, and why it is shaped like this
///
/// 1. **Prompt** — a text field and one button. Nothing else is touched.
/// 2. **Draft** — the generated files, listed and readable, with added lines marked.
///    Generating changes nothing outside the app, so it can be repeated freely.
/// 3. **Publish** — a separate, deliberate step through [ConfirmPolicy] that names the exact
///    repository and branch, because those two strings are what actually gets overwritten.
///    It demands the typed phrase: this is the one action here that can affect someone else.
/// 4. **Live** — the URL appears only when the backend reports the deployment as live. A
///    pending or failed publish shows its own state and message; the screen never guesses a
///    URL from a commit sha or a draft id.
///
/// ## Responsive
///
/// Compact stacks the file picker above the code (the code gets the full width, which is what
/// matters for reading it). Expanded puts the picker beside the code so both stay visible
/// while comparing files.
class WebBuilderPage extends ConsumerWidget {
  /// Creates the page.
  const WebBuilderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final WebBuilderState state = ref.watch(webBuilderProvider);
    final ArmxColors colors = ArmxColors.of(context);
    final SiteDraft? draft = state.draft;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(context.l10n.builderTitle),
        actions: <Widget>[
          if (draft != null)
            ArmxIconButton(
              icon: Icons.delete_sweep_outlined,
              semanticLabel: context.l10n.builderDiscard,
              onPressed: () => ref.read(webBuilderProvider.notifier).discard(),
            ),
        ],
      ),
      body: PageBody(
        children: <Widget>[
          Text(
            context.l10n.builderSubtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Insets.lg),
          ArmxCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ArmxTextField(
                  label: context.l10n.builderPromptLabel,
                  hint: context.l10n.builderPromptHint,
                  initialValue: state.prompt,
                  maxLines: 3,
                  minLines: 2,
                  maxLength: 600,
                  enabled: !state.generating && !state.publishing,
                  onChanged: (String value) =>
                      ref.read(webBuilderProvider.notifier).setPrompt(value),
                ),
                const SizedBox(height: Insets.md),
                AdaptiveWrapRow(
                  children: <Widget>[
                    ArmxButton(
                      label: state.generating
                          ? context.l10n.builderGenerating
                          : context.l10n.builderGenerate,
                      icon: Icons.auto_awesome_rounded,
                      loading: state.generating,
                      onPressed: state.publishing
                          ? null
                          : () => ref.read(webBuilderProvider.notifier).generate(),
                    ),
                    if (draft != null)
                      ArmxButton(
                        label: context.l10n.builderDeploy,
                        variant: ArmxButtonVariant.destructive,
                        icon: Icons.rocket_launch_rounded,
                        loading: state.publishing,
                        onPressed: state.publishing
                            ? null
                            : () => _publish(context, ref, draft),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (state.error != null) ...<Widget>[
            const SizedBox(height: Insets.lg),
            ArmxErrorState(error: state.error, compact: true),
          ],
          const SizedBox(height: Insets.xl),
          if (draft == null)
            ArmxEmptyState(
              icon: Icons.code_rounded,
              title: context.l10n.builderPreviewTitle,
              message: context.l10n.builderPreviewEmpty,
            )
          else ...<Widget>[
            _DraftSummary(draft: draft, deployment: state.deployment),
            const SizedBox(height: Insets.lg),
            if (context.isExpanded)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 2, child: _CodePane(state: state)),
                  const SizedBox(width: Insets.lg),
                  SizedBox(
                    width: 320,
                    child: GeneratedFilePicker(
                      files: draft.files,
                      selectedPath: state.selectedFile?.path,
                      onSelected: (String path) =>
                          ref.read(webBuilderProvider.notifier).selectFile(path),
                    ),
                  ),
                ],
              )
            else ...<Widget>[
              GeneratedFilePicker(
                files: draft.files,
                selectedPath: state.selectedFile?.path,
                onSelected: (String path) =>
                    ref.read(webBuilderProvider.notifier).selectFile(path),
              ),
              const SizedBox(height: Insets.lg),
              _CodePane(state: state),
            ],
          ],
          const SizedBox(height: Insets.xxl),
          const _Deployments(),
        ],
      ),
    );
  }

  /// Confirm — naming the repository and branch — then publish.
  Future<void> _publish(
    BuildContext context,
    WidgetRef ref,
    SiteDraft draft,
  ) async {
    final bool confirmed = await ConfirmPolicy.confirm(
      context,
      ConfirmPolicy.forAction(
        context,
        title: context.l10n.builderDeployTitle,
        action: 'web_deploy',
        target: '${draft.repository}#${draft.branch}',
        parameters: <ConfirmParameter>[
          ConfirmParameter(label: 'draft_id', value: draft.id, monospace: true),
          ConfirmParameter(
            label: 'repository',
            value: draft.repository,
            monospace: true,
          ),
          ConfirmParameter(label: 'branch', value: draft.branch, monospace: true),
          ConfirmParameter(
            label: 'files',
            value: draft.files.map((GeneratedFile file) => file.path).join(', '),
            monospace: true,
          ),
        ],
        consequence: context.l10n.builderDeployConsequence,
        irreversible: true,
        requireTypedPhrase: true,
        confirmLabel: context.l10n.builderDeploy,
      ),
    );
    if (!confirmed) {
      return;
    }
    // No publish is issued unless the dialog resolved true: the controller is not called
    // before this line, which is what the widget test asserts.
    await ref.read(webBuilderProvider.notifier).deploy();
  }
}

class _DraftSummary extends StatelessWidget {
  const _DraftSummary({required this.draft, required this.deployment});

  final SiteDraft draft;
  final Deployment? deployment;

  @override
  Widget build(BuildContext context) {
    return ArmxCard(
      title: context.l10n.builderPreviewTitle,
      leading: const Icon(Icons.description_outlined),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ArmxDetailRow(
            label: context.l10n.builderRepoLabel,
            value: draft.repository,
            monospace: true,
            icon: Icons.folder_outlined,
          ),
          ArmxDetailRow(
            label: context.l10n.builderBranchLabel,
            value: draft.branch,
            monospace: true,
            icon: Icons.account_tree_outlined,
          ),
          ArmxDetailRow(
            label: context.l10n.builderFiles(draft.files.length),
            value: context.l10n.builderLinesAdded(
              draft.files
                  .where((GeneratedFile file) => !file.isNew)
                  .fold<int>(0, (int sum, GeneratedFile f) => sum + f.addedLines),
            ),
            icon: Icons.difference_outlined,
          ),
          if (deployment != null) ...<Widget>[
            const SizedBox(height: Insets.md),
            _DeploymentState(deployment: deployment!),
          ],
        ],
      ),
    );
  }
}

/// The publish outcome, stated as a state rather than as a URL.
class _DeploymentState extends StatelessWidget {
  const _DeploymentState({required this.deployment});

  final Deployment deployment;

  @override
  Widget build(BuildContext context) {
    final DeploymentStatus status = deployment.status;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ArmxStatusPill(
          status: deploymentDotStatus(status),
          label: deploymentStatusLabel(context, status),
          pulse: status == DeploymentStatus.inProgress,
        ),
        if (status.isLive && deployment.liveUrl != null) ...<Widget>[
          const SizedBox(height: Insets.sm),
          ArmxDetailRow(
            label: context.l10n.builderLiveUrl,
            value: deployment.liveUrl!,
            monospace: true,
            icon: Icons.public_rounded,
          ),
        ],
        if (deployment.commitSha != null)
          ArmxDetailRow(
            label: context.l10n.builderCommit,
            value: deployment.commitSha!,
            monospace: true,
            icon: Icons.commit_rounded,
          ),
        if (deployment.failureMessage != null) ...<Widget>[
          const SizedBox(height: Insets.sm),
          ArmxNotice(
            tone: ArmxBadgeToneLike.danger,
            message: deployment.failureMessage!,
          ),
        ],
      ],
    );
  }
}

class _CodePane extends StatelessWidget {
  const _CodePane({required this.state});

  final WebBuilderState state;

  @override
  Widget build(BuildContext context) {
    final GeneratedFile? file = state.selectedFile;
    if (file == null) {
      return ArmxEmptyState(
        icon: Icons.code_rounded,
        message: context.l10n.builderPreviewEmpty,
        compact: true,
      );
    }
    return GeneratedFileView(file: file);
  }
}

/// Previous publishes, with their real status.
class _Deployments extends ConsumerWidget {
  const _Deployments();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Deployment>> deployments =
        ref.watch(deploymentsProvider);

    return ArmxCard(
      title: context.l10n.builderDeploymentsTitle,
      leading: const Icon(Icons.history_rounded),
      child: switch (deployments) {
        AsyncLoading<List<Deployment>>() => const ArmxSkeletonCard(lines: 2),
        AsyncError<List<Deployment>>(:final Object error) => ArmxErrorState(
            error: error,
            compact: true,
            onRetry: () => ref.invalidate(deploymentsProvider),
          ),
        AsyncData<List<Deployment>>(:final List<Deployment> value) =>
          value.isEmpty
              ? ArmxEmptyState(
                  icon: Icons.rocket_launch_outlined,
                  title: context.l10n.builderDeploymentsEmpty,
                  compact: true,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final Deployment deployment in value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Insets.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            ArmxStatusDot(
                              status: deploymentDotStatus(deployment.status),
                              label: deploymentStatusLabel(
                                context,
                                deployment.status,
                              ),
                              compact: true,
                            ),
                            if (deployment.liveUrl != null)
                              ArmxDetailRow(
                                label: context.l10n.builderLiveUrl,
                                value: deployment.liveUrl!,
                                monospace: true,
                              ),
                            if (deployment.commitSha != null)
                              ArmxDetailRow(
                                label: context.l10n.builderCommit,
                                value: deployment.commitSha!,
                                monospace: true,
                              ),
                            if (deployment.deployedAt != null)
                              Text(
                                deployment.deployedAt!.toLocal().toString(),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
      },
    );
  }
}

/// The dot a deployment's status paints.
///
/// `replaced` is deliberately not an error: a superseded deployment worked, it was simply
/// overtaken, and colouring it red would send someone hunting for a fault that is not there.
ArmxStatus deploymentDotStatus(DeploymentStatus status) => switch (status) {
      DeploymentStatus.live => ArmxStatus.online,
      DeploymentStatus.pending => ArmxStatus.pending,
      DeploymentStatus.inProgress => ArmxStatus.pending,
      DeploymentStatus.failed => ArmxStatus.failed,
      DeploymentStatus.replaced => ArmxStatus.stopped,
    };

/// A deployment status as a localized phrase.
String deploymentStatusLabel(BuildContext context, DeploymentStatus status) =>
    switch (status) {
      DeploymentStatus.live => context.l10n.builderDeployLive,
      DeploymentStatus.pending => context.l10n.builderDeployQueued,
      DeploymentStatus.inProgress => context.l10n.statusDeploying,
      DeploymentStatus.failed => context.l10n.builderDeployFailed,
      DeploymentStatus.replaced => context.l10n.builderDeployReplaced,
    };
