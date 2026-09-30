// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'vision.freezed.dart';
part 'vision.g.dart';

/// The five angles captured during face enrolment.
enum FaceEnrolmentAngle {
  /// Looking straight at the camera.
  @JsonValue('FRONT')
  front,

  /// Turned to the user's left.
  @JsonValue('LEFT')
  left,

  /// Turned to the user's right.
  @JsonValue('RIGHT')
  right,

  /// Chin up.
  @JsonValue('UP')
  up,

  /// Chin down.
  @JsonValue('DOWN')
  down,
}

/// Liveness challenge presented to the user.
enum LivenessChallengeKind {
  /// Blink once with both eyes.
  @JsonValue('BLINK')
  blink,

  /// Turn the head left then back.
  @JsonValue('HEAD_TURN')
  headTurn,
}

/// **Metadata only** for an enrolled face template.
///
/// The embedding itself never appears in a model, a log or an API payload: it lives in
/// encrypted local storage (see `FaceTemplateStore`) and is destroyed by the
/// "delete all biometric data" action.
@freezed
abstract class FaceTemplateMeta with _$FaceTemplateMeta {
  /// Creates template metadata.
  const factory FaceTemplateMeta({
    required String id,
    required DateTime createdAt,
    @Default(512) int embeddingSize,
    @Default('armx-face-v1') String modelId,
    @Default(0.72) double threshold,
    @Default(<FaceEnrolmentAngle>[]) List<FaceEnrolmentAngle> anglesCaptured,
    @Default(false) bool encrypted,
    @Default(0) int embeddingCount,
  }) = _FaceTemplateMeta;

  /// Creates metadata from wire JSON.
  factory FaceTemplateMeta.fromJson(Map<String, dynamic> json) =>
      _$FaceTemplateMetaFromJson(json);

  const FaceTemplateMeta._();

  /// Whether all five angles were captured (enrolment complete).
  bool get isComplete => anglesCaptured.length >= 5;

  /// Angles still missing from the enrolment.
  List<FaceEnrolmentAngle> get missingAngles => FaceEnrolmentAngle.values
      .where((angle) => !anglesCaptured.contains(angle))
      .toList(growable: false);
}

/// Result of a face verification attempt (never contains template data).
@freezed
abstract class VisionMatch with _$VisionMatch {
  /// Creates a match result.
  const factory VisionMatch({
    required bool matched,
    required double score,
    required double threshold,
    required DateTime at,
    @Default('') String reason,
  }) = _VisionMatch;

  /// Creates a match result from wire JSON.
  factory VisionMatch.fromJson(Map<String, dynamic> json) => _$VisionMatchFromJson(json);
}

/// A liveness challenge issued to the user.
@freezed
abstract class LivenessChallenge with _$LivenessChallenge {
  /// Creates a challenge.
  const factory LivenessChallenge({
    required LivenessChallengeKind kind,
    required DateTime issuedAt,
    required DateTime expiresAt,
    @Default('') String instruction,
  }) = _LivenessChallenge;

  /// Creates a challenge from wire JSON.
  factory LivenessChallenge.fromJson(Map<String, dynamic> json) =>
      _$LivenessChallengeFromJson(json);

  const LivenessChallenge._();

  /// True when the challenge is still answerable at [now].
  bool isValidAt(DateTime now) => expiresAt.isAfter(now);
}

/// Outcome of a liveness challenge.
@freezed
abstract class LivenessResult with _$LivenessResult {
  /// Creates a liveness result.
  const factory LivenessResult({
    required bool passed,
    required LivenessChallengeKind kind,
    required DateTime at,
    @Default('') String detail,
    @Default(0) double confidence,
  }) = _LivenessResult;

  /// Creates a result from wire JSON.
  factory LivenessResult.fromJson(Map<String, dynamic> json) => _$LivenessResultFromJson(json);
}

/// Palm gesture recognised by the pose model.
enum PalmGesture {
  /// Open palm held for ~600 ms: wake / stop.
  @JsonValue('PALM_OPEN')
  palmOpen,

  /// Fist: hard stop.
  @JsonValue('FIST')
  fist,

  /// No gesture.
  @JsonValue('NONE')
  none,
}

/// Current state of the camera privacy switch, surfaced on every screen that can use it.
@freezed
abstract class CameraPrivacyState with _$CameraPrivacyState {
  /// Creates the privacy state.
  const factory CameraPrivacyState({
    @Default(false) bool cameraEnabled,
    @Default(false) bool microphoneEnabled,
    @Default(false) bool palmGestureEnabled,
    required DateTime updatedAt,
  }) = _CameraPrivacyState;

  /// Creates the state from wire JSON.
  factory CameraPrivacyState.fromJson(Map<String, dynamic> json) =>
      _$CameraPrivacyStateFromJson(json);
}
