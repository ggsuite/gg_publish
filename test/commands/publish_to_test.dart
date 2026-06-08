// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
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
      group('returning pubspec.yaml\'s publish_to field or pub.dev', () {
        test('when called from cli', () async {
          // .........................
          // Set publish_to to a value.
          await initPubspec(publishTo: 'xyz');

          await runner.run(['publish-to', '--input', d.path]);

          // CLi outputs the value
          expect(messages.last, 'xyz');

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
          expect(await publishTo.fromDirectory(d), 'xyz');
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
      });
    });
  });
}
