// @license
// Copyright (c) 2025 Göran Hegenberg. All Rights Reserved.
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
  late MainBranch mainBranch;
  late CommandRunner<dynamic> runner;
  final messages = <String>[];

  setUp(() async {
    messages.clear();
    d = await initTestDir();
    await initGit(d);
    mainBranch = MainBranch(ggLog: messages.add);
    runner = CommandRunner<dynamic>('test', 'test')..addCommand(mainBranch);
  });

  tearDown(() async {
    await d.delete(recursive: true);
  });

  group('MainBranch', () {
    group('get(directory, ggLog)', () {
      test('should return main when repository uses main', () async {
        final result = await mainBranch.get(directory: d, ggLog: messages.add);

        expect(result, 'main');
      });

      test('should return master when repository uses master', () async {
        await Process.run(
          'git',
          ['branch', '-m', 'master'],
          workingDirectory: d.path,
          runInShell: true,
        );

        final result = await mainBranch.get(directory: d, ggLog: messages.add);

        expect(result, 'master');
      });

      test(
        'should return main while user is currently on a feature branch',
        () async {
          await createBranch(d, 'feature/test-branch');

          final result = await mainBranch.get(
            directory: d,
            ggLog: messages.add,
          );

          expect(result, 'main');
        },
      );

      test('should throw when neither main nor master exists', () async {
        await Process.run(
          'git',
          ['branch', '-m', 'development'],
          workingDirectory: d.path,
          runInShell: true,
        );

        await expectLater(
          () => mainBranch.get(directory: d, ggLog: messages.add),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              'Could not determine the main branch. '
                  'Expected "main" or "master".',
            ),
          ),
        );
      });

      test('should throw when reading git branches fails', () async {
        final command = MainBranch(
          ggLog: messages.add,
          processRunner:
              (
                String executable,
                List<String> arguments, {
                String? workingDirectory,
                bool runInShell = false,
              }) async {
                return ProcessResult(1, 1, '', 'git failed');
              },
        );

        await expectLater(
          () => command.get(directory: d, ggLog: messages.add),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to read git branches: git failed'),
            ),
          ),
        );
      });
    });

    group('exec(directory, ggLog)', () {
      test('should log the main branch name', () async {
        final result = await mainBranch.exec(directory: d, ggLog: messages.add);

        expect(result, 'main');
        expect(messages.last, 'main');
      });
    });

    group('run()', () {
      test('should allow to run command from CLI', () async {
        await runner.run(['main-branch', '--input', d.path]);

        expect(messages.last, 'main');
      });
    });
  });
}
