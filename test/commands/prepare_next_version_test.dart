// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:gg_version/gg_version.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../test_helpers.dart';

import 'package:gg_console_colors/gg_console_colors.dart';

void main() async {
  final messages = <String>[];
  final ggLog = messages.add;
  late Directory d;
  late PrepareNextVersion prepareNextVersion;
  late PublishedVersion publishedVersion;
  late MockRemoteTags remoteTags;
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
    ).thenAnswer((_) async => Version(1, 2, 3));
  }

  // ...........................................................................
  setUp(() async {
    d = await initTestDir();
    registerFallbackValue(d);

    messages.clear();
    publishedVersion = MockPublishedVersion();
    remoteTags = MockRemoteTags();
    registerFallbackValue(Version(0, 0, 0));
    // No tags on origin: the published version stays the baseline.
    when(
      () => remoteTags.baseline(
        directory: any(named: 'directory'),
        ggLog: any(named: 'ggLog'),
        publishedVersion: any(named: 'publishedVersion'),
      ),
    ).thenAnswer(
      (invocation) async =>
          invocation.namedArguments[#publishedVersion] as Version,
    );
    prepareNextVersion = PrepareNextVersion(
      ggLog: ggLog,
      publishedVersion: publishedVersion,
      remoteTags: remoteTags,
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
      group('should do nothing', () {
        test('if the project has no manifest', () async {
          // Delete pubspec.yaml → ProjectType.none
          await File('${d.path}/pubspec.yaml').delete();

          // Execute command
          await prepareNextVersion.apply(
            ggLog: ggLog,
            directory: d,
            increment: VersionIncrement.patch,
          );

          // No manifest was created, the version lives in git tags only.
          expect(File('${d.path}/pubspec.yaml').existsSync(), isFalse);
          expect(messages.last, contains('Git-only project'));
        });
      });

      group('should throw', () {
        group('if pubspec.yaml', () {
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
              exception = rmC(e.toString());
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
          expect(content, contains('version: 1.2.4'));
        });

        test(
          'into pubspec.yaml, keeping and counting up the build number',
          () async {
            mockPublishedVersion();
            await addPubspecFileWithoutCommitting(d, version: '1.2.3+155');

            // Execute command
            await prepareNextVersion.apply(
              ggLog: ggLog,
              directory: d,
              increment: VersionIncrement.patch,
            );

            // Check pubspec.yaml
            final content = await File('${d.path}/pubspec.yaml').readAsString();
            expect(content, contains('version: 1.2.4+156'));
          },
        );

        test('into both manifests of a bridge, in lock-step', () async {
          // Turn the fixture into a bridge: add package.json + tsconfig.json.
          // The published version is read from the npm side (package.json), so
          // it must carry a version too.
          await File('${d.path}/package.json')
              .writeAsString('{"name": "@org/bridge", "version": "1.2.3"}');
          await File('${d.path}/tsconfig.json').writeAsString('{}');
          mockPublishedVersion();

          await prepareNextVersion.apply(
            ggLog: ggLog,
            directory: d,
            increment: VersionIncrement.patch,
          );

          // The published npm manifest is bumped …
          final packageJson = await File('${d.path}/package.json')
              .readAsString();
          expect(packageJson, contains('"version": "1.2.4"'));

          // … and the Dart side advances in lock-step.
          final pubspec = await File('${d.path}/pubspec.yaml').readAsString();
          expect(pubspec, contains('version: 1.2.4'));
        });
      });

      group('should write the generated version file', () {
        test(
          'carrying the version being released, not the previous one',
          () async {
            // »do publish« bumps, commits and then uploads without running the
            // tests again, so the generated constant has to be written here or
            // the published artifact would report the previous version.
            mockPublishedVersion();

            await prepareNextVersion.apply(
              ggLog: ggLog,
              directory: d,
              increment: VersionIncrement.patch,
            );

            final name = RegExp(r'^name:\s*(\S+)', multiLine: true)
                .firstMatch(
                  await File('${d.path}/pubspec.yaml').readAsString(),
                )!
                .group(1)!;
            final slug = versionFileSlug(name);
            final identifier = versionFileIdentifier(slug);

            final generated = File('${d.path}/lib/src/${slug}_version.dart');
            expect(generated.existsSync(), isTrue);
            expect(
              await generated.readAsString(),
              contains("const String $identifier = '1.2.4';"),
            );

            // The self-healing mirror test comes with it, otherwise gg_test
            // fails the »tests« check before running anything.
            expect(
              File('${d.path}/test/${slug}_version_test.dart').existsSync(),
              isTrue,
            );
          },
        );

        test('for both languages of a bridge', () async {
          await File('${d.path}/package.json')
              .writeAsString('{"name": "@org/bridge", "version": "1.2.3"}');
          await File('${d.path}/tsconfig.json').writeAsString('{}');
          mockPublishedVersion();

          await prepareNextVersion.apply(
            ggLog: ggLog,
            directory: d,
            increment: VersionIncrement.patch,
          );

          expect(
            await File('${d.path}/src/bridge_version.ts').readAsString(),
            contains("export const bridgeVersion = '1.2.4';"),
          );

          final name = RegExp(r'^name:\s*(\S+)', multiLine: true)
              .firstMatch(await File('${d.path}/pubspec.yaml').readAsString())!
              .group(1)!;
          final slug = versionFileSlug(name);
          expect(
            await File('${d.path}/lib/src/${slug}_version.dart').readAsString(),
            contains("= '1.2.4';"),
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
              exception = rmC(e.toString());
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
              final expectedNextVersion = prepareNextVersion
                  .calculateNextVersion(
                    publishedVersion: Version(1, 2, 3),
                    increment: increment,
                  );

              // Check pubspec.yaml
              final content = await File('${d.path}/pubspec.yaml')
                  .readAsString();
              expect(content, contains('version: $expectedNextVersion'));
            });
          }
        });
      });

      test('should allow to define the published version ', () async {
        await prepareNextVersion.exec(
          directory: d,
          ggLog: ggLog,
          publishedVersion: Version(1, 3, 6),
          increment: VersionIncrement.patch,
        );

        // Check pubspec.yaml
        final content = await File('${d.path}/pubspec.yaml').readAsString();
        expect(content, contains('version: 1.3.7'));
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

      group('with a build number in pubspec.yaml', () {
        test('should keep the build number and count it up', () async {
          mockPublishedVersion();
          await addPubspecFileWithoutCommitting(d, version: '1.2.3+155');

          final nextVersion = await prepareNextVersion.nextVersion(
            ggLog: ggLog,
            directory: d,
            increment: VersionIncrement.patch,
          );

          expect(nextVersion, Version.parse('1.2.4+156'));
        });

        test('should keep the build number of an already prepared '
            'pubspec.yaml', () async {
          mockPublishedVersion();
          await addPubspecFileWithoutCommitting(d, version: '1.2.4+156');

          final nextVersion = await prepareNextVersion.nextVersion(
            ggLog: ggLog,
            directory: d,
            increment: VersionIncrement.patch,
          );

          expect(nextVersion, Version.parse('1.2.4+156'));
        });
      });

      test('should ignore a pubspec.yaml without version', () async {
        mockPublishedVersion();
        await addPubspecFileWithoutCommitting(d, version: null);

        final nextVersion = await prepareNextVersion.nextVersion(
          ggLog: ggLog,
          directory: d,
          increment: VersionIncrement.patch,
        );

        expect(nextVersion, Version(1, 2, 4));
      });

      group('with channel == ReleaseChannel.rc', () {
        void mockAllVersions(List<Version> versions) {
          when(
            () => publishedVersion.allVersions(
              ggLog: ggLog,
              directory: any(named: 'directory'),
            ),
          ).thenAnswer((_) async => versions);
        }

        test('returns rc.1 when no rc exists for the target yet', () async {
          mockPublishedVersion();
          mockAllVersions([Version(1, 2, 3)]);

          final nextVersion = await prepareNextVersion.nextVersion(
            ggLog: ggLog,
            directory: d,
            increment: VersionIncrement.minor,
            channel: ReleaseChannel.rc,
          );

          expect(nextVersion, Version.parse('1.3.0-rc.1'));
        });

        test('keeps the build number of pubspec.yaml', () async {
          mockPublishedVersion();
          mockAllVersions([Version(1, 2, 3)]);
          await addPubspecFileWithoutCommitting(d, version: '1.2.3+155');

          final nextVersion = await prepareNextVersion.nextVersion(
            ggLog: ggLog,
            directory: d,
            increment: VersionIncrement.minor,
            channel: ReleaseChannel.rc,
          );

          expect(nextVersion, Version.parse('1.3.0-rc.1+156'));
        });

        test('increments the highest existing rc number', () async {
          mockPublishedVersion();
          mockAllVersions([
            Version(1, 2, 3),
            Version.parse('1.3.0-rc.1'),
            Version.parse('1.3.0-rc.3'),
          ]);

          final nextVersion = await prepareNextVersion.nextVersion(
            ggLog: ggLog,
            directory: d,
            increment: VersionIncrement.minor,
            channel: ReleaseChannel.rc,
          );

          expect(nextVersion, Version.parse('1.3.0-rc.4'));
        });

        test('uses allPublishedVersions when provided', () async {
          mockPublishedVersion();

          final nextVersion = await prepareNextVersion.nextVersion(
            ggLog: ggLog,
            directory: d,
            increment: VersionIncrement.patch,
            channel: ReleaseChannel.rc,
            allPublishedVersions: [Version.parse('1.2.4-rc.7')],
          );

          expect(nextVersion, Version.parse('1.2.4-rc.8'));
          verifyNever(
            () => publishedVersion.allVersions(
              ggLog: ggLog,
              directory: any(named: 'directory'),
            ),
          );
        });

        test('throws when the target is already published as stable', () async {
          mockPublishedVersion();
          mockAllVersions([Version(1, 2, 3), Version(1, 3, 0)]);

          await expectLater(
            prepareNextVersion.nextVersion(
              ggLog: ggLog,
              directory: d,
              increment: VersionIncrement.minor,
              channel: ReleaseChannel.rc,
            ),
            throwsA(
              isA<Exception>().having(
                (e) => rmC(e.toString()),
                'message',
                contains('The version is already published.'),
              ),
            ),
          );
        });

        test('ignores non-rc prereleases of the target', () async {
          mockPublishedVersion();
          mockAllVersions([
            Version.parse('1.3.0-beta.5'),
            Version.parse('1.3.0-rc.abc'),
          ]);

          final nextVersion = await prepareNextVersion.nextVersion(
            ggLog: ggLog,
            directory: d,
            increment: VersionIncrement.minor,
            channel: ReleaseChannel.rc,
          );

          expect(nextVersion, Version.parse('1.3.0-rc.1'));
        });
      });
    });

    group('apply(..., channel: ReleaseChannel.rc)', () {
      test('writes the rc version into pubspec.yaml', () async {
        mockPublishedVersion();
        when(
          () => publishedVersion.allVersions(
            ggLog: ggLog,
            directory: any(named: 'directory'),
          ),
        ).thenAnswer((_) async => [Version(1, 2, 3)]);

        await prepareNextVersion.apply(
          ggLog: ggLog,
          directory: d,
          increment: VersionIncrement.patch,
          channel: ReleaseChannel.rc,
        );

        final content = await File('${d.path}/pubspec.yaml').readAsString();
        expect(content, contains('version: 1.2.4-rc.1'));
      });
    });

    group('exec(..., --channel rc)', () {
      test('reads the channel from the command line', () async {
        mockPublishedVersion();
        when(
          () => publishedVersion.allVersions(
            ggLog: ggLog,
            directory: any(named: 'directory'),
          ),
        ).thenAnswer((_) async => [Version(1, 2, 3)]);

        await runner.run([
          'prepare-next-version',
          '--version-increment',
          'patch',
          '--channel',
          'rc',
          '-i',
          d.path,
        ]);

        final content = await File('${d.path}/pubspec.yaml').readAsString();
        expect(content, contains('version: 1.2.4-rc.1'));
      });
    });

    group('with version tags on origin', () {
      late Directory local;
      late Directory remote;
      late PrepareNextVersion command;

      // .......................................................................
      Future<void> tagOnOrigin(List<String> tags) async {
        await addTags(local, tags);
        await pushTags(local);

        // The tags are only on origin, as in a clone that never fetched them.
        for (final tag in tags) {
          await Process.run('git', [
            'tag',
            '-d',
            tag,
          ], workingDirectory: local.path);
        }
      }

      // .......................................................................
      Future<Version> next({
        required String manifest,
        VersionIncrement increment = VersionIncrement.patch,
        ReleaseChannel channel = ReleaseChannel.stable,
      }) async {
        await File('${local.path}/pubspec.yaml')
            .writeAsString('name: test\nversion: $manifest\n');

        return command.nextVersion(
          directory: local,
          ggLog: ggLog,
          increment: increment,
          channel: channel,
          publishedVersion: Version(0, 0, 145),
          allPublishedVersions: [Version(0, 0, 145)],
        );
      }

      // .......................................................................
      setUp(() async {
        (local, remote) = await initLocalAndRemoteGit();
        command = PrepareNextVersion(
          ggLog: ggLog,
          publishedVersion: publishedVersion,
        );
      });

      tearDown(() async {
        await local.delete(recursive: true);
        await remote.delete(recursive: true);
      });

      // .......................................................................
      test('should count on from a tag that is not published', () async {
        // The registry knows 0.0.145, origin already has a tag 0.0.146 that
        // somebody else set — releasing 0.0.146 would have to delete it.
        await tagOnOrigin(['0.0.145', '0.0.146']);

        expect(await next(manifest: '0.0.145'), Version(0, 0, 147));
        expect(
          messages.map(rmC),
          contains(
            'Origin has the tag 0.0.146, but 0.0.145 is the latest published '
            'version. Counting on from 0.0.146.',
          ),
        );
      });

      test('should count on from the highest tag, even across a gap', () async {
        // Tagging 0.0.147 would fail: it must be greater than 0.0.148.
        await tagOnOrigin(['0.0.146', '0.0.148']);

        expect(await next(manifest: '0.0.145'), Version(0, 0, 149));
      });

      test('should keep the chosen increment', () async {
        await tagOnOrigin(['0.1.0']);

        expect(
          await next(manifest: '0.0.145', increment: VersionIncrement.minor),
          Version(0, 2, 0),
        );
      });

      test('should count on from a tag the manifest already carries', () async {
        // Merged in from main, e.g. — the tag is still somebody else's.
        await tagOnOrigin(['0.0.146']);

        expect(
          await next(manifest: '0.0.146+7'),
          Version(0, 0, 147, build: '8'),
        );
      });

      test('should count an rc on from the tag as well', () async {
        await tagOnOrigin(['0.0.146']);

        expect(
          await next(manifest: '0.0.145', channel: ReleaseChannel.rc),
          Version(0, 0, 147, pre: 'rc.1'),
        );
      });

      test('should ignore tags up to the published version', () async {
        await tagOnOrigin(['0.0.100', '0.0.145', 'v9.9.9', 'release']);

        expect(await next(manifest: '0.0.145'), Version(0, 0, 146));
        expect(messages, isEmpty);
      });
    });

    test('should have a code coverage of 100%', () {
      expect(PrepareNextVersion(ggLog: ggLog), isNotNull);
    });
  });
}
