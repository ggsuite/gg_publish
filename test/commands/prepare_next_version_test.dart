// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() async {
  final messages = <String>[];
  final ggLog = messages.add;
  late Directory d;
  late PrepareNextVersion prepareNextVersion;
  late PublishedVersion publishedVersion;
  late CommandRunner<void> runner;

  // ...........................................................................
  void mockPublishedVersion() {
    when(
      () => publishedVersion.get(
        ggLog: ggLog,
        directory: any(
          named: 'directory',
          that: predicate<dynamic>((x) {
            return x.path == d.path;
          }),
        ),
      ),
    ).thenAnswer(
      (_) async => Version(1, 2, 3),
    );
  }

  // ...........................................................................
  setUp(() async {
    d = await initTestDir();
    registerFallbackValue(d);

    messages.clear();
    publishedVersion = MockPublishedVersion();
    prepareNextVersion = PrepareNextVersion(
      ggLog: ggLog,
      publishedVersion: publishedVersion,
    );
    runner = CommandRunner<void>('test', 'test')
      ..addCommand(prepareNextVersion);

    await addPubspecFileWithoutCommitting(d, version: '1.2.3');
    await addChangeLogWithoutCommitting(d, version: '1.2.3');
  });

  tearDown(() async {
    await d.delete(recursive: true);
  });

  // ...........................................................................
  group('PrepareNextVersion', () {
    group('apply(directory, ggLog, increment)', () {
      group('should throw', () {
        group('if pubspec.yaml', () {
          test('is missing', () async {
            // Delete pubspec.yaml
            await File('${d.path}/pubspec.yaml').delete();

            // Execute command
            late String exception;

            try {
              await prepareNextVersion.apply(
                ggLog: ggLog,
                directory: d,
                increment: VersionIncrement.patch,
              );
            } catch (e) {
              exception = e.toString();
            }

            // Check exception
            expect(
              exception,
              'Exception: pubspec.yaml not found',
            );
          });

          test('is not containing a version', () async {
            // Empty pubspec.yaml
            await File('${d.path}/pubspec.yaml').writeAsString('');

            // Execute command
            late String exception;

            try {
              await prepareNextVersion.apply(
                ggLog: ggLog,
                directory: d,
                increment: VersionIncrement.patch,
              );
            } catch (e) {
              exception = e.toString();
            }

            // Check exception
            expect(
              exception,
              'Exception: "version:" not found in pubspec.yaml',
            );
          });
        });
      });

      group('should write the next version', () {
        test('into pubspec.yaml', () async {
          mockPublishedVersion();

          // Execute command
          await prepareNextVersion.apply(
            ggLog: ggLog,
            directory: d,
            increment: VersionIncrement.patch,
          );

          // Check pubspec.yaml
          final content = await File('${d.path}/pubspec.yaml').readAsString();
          expect(
            content,
            contains('version: 1.2.4'),
          );
        });
      });
    });

    group('exec(directory, ggLog, increment)', () {
      group('should allow to run the command from CLI', () {
        group('and throw', () {
          test('when no --version-increment option is specified', () async {
            // Execute command
            late String exception;

            try {
              await runner.run(['prepare-next-version']);
            } catch (e) {
              exception = e.toString();
            }

            // Check exception
            expect(
              exception,
              contains(
                'Invalid argument(s): Option version-increment is mandatory.',
              ),
            );
          });
        });
        group('and increase the version in pubspec.yaml', () {
          for (final increment in VersionIncrement.values) {
            test('with increment == ${increment.name}', () async {
              mockPublishedVersion();

              // Execute command
              await runner.run([
                'prepare-next-version',
                '--version-increment',
                increment.name,
                '-i',
                d.path,
              ]);

              // Expected next version
              final expectedNextVersion =
                  prepareNextVersion.calculateNextVersion(
                publishedVersion: Version(1, 2, 3),
                increment: increment,
              );

              // Check pubspec.yaml
              final content =
                  await File('${d.path}/pubspec.yaml').readAsString();
              expect(
                content,
                contains('version: $expectedNextVersion'),
              );
            });
          }
        });
      });
    });

    group('calculateNextVersion(publishedVersion, increment)', () {
      group('with increment == VersionIncrement.major', () {
        test('should return the next major version', () {
          final version = prepareNextVersion.calculateNextVersion(
            publishedVersion: Version(1, 2, 3),
            increment: VersionIncrement.major,
          );

          expect(version, Version(2, 0, 0));
        });
      });

      group('with increment == VersionIncrement.minor', () {
        test('should return the next minor version', () {
          final version = prepareNextVersion.calculateNextVersion(
            publishedVersion: Version(1, 2, 3),
            increment: VersionIncrement.minor,
          );

          expect(version, Version(1, 3, 0));
        });
      });

      group('with increment == VersionIncrement.patch', () {
        test('should return the next patch version', () {
          final version = prepareNextVersion.calculateNextVersion(
            publishedVersion: Version(1, 2, 3),
            increment: VersionIncrement.patch,
          );

          expect(version, Version(1, 2, 4));
        });
      });
    });

    group('nextVersion(directory, ggLog, increment)', () {
      test('should return the next version', () async {
        mockPublishedVersion();

        final nextVersion = await prepareNextVersion.nextVersion(
          ggLog: ggLog,
          directory: d,
          increment: VersionIncrement.patch,
        );

        expect(nextVersion, Version(1, 2, 4));
      });
    });

    test('should have a code coverage of 100%', () {
      expect(PrepareNextVersion(ggLog: ggLog), isNotNull);
    });
  });
}
