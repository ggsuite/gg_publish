// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_lang/gg_lang.dart';
import 'package:gg_process/gg_process.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:gg_console_colors/gg_console_colors.dart';

void main() {
  final catalog = LanguageCatalog.fromString(_catalogJson);

  final messages = <String>[];
  final ggLog = messages.add;
  late Directory local;
  late Directory remote;
  late RemoveVersionTag removeVersionTag;

  // ...........................................................................
  void writePubspec(Directory d, String version) => File(
    '${d.path}/pubspec.yaml',
  ).writeAsStringSync('name: test\nversion: $version\n');

  // ...........................................................................
  Future<List<String>> localTags(Directory d) async {
    final result = await Process.run('git', [
      'tag',
      '--list',
    ], workingDirectory: d.path);

    return (result.stdout as String)
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  // ...........................................................................
  Future<List<String>> remoteTags(Directory d) async {
    final result = await Process.run('git', [
      'ls-remote',
      '--tags',
      'origin',
    ], workingDirectory: d.path);

    return (result.stdout as String)
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((line) => line.split(RegExp(r'\s+')).last)
        .toList();
  }

  // ...........................................................................
  Future<void> pushTags(Directory d) async {
    final result = await Process.run('git', [
      'push',
      'origin',
      '--tags',
    ], workingDirectory: d.path);

    if (result.exitCode != 0) {
      throw Exception('Could not push the tags: ${result.stderr}');
    }
  }

  // ...........................................................................
  setUp(() async {
    messages.clear();
    (local, remote) = await initLocalAndRemoteGit();
    writePubspec(local, '1.0.0');
    removeVersionTag = RemoveVersionTag(ggLog: ggLog, catalog: catalog);
    registerFallbackValue(local);
  });

  // ...........................................................................
  tearDown(() async {
    await local.delete(recursive: true);
    await remote.delete(recursive: true);
  });

  // ...........................................................................
  group('RemoveVersionTag', () {
    group('get(directory, ggLog)', () {
      group('should remove the tag of the version to be published', () {
        test('locally as well as on the remote', () async {
          await addTag(local, '1.0.0');
          await pushTags(local);
          expect(await remoteTags(local), contains('refs/tags/1.0.0'));

          final removed = await removeVersionTag.get(
            directory: local,
            ggLog: ggLog,
          );

          expect(removed, isTrue);
          expect(await localTags(local), isEmpty);
          expect(await remoteTags(local), isEmpty);
          expect(messages, contains('Removed the local tag 1.0.0.'));
          expect(messages, contains('Removed the remote tag 1.0.0.'));
        });

        test('when the tag is an annotated one', () async {
          // An annotated tag makes »git ls-remote« print a second line for
          // the dereferenced commit (»refs/tags/1.0.0^{}«).
          final result = await Process.run('git', [
            'tag',
            '-a',
            '1.0.0',
            '-m',
            'Version 1.0.0',
          ], workingDirectory: local.path);
          expect(result.exitCode, 0);
          await pushTags(local);

          final removed = await removeVersionTag.get(
            directory: local,
            ggLog: ggLog,
          );

          expect(removed, isTrue);
          expect(await localTags(local), isEmpty);
          expect(await remoteTags(local), isEmpty);
        });

        test('when the tag exists only locally', () async {
          await addTag(local, '1.0.0');

          final removed = await removeVersionTag.get(
            directory: local,
            ggLog: ggLog,
          );

          expect(removed, isTrue);
          expect(await localTags(local), isEmpty);
          expect(messages, contains('Removed the local tag 1.0.0.'));
          expect(messages, isNot(contains('Removed the remote tag 1.0.0.')));
        });

        test('when the tag exists only on the remote', () async {
          await addTag(local, '1.0.0');
          await pushTags(local);
          await Process.run('git', [
            'tag',
            '-d',
            '1.0.0',
          ], workingDirectory: local.path);

          final removed = await removeVersionTag.get(
            directory: local,
            ggLog: ggLog,
          );

          expect(removed, isTrue);
          expect(await remoteTags(local), isEmpty);
          expect(messages, contains('Removed the remote tag 1.0.0.'));
          expect(messages, isNot(contains('Removed the local tag 1.0.0.')));
        });

        test('when the repo has no remote', () async {
          final d = await initTestDir();
          await initGit(d);
          await addAndCommitSampleFile(d);
          writePubspec(d, '1.0.0');
          await addTag(d, '1.0.0');

          final removed = await removeVersionTag.get(
            directory: d,
            ggLog: ggLog,
          );

          expect(removed, isTrue);
          expect(await localTags(d), isEmpty);

          await d.delete(recursive: true);
        });

        test('read from package.json for a bridge project', () async {
          // A bridge (pubspec.yaml + package.json + tsconfig.json) is
          // published as TypeScript, i.e. package.json holds the version.
          File(
            '${local.path}/package.json',
          ).writeAsStringSync('{"name": "ts", "version": "2.0.0"}');
          File('${local.path}/tsconfig.json').writeAsStringSync('{}');
          await addTags(local, ['1.0.0', '2.0.0']);

          final removed = await removeVersionTag.get(
            directory: local,
            ggLog: ggLog,
          );

          expect(removed, isTrue);
          expect(await localTags(local), ['1.0.0']);
        });
      });

      group('should do nothing', () {
        test('when no tag for the version exists', () async {
          await addTag(local, '0.9.0');
          await pushTags(local);

          final removed = await removeVersionTag.get(
            directory: local,
            ggLog: ggLog,
          );

          expect(removed, isFalse);
          expect(await localTags(local), ['0.9.0']);
          expect(await remoteTags(local), contains('refs/tags/0.9.0'));
          expect(messages, contains('No tag 1.0.0 to be removed.'));
        });

        test('when the project has no manifest', () async {
          File('${local.path}/pubspec.yaml').deleteSync();
          await addTag(local, '1.0.0');

          final removed = await removeVersionTag.get(
            directory: local,
            ggLog: ggLog,
          );

          expect(removed, isFalse);
          expect(await localTags(local), ['1.0.0']);
          expect(
            messages,
            contains(
              'No manifest - no version tag to be '
              'removed.',
            ),
          );
        });
      });

      group('should throw', () {
        late GgProcessWrapper processWrapper;
        late MockHasRemote hasRemote;
        late RemoveVersionTag command;

        setUp(() {
          processWrapper = MockGgProcessWrapper();
          hasRemote = MockHasRemote();
          command = RemoveVersionTag(
            ggLog: ggLog,
            processWrapper: processWrapper,
            hasRemote: hasRemote,
            catalog: catalog,
          );
        });

        // .....................................................................
        void mockGit(List<String> args, ProcessResult result) => when(
          () => processWrapper.run('git', args, workingDirectory: local.path),
        ).thenAnswer((_) async => result);

        test('when the local tags cannot be listed', () async {
          mockGit(['tag', '--list', '1.0.0'], ProcessResult(0, 1, '', 'Ooops'));

          await expectLater(
            () => command.get(directory: local, ggLog: ggLog),
            throwsA(
              isA<Exception>().having(
                (e) => rmC(e.toString()),
                'message',
                contains('Failed to list the tags.'),
              ),
            ),
          );
        });

        test('when the local tag cannot be removed', () async {
          mockGit([
            'tag',
            '--list',
            '1.0.0',
          ], ProcessResult(0, 0, '1.0.0\n', ''));
          mockGit(['tag', '-d', '1.0.0'], ProcessResult(0, 1, '', 'Ooops'));

          await expectLater(
            () => command.get(directory: local, ggLog: ggLog),
            throwsA(
              isA<Exception>().having(
                (e) => rmC(e.toString()),
                'message',
                contains('Failed to remove the local tag.'),
              ),
            ),
          );
        });

        test('when the remote tags cannot be listed', () async {
          mockGit(['tag', '--list', '1.0.0'], ProcessResult(0, 0, '', ''));
          hasRemote.mockGet(result: true, ggLog: ggLog);
          mockGit([
            'ls-remote',
            '--tags',
            'origin',
            'refs/tags/1.0.0',
          ], ProcessResult(0, 1, '', 'Ooops'));

          await expectLater(
            () => command.get(directory: local, ggLog: ggLog),
            throwsA(
              isA<Exception>().having(
                (e) => rmC(e.toString()),
                'message',
                contains('Failed to list the remote tags.'),
              ),
            ),
          );
        });

        test('when the remote tag cannot be removed', () async {
          mockGit(['tag', '--list', '1.0.0'], ProcessResult(0, 0, '', ''));
          hasRemote.mockGet(result: true, ggLog: ggLog);
          mockGit([
            'ls-remote',
            '--tags',
            'origin',
            'refs/tags/1.0.0',
          ], ProcessResult(0, 0, 'abc123\trefs/tags/1.0.0\n', ''));
          mockGit([
            'push',
            'origin',
            '--delete',
            'refs/tags/1.0.0',
          ], ProcessResult(0, 1, '', 'Ooops'));

          await expectLater(
            () => command.get(directory: local, ggLog: ggLog),
            throwsA(
              isA<Exception>().having(
                (e) => rmC(e.toString()),
                'message',
                contains('Failed to remove the remote tag.'),
              ),
            ),
          );
        });

        test('when the directory does not exist', () async {
          await expectLater(
            () => command.get(directory: Directory('xyz'), ggLog: ggLog),
            throwsA(isA<ArgumentError>()),
          );
        });
      });
    });

    // .........................................................................
    group('exec(directory, ggLog)', () {
      test('should remove the tag from the command line', () async {
        // No catalog injected: the bundled gg_lang catalog is used.
        final cliCommand = RemoveVersionTag(ggLog: ggLog);
        final runner = CommandRunner<dynamic>('ggPublish', 'Description')
          ..addCommand(cliCommand);

        await addTag(local, '1.0.0');
        await pushTags(local);

        await runner.run(['remove-version-tag', '--input', local.path]);

        expect(await localTags(local), isEmpty);
        expect(await remoteTags(local), isEmpty);
      });
    });

    test('has a code coverage of 100%', () {
      expect(RemoveVersionTag(ggLog: ggLog), isNotNull);
    });
  });
}

const _catalogJson = '''
{
  "schemaVersion": 1,
  "languages": {
    "dart": {
      "displayName": "Dart",
      "manifest": {
        "file": "pubspec.yaml",
        "format": "yaml",
        "versionPath": "version",
        "namePath": "name",
        "publishTargetMarker": "publish_to",
        "lockFile": "pubspec.lock"
      },
      "commands": {}
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
      "commands": {}
    }
  }
}
''';
