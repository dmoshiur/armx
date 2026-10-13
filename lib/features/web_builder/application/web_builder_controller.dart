// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import '../../../data/models/web_builder.dart';

/// Web-builder state: the prompt, the draft it produced, and the last publish.
class WebBuilderState {
  /// Creates a state.
  const WebBuilderState({
    this.prompt = '',
    this.draft,
    this.deployment,
    this.selectedFilePath,
    this.generating = false,
    this.publishing = false,
    this.error,
  });

  /// The prompt as typed.
  final String prompt;

  /// The generated draft, if any.
  final SiteDraft? draft;

  /// The most recent publish result.
  final Deployment? deployment;

  /// File currently shown in the preview.
  final String? selectedFilePath;

  /// True while a draft is being generated.
  final bool generating;

  /// True while a publish is in flight.
  final bool publishing;

  /// The last failure.
  final AppException? error;

  /// The selected file, falling back to the first one.
  GeneratedFile? get selectedFile {
    final SiteDraft? current = draft;
    if (current == null || current.files.isEmpty) {
      return null;
    }
    return current.files.firstWhere(
      (GeneratedFile file) => file.path == selectedFilePath,
      orElse: () => current.files.first,
    );
  }

  /// Total lines added across modified files.
  int get addedLines => (draft?.files ?? const <GeneratedFile>[])
      .where((GeneratedFile file) => !file.isNew)
      .fold<int>(0, (int sum, GeneratedFile file) => sum + file.addedLines);

  /// Copy with changes.
  WebBuilderState copyWith({
    String? prompt,
    SiteDraft? draft,
    Deployment? deployment,
    String? selectedFilePath,
    bool? generating,
    bool? publishing,
    AppException? error,
    bool clearError = false,
    bool clearDraft = false,
  }) =>
      WebBuilderState(
        prompt: prompt ?? this.prompt,
        draft: clearDraft ? null : (draft ?? this.draft),
        deployment: clearDraft ? null : (deployment ?? this.deployment),
        selectedFilePath: clearDraft
            ? null
            : (selectedFilePath ?? this.selectedFilePath),
        generating: generating ?? this.generating,
        publishing: publishing ?? this.publishing,
        error: clearError ? null : (error ?? this.error),
      );
}

/// The web-builder flow: prompt → draft → publish.
///
/// The two halves are kept strictly apart because one of them writes to a repository:
///
/// * [generate] changes nothing outside the app and can be repeated freely;
/// * [deploy] publishes, and is only ever reached after the page confirmed a dialog naming
///   the exact repository and branch. The controller cannot see the UI, so it does not try to
///   check that itself — the widget test pins the rule at the call site instead.
class WebBuilderController extends Notifier<WebBuilderState> {
  @override
  WebBuilderState build() => const WebBuilderState();

  /// Records the prompt.
  void setPrompt(String prompt) => state = state.copyWith(prompt: prompt);

  /// Generates a draft from the current prompt. Nothing is published.
  Future<void> generate() async {
    final String prompt = state.prompt.trim();
    if (prompt.isEmpty) {
      state = state.copyWith(
        error: const ValidationException(
          message: 'A prompt is required before a draft can be generated.',
          code: 'prompt_required',
        ),
      );
      return;
    }

    state = state.copyWith(generating: true, clearError: true);
    try {
      final SiteDraft draft =
          await ref.read(armxApiProvider).generateSite(prompt: prompt);
      state = state.copyWith(
        draft: draft,
        generating: false,
        selectedFilePath: draft.files.isEmpty ? null : draft.files.first.path,
      );
    } on AppException catch (error) {
      state = state.copyWith(generating: false, error: error);
    }
  }

  /// Selects a file in the preview.
  void selectFile(String path) => state = state.copyWith(selectedFilePath: path);

  /// Publishes the current draft.
  ///
  /// `publishing` is what the UI shows as a distinct pending state: a publish is not
  /// instant, and a button that returns to idle while the deploy is queued invites a second,
  /// conflicting one.
  Future<void> deploy({String? repository, String? branch}) async {
    final SiteDraft? draft = state.draft;
    if (draft == null) {
      return;
    }
    state = state.copyWith(publishing: true, clearError: true);
    try {
      final Deployment deployment = await ref.read(armxApiProvider).deploySite(
            draftId: draft.id,
            repository: repository ?? draft.repository,
            branch: branch ?? draft.branch,
          );
      state = state.copyWith(publishing: false, deployment: deployment);
      ref.invalidate(deploymentsProvider);
    } on AppException catch (error) {
      state = state.copyWith(publishing: false, error: error);
    }
  }

  /// Throws the draft away so the next prompt starts clean.
  void discard() => state = WebBuilderState(prompt: state.prompt).copyWith(clearDraft: true);
}

/// The web-builder state.
final NotifierProvider<WebBuilderController, WebBuilderState> webBuilderProvider =
    NotifierProvider<WebBuilderController, WebBuilderState>(
  WebBuilderController.new,
);

/// Previous publishes, newest first.
final FutureProvider<List<Deployment>> deploymentsProvider =
    FutureProvider<List<Deployment>>(
  (Ref ref) => ref.watch(armxApiProvider).deployments(),
);
