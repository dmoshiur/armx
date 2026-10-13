// Copyright (c) 2026 Md. Moshiur Rahman Mohi / THAMJJ13.TOP. Proprietary. All Rights Reserved.

import 'package:armx_ai/data/models/web_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeneratedFile', () {
    test('a file with no previous contents is new', () {
      const GeneratedFile file = GeneratedFile(
        path: 'index.html',
        contents: '<!doctype html>',
      );
      expect(file.isNew, isTrue);
    });

    test('an edit is not a new file and its line delta is signed', () {
      const GeneratedFile added = GeneratedFile(
        path: 'index.html',
        contents: 'a\nb\nc',
        previousContents: 'a',
      );
      expect(added.isNew, isFalse);
      expect(added.addedLines, 2);

      const GeneratedFile removed = GeneratedFile(
        path: 'index.html',
        contents: 'a',
        previousContents: 'a\nb\nc',
      );
      expect(removed.addedLines, -2);
    });

    test('an unchanged file reports a zero delta rather than a fake change', () {
      const GeneratedFile same = GeneratedFile(
        path: 'style.css',
        contents: 'body { color: red; }',
        previousContents: 'body { color: red; }',
      );
      expect(same.addedLines, 0);
    });
  });

  group('DeploymentStatus', () {
    test('an unrecognised status is pending — it can never render as a live site', () {
      // The rule the whole Web Builder screen depends on: `live` is earned, never defaulted.
      expect(DeploymentStatus.fromWire('weird'), DeploymentStatus.pending);
      expect(DeploymentStatus.fromWire(null), DeploymentStatus.pending);
      expect(DeploymentStatus.fromWire('weird').isLive, isFalse);
    });

    test('the server spellings map to the five statuses', () {
      expect(DeploymentStatus.fromWire('building'), DeploymentStatus.inProgress);
      expect(DeploymentStatus.fromWire('deployed'), DeploymentStatus.live);
      expect(DeploymentStatus.fromWire('error'), DeploymentStatus.failed);
      expect(DeploymentStatus.fromWire('superseded'), DeploymentStatus.replaced);
    });

    test('only live is live', () {
      for (final DeploymentStatus status in DeploymentStatus.values) {
        expect(status.isLive, status == DeploymentStatus.live, reason: '$status');
      }
    });
  });

  group('SiteDraft', () {
    test('parses the prompt, the target repository and the generated files together', () {
      final SiteDraft draft = SiteDraft.fromJson(const <String, Object?>{
        'id': 'draft-1',
        'prompt': 'A one-page site for the workshop',
        'repository': 'thamjj13/armx-site',
        'branch': 'main',
        'files': <Object?>[
          <String, Object?>{
            'path': 'index.html',
            'contents': '<h1>Workshop</h1>',
            'previous_contents': '<h1>Old</h1>',
          },
        ],
      });
      expect(draft.repository, 'thamjj13/armx-site');
      expect(draft.branch, 'main');
      expect(draft.files, hasLength(1));
      expect(draft.files.single.previousContents, '<h1>Old</h1>');
    });

    test('a draft with no files yet parses, so the preview can say "nothing generated"', () {
      final SiteDraft draft = SiteDraft.fromJson(const <String, Object?>{
        'id': 'draft-2',
        'prompt': 'anything',
      });
      expect(draft.files, isEmpty);
    });
  });

  group('Deployment', () {
    test('a failed deployment carries its reason and no live URL', () {
      final Deployment deployment = Deployment.fromJson(const <String, Object?>{
        'id': 'dep-1',
        'draft_id': 'draft-1',
        'status': 'failed',
        'failure_message': 'Repository not found',
      });
      expect(deployment.status, DeploymentStatus.failed);
      expect(deployment.liveUrl, isNull);
      expect(deployment.failureMessage, 'Repository not found');
      expect(deployment.status.isLive, isFalse);
    });

    test('a live deployment carries the URL it earned', () {
      final Deployment deployment = Deployment.fromJson(const <String, Object?>{
        'id': 'dep-2',
        'draft_id': 'draft-1',
        'status': 'live',
        'live_url': 'https://thamjj13.github.io/armx-site/',
        'commit_sha': 'abc1234',
      });
      expect(deployment.status.isLive, isTrue);
      expect(deployment.liveUrl, startsWith('https://'));
      expect(deployment.commitSha, 'abc1234');
    });
  });
}
