// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() async {
  // ...........................................................................
  late Directory d;

  final messages = <String>[];
  final ggLog = messages.add;
  late IsVersionPrepared isVersionPrepared;
  final versions = IsVersionPrepared.messagePrefix;
  late PublishedVersion publishedVersion;
  late CommandRunner<void> runner;

  // ...........................................................................
  setUp(() async {
    messages.clear();
    d = await initTestDir();
    registerFallbackValue(d);
    await initGit(d);
    await addAndCommitSampleFile(d);
    publishedVersion = MockPublishedVersion();
    isVersionPrepared = IsVersionPrepared(
      ggLog: ggLog,
      publishedVersion: publishedVersion,
    );
    runner = CommandRunner<void>('test', 'test');
    runner.addCommand(isVersionPrepared);
  });

  // ...........................................................................
  tearDown(() {
    d.deleteSync(recursive: true);
  });

  // ...........................................................................
  group('IsVersionPrepared', () {
    group('get(directory, ggLog)', () {
      group('should return false', () {
        group('and log »versions must be the same«', () {
          test(
            'when pubspec.yaml and CHANGELOG have different versions',
            () async {
              await addAndCommitVersions(
                d,
                pubspec: '1.0.0',
                changeLog: '1.1.0',
                gitHead: '1.0.0',
              );

              final result = await isVersionPrepared.get(
                ggLog: ggLog,
                directory: d,
              );
              expect(result, isFalse);
              expect(messages.last, darkGray('$versions must be the same.'));
            },
          );
        });

        group('and log the required versions', () {
          test('when versions are not the next increment', () async {
            // Assume the published version is 2.0.0
            when(() => publishedVersion.get(ggLog: ggLog, directory: d))
                .thenAnswer((_) async => Version(2, 0, 0));

            // Assume the locally configured version is 3.0.0
            await addAndCommitVersions(
              d,
              pubspec: '4.0.0',
              changeLog: '4.0.0',
              gitHead: '4.0.0',
            );

            // The next version must be 3.0.0, 2.1.0 or 2.0.1
            final result = await isVersionPrepared.get(
              ggLog: ggLog,
              directory: d,
            );
            expect(result, isFalse);
            expect(
              messages.last,
              darkGray('$versions must one of the following:'
                  '\n- 2.0.1'
                  '\n- 2.1.0'
                  '\n- 3.0.0'),
            );
          });
        });
      });

      group('should return true', () {
        group('when README.md and pubspec.yaml have the same version', () {
          test('and the version is the next increment', () async {
            // Assume the published version is 2.0.0
            when(() => publishedVersion.get(ggLog: ggLog, directory: d))
                .thenAnswer((_) async => Version(2, 0, 0));

            for (final version in ['2.0.1', '2.1.0', '3.0.0']) {
              await addAndCommitVersions(
                d,
                pubspec: version,
                changeLog: version,
                gitHead: version,
              );

              final result = await isVersionPrepared.get(
                ggLog: ggLog,
                directory: d,
              );
              expect(result, isTrue);
              expect(messages.isEmpty, isTrue);
            }
          });
        });
      });
    });

    group('exec(direcotry, ggLog)', () {
      group('should print »✅ Version is prepared«', () {
        test('when the versions match', () async {
          // Assume the published version is 2.0.0
          when(
            () => publishedVersion.get(
              ggLog: any(named: 'ggLog'),
              directory: any(named: 'directory'),
            ),
          ).thenAnswer((_) async => Version(2, 0, 0));

          await addAndCommitVersions(
            d,
            pubspec: '2.0.1',
            changeLog: '2.0.1',
            gitHead: '2.0.1',
          );

          await runner.run([
            'is-version-prepared',
            '-i',
            d.path,
          ]);
          expect(messages[0], contains('⌛️ Version is prepared'));
          expect(messages[1], contains('✅ Version is prepared'));
        });
      });

      group('should print »❌ Version is prepared«', () {
        group('and throw an error description', () {
          test('when the versions do not match', () async {
            await addAndCommitVersions(
              d,
              pubspec: '2.0.0',
              changeLog: '3.0.0',
              gitHead: '2.0.1',
            );

            String exceptionMessage = '';

            try {
              await runner.run([
                'is-version-prepared',
                '-i',
                d.path,
              ]);
            } catch (e) {
              exceptionMessage = e.toString();
            }

            expect(messages[0], contains('⌛️ Version is prepared'));
            expect(messages[1], contains('❌ Version is prepared'));

            expect(
              exceptionMessage,
              contains(darkGray('$versions must be the same.')),
            );
          });
        });
      });
    });

    test('should have a code coverage of 100%', () {
      expect(() => IsVersionPrepared(ggLog: ggLog), returnsNormally);
    });
  });
}
