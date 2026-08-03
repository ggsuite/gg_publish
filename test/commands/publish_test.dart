// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// ignore_for_file: unawaited_futures

import 'dart:io';

import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_lang/gg_lang.dart';
import 'package:gg_process/gg_process.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import 'package:gg_console_colors/gg_console_colors.dart';

void main() {
  final catalog = LanguageCatalog.fromString(catalogJson);

  final messages = <String>[];
  final ggLog = messages.add;
  late Directory d;
  late Publish publish;
  late GgProcessWrapper processWrapper;
  late GgFakeProcess process;
  late IsVersionPrepared isVersionPrepared;
  late MockRemoveVersionTag removeVersionTag;
  late MockPublishedVersion publishedVersion;
  late String? stdInValue;

  // ...........................................................................
  void mockIsVersionPrepared(bool value) {
    when(() {
      when(
        () => isVersionPrepared.get(ggLog: ggLog, directory: d),
      ).thenAnswer((_) => Future.value(value));
    });
  }

  // ...........................................................................
  /// Makes the registry report the given version lists, one per call.
  /// The last list is repeated for further calls. Null means »the package
  /// has no public registry«.
  void mockRegistryVersions(List<List<Version>?> results) {
    var call = 0;
    when(
      () =>
          publishedVersion.registryVersions(directory: any(named: 'directory')),
    ).thenAnswer((_) async {
      final result = results[call < results.length ? call : results.length - 1];
      call++;
      return result;
    });
  }

  // ...........................................................................
  /// Stubs the `--dry-run` validation preceding every Dart publish.
  void mockDryRun({
    String stdout = 'Package has 0 warnings.',
    String stderr = '',
    int exitCode = 0,
    String executable = 'dart',
    bool runInShell = false,
    Directory? directory,
  }) {
    when(
      () => processWrapper.run(
        executable,
        ['pub', 'publish', '--dry-run'],
        workingDirectory: (directory ?? d).path,
        runInShell: runInShell,
      ),
    ).thenAnswer((_) async => ProcessResult(0, exitCode, stdout, stderr));
  }

  // ...........................................................................
  void mockProcess({required int result, required bool force}) {
    mockDryRun();
    when(
      () => processWrapper.start('dart', [
        'pub',
        'publish',
        if (force) '--force',
      ], workingDirectory: d.path),
    ).thenAnswer((_) => Future.value(process));
  }

  // ...........................................................................
  setUp(() async {
    messages.clear();
    d = await Directory.systemTemp.createTemp();
    await initGit(d);
    await addAndCommitSampleFile(d);
    // A manifest so the publish command can be resolved for the project type.
    File(
      '${d.path}/pubspec.yaml',
    ).writeAsStringSync('name: test\nversion: 1.0.0\n');
    process = GgFakeProcess();
    isVersionPrepared = MockIsVersionPrepared();
    processWrapper = MockGgProcessWrapper();
    removeVersionTag = MockRemoveVersionTag();
    publishedVersion = MockPublishedVersion();
    registerFallbackValue(d);
    removeVersionTag.mockGet(result: false, ggLog: ggLog);
    // By default the package is already available on the registry.
    mockRegistryVersions([
      [Version(0, 9, 0)],
    ]);
    publish = Publish(
      ggLog: ggLog,
      processWrapper: processWrapper,
      isVersionPrepared: isVersionPrepared,
      removeVersionTag: removeVersionTag,
      readLineFromStdIn: () => stdInValue,
      catalog: catalog,
      publishedVersion: publishedVersion,
    );
  });

  // ...........................................................................
  tearDown(() async {
    await d.delete(recursive: true);
  });

  // ...........................................................................
  group('Publish', () {
    group('exec(directory, ggLog)', () {
      group('should publish', () {
        test('and log the ongoing process live', () async {
          // Setup consistent versions
          mockIsVersionPrepared(true);
          mockProcess(result: 0, force: false);

          // Start the process
          bool isDone = false;
          publish
              .exec(directory: d, ggLog: ggLog)
              .then((value) => isDone = true);
          await Future<void>.delayed(Duration.zero);

          // Let the process output some message
          process.pushToStdout.add('Something happens.');
          await Future<void>.delayed(Duration.zero);

          // It should be logged
          expect(messages.last, contains('Something happens.'));

          // Let the process not fail
          process.exit(0);
          await Future<void>.delayed(Duration.zero);

          expect(isDone, isTrue);
        });

        group('and ask (not) the user for confirmation', () {
          for (final ask in [null, false, true]) {
            test('when askBeforePublishing is $ask', () async {
              final shouldAsk = ask == true || ask == null;

              // Setup consistent versions
              mockIsVersionPrepared(true);
              mockProcess(result: 0, force: !shouldAsk);

              // Start the process
              bool isDone = false;
              publish
                  .exec(directory: d, ggLog: ggLog, askBeforePublishing: ask)
                  .then((value) => isDone = true);
              await Future<void>.delayed(Duration.zero);

              if (shouldAsk) {
                // Answer the next question with y
                stdInValue = 'y';

                // Let the process output some message
                process.pushToStdout.add('Do you want to publish');

                await Future<void>.delayed(Duration.zero);

                // It should be logged
                expect(messages.last, contains('Do you want to publish'));
              }

              // Let the process not fail
              process.exit(0);
              await Future<void>.delayed(Duration.zero);

              expect(isDone, isTrue);
            });
          }
        });

        test('although »dart pub publish« writes notices to stderr', () async {
          // `dart pub` uses stderr for progress and informational output,
          // e.g. »Uploading...«. That must not turn a successful publish
          // (exit code 0) into a failure.
          mockIsVersionPrepared(true);
          mockProcess(result: 0, force: false);

          bool isDone = false;
          Object? exception;
          publish
              .exec(directory: d, ggLog: ggLog)
              .then((value) => isDone = true)
              .onError((error, _) {
                exception = error;
                return false;
              });
          await Future<void>.delayed(Duration.zero);

          // Let the process write a notice to stderr
          process.pushToStderr.add('Uploading... (0.5s)');
          await Future<void>.delayed(Duration.zero);

          // Let the process succeed
          process.exit(0);
          await Future<void>.delayed(Duration.zero);

          expect(exception, isNull);
          expect(isDone, isTrue);
        });

        test('after removing an already existing version tag', () async {
          // A publish that failed after tagging leaves the tag on a commit
          // this run replaces. It must be gone - locally and on the remote -
          // before publishing, so the tag step can recreate it.
          mockIsVersionPrepared(true);
          mockProcess(result: 0, force: false);
          removeVersionTag.mockGet(result: true, ggLog: ggLog);

          final future = publish.exec(directory: d, ggLog: ggLog);
          await Future<void>.delayed(Duration.zero);
          process.exit(0);
          await future;

          verifyInOrder([
            () => removeVersionTag.get(directory: d, ggLog: ggLog),
            () => processWrapper.start('dart', [
              'pub',
              'publish',
            ], workingDirectory: d.path),
          ]);
        });

        test('runs the captured publish through a shell when the catalog '
            'requests it', () async {
          final shellPublish = Publish(
            ggLog: ggLog,
            processWrapper: processWrapper,
            isVersionPrepared: isVersionPrepared,
            removeVersionTag: removeVersionTag,
            readLineFromStdIn: () => stdInValue,
            catalog: LanguageCatalog.fromString(shellCatalogJson),
            publishedVersion: publishedVersion,
          );
          when(
            () => isVersionPrepared.get(ggLog: ggLog, directory: d),
          ).thenAnswer((_) async => true);
          mockDryRun(runInShell: true);
          when(
            () => processWrapper.start(
              'dart',
              ['pub', 'publish'],
              workingDirectory: d.path,
              runInShell: true,
            ),
          ).thenAnswer((_) => Future.value(process));

          bool isDone = false;
          shellPublish
              .exec(directory: d, ggLog: ggLog)
              .then((_) => isDone = true);
          await Future<void>.delayed(Duration.zero);
          process.exit(0);
          await Future<void>.delayed(Duration.zero);

          expect(isDone, isTrue);
        });
      });
      group('should throw', () {
        test('if the project has no manifest', () async {
          late String exceptionMessage;

          mockIsVersionPrepared(true);
          File('${d.path}/pubspec.yaml').deleteSync();

          try {
            await publish.exec(directory: d, ggLog: ggLog);
          } on Exception catch (e) {
            exceptionMessage = rmC(e.toString());
          }

          expect(exceptionMessage, contains('No registry to publish to.'));
        });

        test('if versions are not consistent', () async {
          late String exceptionMessage;

          mockIsVersionPrepared(false);
          mockProcess(result: 0, force: false);

          try {
            await publish.exec(directory: d, ggLog: ggLog);
          } on Exception catch (e) {
            exceptionMessage = rmC(e.toString());
          }

          expect(
            exceptionMessage,
            contains('Exception: Version is not prepared.'),
          );
        });

        test('and reports the stderr of a failing publish', () async {
          // Setup consistent versions
          mockIsVersionPrepared(true);
          mockProcess(result: 0, force: false);

          // Start the process
          late String exceptionMessage;
          publish.exec(directory: d, ggLog: ggLog).onError((error, stackTrace) {
            exceptionMessage = rmC(error.toString());
          });
          await Future<void>.delayed(Duration.zero);

          // Let the process write an error to stderr
          process.pushToStderr.add('Error: Something went wrong');
          await Future<void>.delayed(Duration.zero);

          // Let the process fail
          process.exit(1);
          await Future<void>.delayed(Duration.zero);

          // Check the exception
          expect(exceptionMessage, contains('Publishing failed.'));
          // The cause is printed once, not packed into the exception.
          expect(messages.join('\n'), contains('Error: Something went wrong'));
        });

        test('if »dart pub publish« has exit code != 0', () async {
          // Setup consistent versions
          mockIsVersionPrepared(true);
          mockProcess(result: 0, force: false);

          // Start the process
          late String exceptionMessage;
          publish.exec(directory: d, ggLog: ggLog).onError((error, stackTrace) {
            exceptionMessage = rmC(error.toString());
          });

          // Let the process fail
          process.exit(1);
          await Future<void>.delayed(Duration.zero);

          // Check the exception
          expect(exceptionMessage, contains('Publishing failed.'));
        });

        test('and surfaces the output tail when stderr is empty', () async {
          // npm/pnpm often write the real error to stdout (e.g. a 404/401
          // on publish). The failure must still carry that detail.
          mockIsVersionPrepared(true);
          mockProcess(result: 0, force: false);

          late String exceptionMessage;
          publish.exec(directory: d, ggLog: ggLog).onError((error, _) {
            exceptionMessage = rmC(error.toString());
          });
          await Future<void>.delayed(Duration.zero);

          process.pushToStdout.add('npm error 404 Not Found - PUT ...');
          await Future<void>.delayed(Duration.zero);

          process.exit(1);
          await Future<void>.delayed(Duration.zero);

          expect(exceptionMessage, contains('Publishing failed.'));
          // The cause is printed once, not packed into the exception.
          expect(messages.join('\n'), contains('npm error 404 Not Found'));
        });

        test('keeps only the most recent output in the failure tail', () async {
          mockIsVersionPrepared(true);
          mockProcess(result: 0, force: false);

          late String exceptionMessage;
          publish.exec(directory: d, ggLog: ggLog).onError((error, _) {
            exceptionMessage = rmC(error.toString());
          });
          await Future<void>.delayed(Duration.zero);

          process.pushToStdout.add('VERY-FIRST-LINE');
          for (var i = 0; i < 60; i++) {
            process.pushToStdout.add('filler $i');
          }
          process.pushToStdout.add('VERY-LAST-LINE');
          await Future<void>.delayed(Duration.zero);

          process.exit(1);
          await Future<void>.delayed(Duration.zero);

          // The bounded tail drops the earliest output, keeps the latest.
          expect(exceptionMessage, contains('Publishing failed.'));
          final report = messages.firstWhere((m) => m.contains('exit code'));
          expect(report, contains('VERY-LAST-LINE'));
          expect(report, isNot(contains('VERY-FIRST-LINE')));
        });
      });

      group('when the package is not yet in the registry', () {
        Publish publishWithAnswers(List<String?> answers) => Publish(
          ggLog: ggLog,
          processWrapper: processWrapper,
          isVersionPrepared: isVersionPrepared,
          removeVersionTag: removeVersionTag,
          readLineFromStdIn: () => answers.removeAt(0),
          catalog: catalog,
          publishedVersion: publishedVersion,
        );

        test('asks for a manual first publish and skips the automated '
            'upload when the user published the current version', () async {
          mockIsVersionPrepared(true);
          mockRegistryVersions([
            <Version>[],
            [Version(1, 0, 0)],
          ]);

          await publishWithAnswers(['']).exec(directory: d, ggLog: ggLog);

          final log = messages.join('\n');
          expect(log, contains('»test« has no version published on pub.dev'));
          expect(
            log,
            contains(
              'publish the first version manually directly out of the '
              'current working folder',
            ),
          );
          expect(log, contains('cd ${d.absolute.path}'));
          expect(log, contains('dart pub publish'));
          expect(log, contains('»test« is now available on pub.dev'));

          // The user published 1.0.0 - the current version - manually, so
          // the automated upload must not run. The stale-tag cleanup that
          // precedes the upload still does.
          verify(() => removeVersionTag.get(directory: d, ggLog: ggLog));
          verifyNever(
            () => processWrapper.start(
              any(),
              any(),
              workingDirectory: any(named: 'workingDirectory'),
            ),
          );
        });

        test('runs the automated upload when the user published '
            'a different version manually', () async {
          mockIsVersionPrepared(true);
          mockRegistryVersions([
            <Version>[],
            [Version(0, 5, 0)],
          ]);
          mockProcess(result: 0, force: false);

          final future = publishWithAnswers([
            '',
          ]).exec(directory: d, ggLog: ggLog);
          await Future<void>.delayed(Duration.zero);
          process.exit(0);
          await future;

          // 0.5.0 is on the registry now, but the current version 1.0.0
          // still needs the regular upload.
          verify(
            () => processWrapper.start('dart', [
              'pub',
              'publish',
            ], workingDirectory: d.path),
          );
        });

        test('asks again while the package is not yet visible', () async {
          mockIsVersionPrepared(true);
          mockRegistryVersions([
            <Version>[],
            <Version>[],
            [Version(1, 0, 0)],
          ]);

          await publishWithAnswers(['', '']).exec(directory: d, ggLog: ggLog);

          expect(
            messages.join('\n'),
            contains('»test« is not yet visible on pub.dev'),
          );
        });

        test('treats an unresolvable registry re-check like »not yet '
            'visible«', () async {
          mockIsVersionPrepared(true);
          mockRegistryVersions([
            <Version>[],
            null,
            [Version(1, 0, 0)],
          ]);

          await publishWithAnswers(['', '']).exec(directory: d, ggLog: ggLog);

          expect(
            messages.join('\n'),
            contains('»test« is not yet visible on pub.dev'),
          );
        });

        test('aborts when the user enters »q«', () async {
          mockIsVersionPrepared(true);
          mockRegistryVersions([<Version>[]]);

          await expectLater(
            publishWithAnswers(['q']).exec(directory: d, ggLog: ggLog),
            throwsA(
              isA<Exception>().having(
                (e) => rmC(e.toString()),
                'message',
                contains(
                  'Publishing aborted.',
                ),
              ),
            ),
          );
        });

        test('shows a pnpm command with »--access public« and the dist tag '
            'for a scoped prerelease npm package', () async {
          final tsDir = await Directory.systemTemp.createTemp();
          File(
            '${tsDir.path}/package.json',
          ).writeAsStringSync('{"name": "@org/ts", "version": "1.1.0-rc.1"}');
          File('${tsDir.path}/tsconfig.json').writeAsStringSync('{}');

          when(
            () => isVersionPrepared.get(ggLog: ggLog, directory: tsDir),
          ).thenAnswer((_) async => true);
          mockRegistryVersions([
            <Version>[],
            [Version.parse('1.1.0-rc.1')],
          ]);

          await publishWithAnswers(['']).exec(directory: tsDir, ggLog: ggLog);

          final log = messages.join('\n');
          expect(log, contains('»@org/ts« has no version published on npm'));
          expect(
            log,
            contains(
              'pnpm publish --no-git-checks --access public '
              '--tag rc',
            ),
          );

          await tsDir.delete(recursive: true);
        });

        test(
          'shows a plain pnpm command for an unscoped stable npm package',
          () async {
            final tsDir = await Directory.systemTemp.createTemp();
            File(
              '${tsDir.path}/package.json',
            ).writeAsStringSync('{"name": "ts", "version": "1.0.0"}');
            File('${tsDir.path}/tsconfig.json').writeAsStringSync('{}');

            when(
              () => isVersionPrepared.get(ggLog: ggLog, directory: tsDir),
            ).thenAnswer((_) async => true);
            mockRegistryVersions([
              <Version>[],
              [Version(1, 0, 0)],
            ]);

            await publishWithAnswers(['']).exec(directory: tsDir, ggLog: ggLog);

            final log = messages.join('\n');
            expect(log, contains('cd ${tsDir.absolute.path}'));
            expect(log, contains('pnpm publish --no-git-checks'));
            expect(log, isNot(contains('--access public')));
            expect(log, isNot(contains('--tag')));

            await tsDir.delete(recursive: true);
          },
        );
      });

      group('with »--dry-run«', () {
        const warning = '''
Package validation found the following potential issue:
* 2 checked-in files are ignored by a `.gitignore`.

  Files that are checked in while gitignored:

  .gg/.gg.json
  .gg/.ticket.json

The server may enforce additional checks.

Package has 1 warning.''';

        test(
          'breaks the publishing when the dry run reports a warning',
          () async {
            mockIsVersionPrepared(true);
            mockDryRun(stdout: '', stderr: warning, exitCode: 65);

            late String exceptionMessage;
            await publish
                .exec(directory: d, ggLog: ggLog)
                .onError(
                  (error, _) => exceptionMessage = rmC(error.toString()),
                );

            expect(
              exceptionMessage,
              contains('Publishing was stopped by a warning.'),
            );

            // The warning itself is a detail — the ✗ line above it carries
            // the red. The paths within it stay blue.
            final logged = messages.firstWhere((m) => m.contains('.gg.json'));
            expect(logged, startsWith('\x1B[90m'));
            expect(
              messages.any((m) => m.startsWith('\x1B[31m✗ ')),
              isTrue,
            );
            expect(logged, contains('\x1B[34m.gg/.gg.json'));
            expect(logged, contains('\x1B[34m.gg/.ticket.json'));
            // The summary line is not part of the printed report.
            expect(logged, isNot(contains('additional checks')));

            // The real publish must not have been started.
            verifyNever(
              () => processWrapper.start(
                any(),
                any(),
                workingDirectory: any(named: 'workingDirectory'),
              ),
            );
          },
        );

        test(
          'breaks the publishing on a warning summary without a report',
          () async {
            mockIsVersionPrepared(true);
            mockDryRun(stdout: 'Package has 2 warnings.', exitCode: 65);

            late String exceptionMessage;
            await publish
                .exec(directory: d, ggLog: ggLog)
                .onError(
                  (error, _) => exceptionMessage = rmC(error.toString()),
                );

            expect(
              exceptionMessage,
              contains('Publishing was stopped by a warning.'),
            );
          },
        );

        test(
          'throws when the dry run fails without reporting a warning',
          () async {
            mockIsVersionPrepared(true);
            mockDryRun(stderr: 'Could not resolve dependencies', exitCode: 1);

            late String exceptionMessage;
            await publish
                .exec(directory: d, ggLog: ggLog)
                .onError(
                  (error, _) => exceptionMessage = rmC(error.toString()),
                );

            expect(exceptionMessage, contains('Publishing failed.'));
            // The cause is printed once, not packed into the exception.
            expect(
              messages.join('\n'),
              contains('Could not resolve dependencies'),
            );
          },
        );

        test(
          'throws without detail when the failing dry run stays silent',
          () async {
            mockIsVersionPrepared(true);
            mockDryRun(exitCode: 1, stdout: '');

            late String exceptionMessage;
            await publish
                .exec(directory: d, ggLog: ggLog)
                .onError(
                  (error, _) => exceptionMessage = rmC(error.toString()),
                );

            expect(exceptionMessage, contains('Publishing failed.'));
          },
        );
      });

      group('for a TypeScript project (published interactively)', () {
        test('runs »npm publish« with inherited stdio', () async {
          final tsDir = await Directory.systemTemp.createTemp();
          File(
            '${tsDir.path}/package.json',
          ).writeAsStringSync('{"name": "ts", "version": "1.0.0"}');
          File('${tsDir.path}/tsconfig.json').writeAsStringSync('{}');

          when(
            () => isVersionPrepared.get(ggLog: ggLog, directory: tsDir),
          ).thenAnswer((_) async => true);
          when(
            () => processWrapper.start(
              'npm',
              ['publish'],
              workingDirectory: tsDir.path,
              runInShell: true,
              mode: ProcessStartMode.inheritStdio,
            ),
          ).thenAnswer((_) => Future.value(process));

          // exitCode is a completer; completing it before the flow awaits it
          // is safe, so no polling is needed — await the exec future directly.
          final future = publish.exec(directory: tsDir, ggLog: ggLog);
          process.exit(0);
          await future;

          await tsDir.delete(recursive: true);
        });

        test('adds »--tag rc« for a prerelease version', () async {
          // Without a dist-tag, npm would move `latest` onto the prerelease.
          final tsDir = await Directory.systemTemp.createTemp();
          File(
            '${tsDir.path}/package.json',
          ).writeAsStringSync('{"name": "ts", "version": "1.1.0-rc.1"}');
          File('${tsDir.path}/tsconfig.json').writeAsStringSync('{}');

          when(
            () => isVersionPrepared.get(ggLog: ggLog, directory: tsDir),
          ).thenAnswer((_) async => true);
          when(
            () => processWrapper.start(
              'npm',
              ['publish', '--tag', 'rc'],
              workingDirectory: tsDir.path,
              runInShell: true,
              mode: ProcessStartMode.inheritStdio,
            ),
          ).thenAnswer((_) => Future.value(process));

          final future = publish.exec(directory: tsDir, ggLog: ggLog);
          process.exit(0);
          await future;

          await tsDir.delete(recursive: true);
        });

        test('runs »pnpm publish --no-git-checks« for pnpm', () async {
          final pnpmDir = await Directory.systemTemp.createTemp();
          File(
            '${pnpmDir.path}/package.json',
          ).writeAsStringSync('{"name": "ts", "version": "1.0.0"}');
          File('${pnpmDir.path}/tsconfig.json').writeAsStringSync('{}');
          // The pnpm lockfile makes the project a pnpm project.
          File('${pnpmDir.path}/pnpm-lock.yaml').writeAsStringSync('');

          when(
            () => isVersionPrepared.get(ggLog: ggLog, directory: pnpmDir),
          ).thenAnswer((_) async => true);
          when(
            () => processWrapper.start(
              'pnpm',
              ['publish', '--no-git-checks'],
              workingDirectory: pnpmDir.path,
              runInShell: true,
              mode: ProcessStartMode.inheritStdio,
            ),
          ).thenAnswer((_) => Future.value(process));

          final future = publish.exec(directory: pnpmDir, ggLog: ggLog);
          process.exit(0);
          await future;

          await pnpmDir.delete(recursive: true);
        });

        test('throws when the interactive publish fails', () async {
          final pnpmDir = await Directory.systemTemp.createTemp();
          File(
            '${pnpmDir.path}/package.json',
          ).writeAsStringSync('{"name": "ts", "version": "1.0.0"}');
          File('${pnpmDir.path}/tsconfig.json').writeAsStringSync('{}');
          File('${pnpmDir.path}/pnpm-lock.yaml').writeAsStringSync('');

          when(
            () => isVersionPrepared.get(ggLog: ggLog, directory: pnpmDir),
          ).thenAnswer((_) async => true);
          when(
            () => processWrapper.start(
              'pnpm',
              ['publish', '--no-git-checks'],
              workingDirectory: pnpmDir.path,
              runInShell: true,
              mode: ProcessStartMode.inheritStdio,
            ),
          ).thenAnswer((_) => Future.value(process));

          String? exceptionMessage;
          final future = publish
              .exec(directory: pnpmDir, ggLog: ggLog)
              .onError((error, _) => exceptionMessage = rmC(error.toString()));
          process.exit(1);
          await future;

          expect(exceptionMessage, contains('Publishing failed.'));
          await pnpmDir.delete(recursive: true);
        });
      });

      group('for a bridge project (pubspec + package.json + tsconfig)', () {
        test('runs »npm publish«, not »dart pub publish«', () async {
          // A bridge ships pubspec.yaml AND package.json + tsconfig.json. It
          // is published as a TypeScript package, so the publish command must
          // resolve to »npm publish«.
          final bridgeDir = await Directory.systemTemp.createTemp();
          File('${bridgeDir.path}/pubspec.yaml').writeAsStringSync(
            'name: bridge\nversion: 1.0.0\npublish_to: none\n',
          );
          File(
            '${bridgeDir.path}/package.json',
          ).writeAsStringSync('{"name": "@org/bridge", "version": "1.0.0"}');
          File('${bridgeDir.path}/tsconfig.json').writeAsStringSync('{}');

          when(
            () => isVersionPrepared.get(ggLog: ggLog, directory: bridgeDir),
          ).thenAnswer((_) async => true);
          when(
            () => processWrapper.start(
              'npm',
              ['publish'],
              workingDirectory: bridgeDir.path,
              runInShell: true,
              mode: ProcessStartMode.inheritStdio,
            ),
          ).thenAnswer((_) => Future.value(process));

          final future = publish.exec(directory: bridgeDir, ggLog: ggLog);
          process.exit(0);
          await future;

          await bridgeDir.delete(recursive: true);
        });
      });
    });

    test('has a code coverage of 100%', () {
      expect(Publish(ggLog: ggLog), isNotNull);
    });
  });
}

const _manifest = '''
"manifest": {
  "file": "pubspec.yaml",
  "format": "yaml",
  "versionPath": "version",
  "namePath": "name",
  "publishTargetMarker": "publish_to",
  "lockFile": "pubspec.lock"
}''';

// A catalog whose Dart publish command asks to run through a shell, so the
// captured publish path exercises its runInShell branch.
const shellCatalogJson =
    '''
{
  "schemaVersion": 1,
  "languages": {
    "dart": {
      "displayName": "Dart",
      $_manifest,
      "commands": {
        "publish": {
          "label": "dart pub publish",
          "exec": "dart",
          "args": ["pub", "publish"],
          "runInShell": true
        }
      }
    }
  }
}
''';

const catalogJson =
    '''
{
  "schemaVersion": 1,
  "languages": {
    "dart": {
      "displayName": "Dart",
      $_manifest,
      "commands": {
        "publish": {
          "label": "dart pub publish",
          "exec": "dart",
          "args": ["pub", "publish"]
        }
      }
    },
    "flutter": {
      "displayName": "Flutter",
      $_manifest,
      "commands": {
        "publish": {
          "label": "flutter pub publish",
          "exec": "flutter",
          "args": ["pub", "publish"]
        }
      }
    },
    "typescript": {
      "displayName": "TypeScript",
      "manifest": {
        "file": "package.json",
        "format": "json",
        "versionPath": "version",
        "namePath": "name",
        "publishTargetMarker": "private",
        "lockFile": "package-lock.json"
      },
      "commands": {
        "publish": {
          "label": "npm publish",
          "exec": "npm",
          "args": ["publish"],
          "runInShell": true
        }
      }
    }
  }
}
''';
