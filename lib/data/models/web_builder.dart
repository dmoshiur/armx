// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:meta/meta.dart';

/// One generated file in a draft site.
@immutable
class GeneratedFile {
  /// Creates a generated file.
  const GeneratedFile({
    required this.path,
    required this.contents,
    this.previousContents,
    this.language,
  });

  /// Repo-relative path, e.g. `index.html`.
  final String path;

  /// Full new contents. Rendered in a read-only, monospace, selectable view — never
  /// executed and never rendered as HTML.
  final String contents;

  /// Previous contents when the file already exists, so the preview can show a real diff.
  /// `null` means the file is new.
  final String? previousContents;

  /// Language hint for syntax colouring.
  final String? language;

  /// True when the file is new rather than modified.
  bool get isNew => previousContents == null;

  /// Count of added lines, for the diff summary. A simple count is enough here because
  /// the preview shows the whole file; the number only labels the change.
  int get addedLines => _lineCount(contents) - _lineCount(previousContents ?? '');

  static int _lineCount(String value) =>
      value.isEmpty ? 0 : value.split('\n').length;

  /// Parses from the wire.
  factory GeneratedFile.fromJson(Map<String, Object?> json) => GeneratedFile(
        path: (json['path'] ?? '') as String,
        contents: (json['contents'] ?? '') as String,
        previousContents: json['previous'] as String?,
        language: json['language'] as String?,
      );
}

/// A generated but not yet deployed site.
@immutable
class SiteDraft {
  /// Creates a draft.
  const SiteDraft({
    required this.id,
    required this.prompt,
    required this.files,
    required this.repository,
    required this.branch,
    this.createdAt,
    this.notes,
  });

  /// Identifier used when deploying.
  final String id;

  /// The prompt that produced it.
  final String prompt;

  /// The generated files.
  final List<GeneratedFile> files;

  /// Exact repository the deploy writes to. Shown verbatim in the confirmation dialog —
  /// this is the value that makes "which repo am I about to overwrite" unambiguous.
  final String repository;

  /// Exact branch.
  final String branch;

  /// When it was generated.
  final DateTime? createdAt;

  /// Optional notes from the generator (for example, a manual follow-up step).
  final String? notes;

  /// Parses from the wire.
  factory SiteDraft.fromJson(Map<String, Object?> json) {
    final Object? files = json['files'];
    return SiteDraft(
      id: json['id']! as String,
      prompt: (json['prompt'] ?? '') as String,
      files: files is List<Object?>
          ? files
              .whereType<Map<String, Object?>>()
              .map(GeneratedFile.fromJson)
              .toList(growable: false)
          : const <GeneratedFile>[],
      repository: (json['repository'] ?? '') as String,
      branch: (json['branch'] ?? 'main') as String,
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at']! as String)
          : null,
      notes: json['notes'] as String?,
    );
  }
}

/// Deployment lifecycle.
enum DeploymentStatus {
  /// Accepted by the backend, not finished.
  pending,

  /// Uploading/building.
  inProgress,

  /// Live.
  live,

  /// Failed. [Deployment.failureMessage] explains why.
  failed,

  /// Superseded by a newer deployment.
  replaced;

  /// Parses a wire value. Unknown values become [pending] so an unrecognised status can
  /// never render as a live site.
  static DeploymentStatus fromWire(String? value) => switch (value?.toLowerCase()) {
        'in_progress' || 'building' || 'deploying' => DeploymentStatus.inProgress,
        'live' || 'success' || 'deployed' => DeploymentStatus.live,
        'failed' || 'error' => DeploymentStatus.failed,
        'replaced' || 'superseded' => DeploymentStatus.replaced,
        _ => DeploymentStatus.pending,
      };

  /// True only when the site is actually serving.
  bool get isLive => this == DeploymentStatus.live;
}

/// A deployment of a draft.
@immutable
class Deployment {
  /// Creates a deployment.
  const Deployment({
    required this.id,
    required this.draftId,
    required this.status,
    this.liveUrl,
    this.commitSha,
    this.failureMessage,
    this.deployedAt,
  });

  /// Identifier.
  final String id;

  /// Draft that was deployed.
  final String draftId;

  /// Current state.
  final DeploymentStatus status;

  /// The live URL. **Only set by the backend once the site is actually serving** — the
  /// screen shows it only when [status] is [DeploymentStatus.live].
  final String? liveUrl;

  /// Commit the backend created.
  final String? commitSha;

  /// Why it failed.
  final String? failureMessage;

  /// When it went live.
  final DateTime? deployedAt;

  /// Parses from the wire.
  factory Deployment.fromJson(Map<String, Object?> json) => Deployment(
        id: json['id']! as String,
        draftId: (json['draft_id'] ?? '') as String,
        status: DeploymentStatus.fromWire(json['status'] as String?),
        liveUrl: json['live_url'] as String?,
        commitSha: json['commit_sha'] as String?,
        failureMessage: json['failure_message'] as String?,
        deployedAt: json['deployed_at'] is String
            ? DateTime.tryParse(json['deployed_at']! as String)
            : null,
      );

  /// Copy with changes.
  Deployment copyWith({
    String? id,
    String? draftId,
    DeploymentStatus? status,
    String? liveUrl,
    String? commitSha,
    String? failureMessage,
    DateTime? deployedAt,
  }) =>
      Deployment(
        id: id ?? this.id,
        draftId: draftId ?? this.draftId,
        status: status ?? this.status,
        liveUrl: liveUrl ?? this.liveUrl,
        commitSha: commitSha ?? this.commitSha,
        failureMessage: failureMessage ?? this.failureMessage,
        deployedAt: deployedAt ?? this.deployedAt,
      );
}
