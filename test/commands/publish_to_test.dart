// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_lang/gg_lang.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:test/test.dart';

void main() {
  late Directory d;
  final messages = <String>[];
  final ggLog = messages.add;
  late File pubSpec;
  late CommandRunner<void> runner;
  late PublishTo publishTo;

  // ...........................................................................
  Future<void> initPubspec({String? publishTo}) async {
    var pubspecContent = 'version: 1.0.0';
    if (publishTo != null) {
      pubspecContent += '\npublish_to: $publishTo';
    }
    await pubSpec.writeAsString(pubspecContent);
  }

  // ...........................................................................
  setUp(() async {
    d = await initTestDir();
    messages.clear();
    pubSpec = File('${d.path}/pubspec.yaml');
    publishTo = PublishTo(ggLog: ggLog);
    runner = CommandRunner<void>('test', 'test')..addCommand(publishTo);
  });

  tearDown(() async {
    await d.delete(recursive: true);
  });

  group('PublishTo', () {
    group('succeeds', () {
      group('returning the registries the package publishes to', () {
        test('when called from cli', () async {
          // .........................
          // A custom pub server is still a pub.dev-family target: the only
          // value that takes the Dart side out is »none«.
          await initPubspec(publishTo: 'xyz');

          await runner.run(['publish-to', '--input', d.path]);

          expect(messages.last, 'pub.dev');

          // .........................
          // Remove publish_to.
          await initPubspec(publishTo: null);
          await publishTo.exec(directory: d, ggLog: ggLog);

          // CLi outputs pub.dev
          expect(messages.last, 'pub.dev');
        });

        test('when called with fromDirectory()', () async {
          await initPubspec(publishTo: null);
          expect(await publishTo.fromDirectory(d), 'pub.dev');
          await initPubspec(publishTo: 'xyz');
          expect(await publishTo.fromDirectory(d), 'pub.dev');
          await initPubspec(publishTo: 'none');
          expect(await publishTo.fromDirectory(d), 'none');
        });

        group('for a TypeScript project', () {
          Future<void> initPackageJson({required bool private}) async {
            final pubspec = File('${d.path}/pubspec.yaml');
            if (pubspec.existsSync()) pubspec.deleteSync();
            File('${d.path}/package.json').writeAsStringSync(
              '{"name": "ts", "version": "1.0.0", "private": $private}',
            );
            File('${d.path}/tsconfig.json').writeAsStringSync('{}');
          }

          test('returns "none" when the package is private', () async {
            await initPackageJson(private: true);
            expect(await publishTo.fromDirectory(d), 'none');
          });

          test('returns "npm" when the package is public', () async {
            await initPackageJson(private: false);
            expect(await publishTo.fromDirectory(d), 'npm');
          });
        });

        group('for a project without a manifest', () {
          test('returns "none"', () async {
            expect(pubSpec.existsSync(), isFalse);
            expect(await publishTo.fromDirectory(d), 'none');
          });
        });

        group('for a hybrid (pubspec.yaml + package.json)', () {
          Future<void> initHybrid({
            String? publishTo,
            required bool private,
          }) async {
            await initPubspec(publishTo: publishTo);
            File('${d.path}/package.json').writeAsStringSync(
              '{"name": "@org/foo", "version": "1.0.0", '
              '"private": $private}',
            );
          }

          test('returns both registries when neither side opts out', () async {
            // The base_dna case - this is what the whole change exists for.
            await initHybrid(private: false);
            expect(await publishTo.fromDirectory(d), 'pub.dev+npm');
          });

          test('returns "npm" when publish_to is none', () async {
            // The ds_dna case: private on pub.dev, public on npm.
            await initHybrid(publishTo: 'none', private: false);
            expect(await publishTo.fromDirectory(d), 'npm');
          });

          test('returns "pub.dev" when the npm side is private', () async {
            await initHybrid(private: true);
            expect(await publishTo.fromDirectory(d), 'pub.dev');
          });
        });
      });
    });

    group('targets(directory)', () {
      test('answers per registry instead of with one label', () async {
        await initPubspec(publishTo: null);
        File(
          '${d.path}/package.json',
        ).writeAsStringSync('{"name": "@org/foo", "version": "1.0.0"}');

        expect(await publishTo.targets(d), <PublishTarget>{
          PublishTarget.pubDev,
          PublishTarget.npm,
        });
      });

      test('is empty for a package without a public registry', () async {
        await initPubspec(publishTo: 'none');
        expect(await publishTo.targets(d), isEmpty);
      });
    });
  });
}
