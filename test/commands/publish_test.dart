// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
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
import 'package:test/test.dart';

void main() {
  final catalog = LanguageCatalog.fromString(_catalogJson);

  final messages = <String>[];
  final ggLog = messages.add;
  late Directory d;
  late Publish publish;
  late GgProcessWrapper processWrapper;
  late GgFakeProcess process;
  late IsVersionPrepared isVersionPrepared;
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
  void mockProcess({required int result, required bool force}) {
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
    publish = Publish(
      ggLog: ggLog,
      processWrapper: processWrapper,
      isVersionPrepared: isVersionPrepared,
      readLineFromStdIn: () => stdInValue,
      catalog: catalog,
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

        test('runs the captured publish through a shell when the catalog '
            'requests it', () async {
          final shellPublish = Publish(
            ggLog: ggLog,
            processWrapper: processWrapper,
            isVersionPrepared: isVersionPrepared,
            readLineFromStdIn: () => stdInValue,
            catalog: LanguageCatalog.fromString(_shellCatalogJson),
          );
          when(
            () => isVersionPrepared.get(ggLog: ggLog, directory: d),
          ).thenAnswer((_) async => true);
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
        test('if versions are not consistent', () async {
          late String exceptionMessage;

          mockIsVersionPrepared(false);
          mockProcess(result: 0, force: false);

          try {
            await publish.exec(directory: d, ggLog: ggLog);
          } on Exception catch (e) {
            exceptionMessage = e.toString();
          }

          expect(
            exceptionMessage,
            contains('Exception: Version is not prepared.'),
          );
        });

        test('if »dart pub publish« has exit code != 0', () async {
          // Setup consistent versions
          mockIsVersionPrepared(true);
          mockProcess(result: 0, force: false);

          // Start the process
          late String exceptionMessage;
          publish.exec(directory: d, ggLog: ggLog).onError((error, stackTrace) {
            exceptionMessage = error.toString();
          });

          // Let the process fail
          process.exit(1);
          await Future<void>.delayed(Duration.zero);

          // Check the exception
          expect(
            exceptionMessage,
            contains('»dart pub publish« failed with exit code 1'),
          );
        });

        test('if »dart pub publish« returns errors', () async {
          // Setup consistent versions
          mockIsVersionPrepared(true);
          mockProcess(result: 0, force: false);

          // Start the process
          late String exceptionMessage;
          publish.exec(directory: d, ggLog: ggLog).onError((error, stackTrace) {
            exceptionMessage = error.toString();
          });
          await Future<void>.delayed(Duration.zero);

          // Let the process return errors
          process.pushToStderr.add('Error: Something went wrong');
          await Future<void>.delayed(Duration.zero);

          // Let the process not fail
          process.exit(0);
          await Future<void>.delayed(Duration.zero);

          // Check the exception
          expect(
            exceptionMessage,
            contains('»dart pub publish« failed with exit code 0'),
          );

          expect(exceptionMessage, contains('Error: Something went wrong'));
        });

        test('and surfaces the output tail when stderr is empty', () async {
          // npm/pnpm often write the real error to stdout (e.g. a 404/401
          // on publish). The failure must still carry that detail.
          mockIsVersionPrepared(true);
          mockProcess(result: 0, force: false);

          late String exceptionMessage;
          publish.exec(directory: d, ggLog: ggLog).onError((error, _) {
            exceptionMessage = error.toString();
          });
          await Future<void>.delayed(Duration.zero);

          process.pushToStdout.add('npm error 404 Not Found - PUT ...');
          await Future<void>.delayed(Duration.zero);

          process.exit(1);
          await Future<void>.delayed(Duration.zero);

          expect(exceptionMessage, contains('failed with exit code 1'));
          expect(exceptionMessage, contains('npm error 404 Not Found'));
        });

        test('keeps only the most recent output in the failure tail', () async {
          mockIsVersionPrepared(true);
          mockProcess(result: 0, force: false);

          late String exceptionMessage;
          publish.exec(directory: d, ggLog: ggLog).onError((error, _) {
            exceptionMessage = error.toString();
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
          expect(exceptionMessage, contains('VERY-LAST-LINE'));
          expect(exceptionMessage, isNot(contains('VERY-FIRST-LINE')));
        });
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

          bool isDone = false;
          publish
              .exec(directory: tsDir, ggLog: ggLog)
              .then((_) => isDone = true);
          await Future<void>.delayed(Duration.zero);
          process.exit(0);
          await Future<void>.delayed(Duration.zero);

          expect(isDone, isTrue);
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

          bool isDone = false;
          publish
              .exec(directory: pnpmDir, ggLog: ggLog)
              .then((_) => isDone = true);
          await Future<void>.delayed(Duration.zero);
          process.exit(0);
          await Future<void>.delayed(Duration.zero);

          expect(isDone, isTrue);
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

          late String exceptionMessage;
          publish
              .exec(directory: pnpmDir, ggLog: ggLog)
              .onError((error, _) => exceptionMessage = error.toString());
          await Future<void>.delayed(Duration.zero);
          process.exit(1);
          await Future<void>.delayed(Duration.zero);

          expect(
            exceptionMessage,
            contains('»pnpm publish --no-git-checks« failed with exit code 1'),
          );
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

          bool isDone = false;
          publish
              .exec(directory: bridgeDir, ggLog: ggLog)
              .then((_) => isDone = true);
          await Future<void>.delayed(Duration.zero);
          process.exit(0);
          await Future<void>.delayed(Duration.zero);

          expect(isDone, isTrue);
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
const _shellCatalogJson =
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

const _catalogJson =
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
