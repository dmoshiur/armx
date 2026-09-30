<!-- Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved. -->

# Model assets

This folder is where the **on-device** face-embedding model lives. It ships empty on purpose:
the face pipeline must never download a model at runtime (that would be a network dependency
inside a security path, and it would silently change behaviour between builds).

## Expected file

```
assets/models/face_embedding.tflite
```

* Input tensor: `float32[1, 112, 112, 3]`, RGB, values in `[-1, 1]`.
* Output tensor: `float32[1, 192]`, an L2-normalised embedding.
* Any MobileFaceNet/FaceNet-style model with those shapes works; the app only reads the
  shapes and normalises the output, so swapping the model is a drop-in change.

The app starts fine without it: `FaceEmbedder` reports `ModelStatus.missing` and the Vision
screen shows an explanatory empty state instead of failing. Drop a `.tflite` file here and
re-run `flutter pub get` (asset manifests are built at build time).

## Why the model is not committed

`.tflite` files are binaries whose licence is not ours to redistribute. Add your own
licensed model before shipping a build that performs face enrolment.

## Privacy

Embeddings are computed locally, encrypted with a key held in
`flutter_secure_storage`, and stored on the device only. They are never uploaded. The only
verification artefact that ever leaves the device is the signed, single-use,
60-second `owner_verified` assertion described in `docs/api.md`.
