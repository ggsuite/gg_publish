// @license
// Copyright (c) 2025 Göran Hegenberg. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// End-to-end routing test: a cross-language bridge repo (pubspec.yaml +
// package.json + tsconfig.json) must be treated as a TypeScript package
// throughout the publish/version flow (npm target, package.json version),
// while its Dart side stays in place for local cross-language linking.
//
// These tests use real command instances against real fixture directories;
// no mocks and no network — the version baseline is injected so
// `PrepareNextVersion` never queries a registry.

import 'dart:io';

import 'package:gg_lang/gg_lang.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:gg_version/gg_version.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() {
  final messages = <String>[];
  final ggLog = messages.add;
  late Directory dir;

  setUp(() {
    messages.clear();
    dir = Directory.systemTemp.createTempSync('gg_bridge_publish_e2e');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  // ...........................................................................
  void writeDart({String publishTo = ''}) {
    File('${dir.path}/pubspec.yaml').writeAsStringSync(
      'name: dart_pkg\nversion: 1.0.0\n'
      '${publishTo.isEmpty ? '' : 'publish_to: $publishTo\n'}',
    );
  }

  void writeTs({bool private = false}) {
    File('${dir.path}/package.json').writeAsStringSync(
      '{"name": "@org/ts_pkg", "version": "2.0.0"'
      '${private ? ', "private": true' : ''}}',
    );
    File('${dir.path}/tsconfig.json').writeAsStringSync('{}');
  }

  // A bridge ships BOTH manifests. The pubspec.yaml carries the Dart side
  // (here »publish_to: none« — the Dart side is never sent to pub.dev) and
  // the package.json carries the published TypeScript identity.
  void writeBridge({bool private = false}) {
    File(
      '${dir.path}/pubspec.yaml',
    ).writeAsStringSync('name: bridge\nversion: 1.0.0\npublish_to: none\n');
    writeTs(private: private);
  }

  group('A bridge is treated as TypeScript in the publish flow', () {
    group('checkProjectType', () {
      test('resolves a bridge to TypeScript', () {
        writeBridge();
        expect(checkProjectType(dir), ProjectType.typescript);
      });

      test('resolves a pure Dart repo to Dart', () {
        writeDart();
        expect(checkProjectType(dir), ProjectType.dart);
      });

      test('resolves a pure TypeScript repo to TypeScript', () {
        writeTs();
        expect(checkProjectType(dir), ProjectType.typescript);
      });
    });

    group('PublishTo', () {
      test('a public bridge publishes to npm', () async {
        writeBridge();
        final target = await PublishTo(ggLog: ggLog).fromDirectory(dir);
        expect(target, 'npm');
      });

      test('a private bridge publishes nowhere', () async {
        writeBridge(private: true);
        final target = await PublishTo(ggLog: ggLog).fromDirectory(dir);
        expect(target, 'none');
      });

      test('a pure Dart repo publishes to pub.dev', () async {
        writeDart();
        final target = await PublishTo(ggLog: ggLog).fromDirectory(dir);
        expect(target, 'pub.dev');
      });
    });

    group('PrepareNextVersion', () {
      test('bumps both manifests of a bridge in lock-step', () async {
        writeBridge();

        await PrepareNextVersion(ggLog: ggLog).apply(
          directory: dir,
          ggLog: ggLog,
          increment: VersionIncrement.patch,
          // Inject the baseline so no registry is queried (the published npm
          // version drives the increment).
          publishedVersion: Version(2, 0, 0),
        );

        final packageJson = File('${dir.path}/package.json').readAsStringSync();
        final pubspec = File('${dir.path}/pubspec.yaml').readAsStringSync();

        // Both the published npm manifest and the Dart side advance together,
        // so Dart git-consumers of the bridge keep resolving against the tag.
        expect(packageJson, contains('"version": "2.0.1"'));
        expect(pubspec, contains('version: 2.0.1'));
      });

      test('bumps only the manifest of a single-language repo', () async {
        writeDart();

        await PrepareNextVersion(ggLog: ggLog).apply(
          directory: dir,
          ggLog: ggLog,
          increment: VersionIncrement.minor,
          publishedVersion: Version(1, 0, 0),
        );

        final pubspec = File('${dir.path}/pubspec.yaml').readAsStringSync();
        expect(pubspec, contains('version: 1.1.0'));
      });
    });

    group('FromPubspec', () {
      test('reads the version from a bridge package.json', () async {
        writeBridge();
        final version = await FromPubspec(
          ggLog: ggLog,
        ).fromDirectory(directory: dir);
        expect(version.toString(), '2.0.0');
      });
    });
  });
}
