// @license
// Copyright (c) 2025 Göran Hegenberg. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_process/gg_process.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

void main() {
  late Directory d;
  late MockGgProcessWrapper processWrapper;
  late MockMainBranch mainBranch;
  late MergeMainIntoFeat command;
  final messages = <String>[];

  void initCommand() {
    command = MergeMainIntoFeat(
      ggLog: messages.add,
      mainBranch: mainBranch,
      processWrapper: processWrapper,
    );
  }

  setUp(() async {
    messages.clear();
    d = await initTestDir();
    await initGit(d);
    registerFallbackValue(d);
    processWrapper = MockGgProcessWrapper();
    mainBranch = MockMainBranch();
    initCommand();
  });

  tearDown(() async {
    await d.delete(recursive: true);
  });

  group('MergeMainIntoFeat', () {
    group('constructor', () {
      test('should create default dependencies', () {
        expect(() => MergeMainIntoFeat(ggLog: messages.add), returnsNormally);
      });
    });

    group('get(directory, ggLog)', () {
      test('should fetch origin and merge origin/main', () async {
        when(
          () => processWrapper.run(
            'git',
            ['fetch', 'origin'],
            runInShell: true,
            workingDirectory: d.path,
          ),
        ).thenAnswer((_) async => ProcessResult(0, 0, '', ''));

        when(
          () => mainBranch.get(
            directory: d,
            ggLog: any(named: 'ggLog'),
          ),
        ).thenAnswer((_) async => 'main');

        when(
          () => processWrapper.run(
            'git',
            ['merge', 'origin/main'],
            runInShell: true,
            workingDirectory: d.path,
          ),
        ).thenAnswer((_) async => ProcessResult(0, 0, '', ''));

        await command.get(directory: d, ggLog: messages.add);

        verify(
          () => processWrapper.run(
            'git',
            ['fetch', 'origin'],
            runInShell: true,
            workingDirectory: d.path,
          ),
        ).called(1);

        verify(
          () => mainBranch.get(
            directory: d,
            ggLog: any(named: 'ggLog'),
          ),
        ).called(1);

        verify(
          () => processWrapper.run(
            'git',
            ['merge', 'origin/main'],
            runInShell: true,
            workingDirectory: d.path,
          ),
        ).called(1);
      });

      test('should merge origin/master when main branch is master', () async {
        when(
          () => processWrapper.run(
            'git',
            ['fetch', 'origin'],
            runInShell: true,
            workingDirectory: d.path,
          ),
        ).thenAnswer((_) async => ProcessResult(0, 0, '', ''));

        when(
          () => mainBranch.get(
            directory: d,
            ggLog: any(named: 'ggLog'),
          ),
        ).thenAnswer((_) async => 'master');

        when(
          () => processWrapper.run(
            'git',
            ['merge', 'origin/master'],
            runInShell: true,
            workingDirectory: d.path,
          ),
        ).thenAnswer((_) async => ProcessResult(0, 0, '', ''));

        await command.get(directory: d, ggLog: messages.add);

        verify(
          () => processWrapper.run(
            'git',
            ['merge', 'origin/master'],
            runInShell: true,
            workingDirectory: d.path,
          ),
        ).called(1);
      });

      test('should throw when git fetch fails', () async {
        when(
          () => processWrapper.run(
            'git',
            ['fetch', 'origin'],
            runInShell: true,
            workingDirectory: d.path,
          ),
        ).thenAnswer((_) async => ProcessResult(1, 1, '', 'fetch failed'));

        await expectLater(
          () => command.get(directory: d, ggLog: messages.add),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to fetch from origin: fetch failed'),
            ),
          ),
        );
      });

      test('should throw when git merge fails', () async {
        when(
          () => processWrapper.run(
            'git',
            ['fetch', 'origin'],
            runInShell: true,
            workingDirectory: d.path,
          ),
        ).thenAnswer((_) async => ProcessResult(0, 0, '', ''));

        when(
          () => mainBranch.get(
            directory: d,
            ggLog: any(named: 'ggLog'),
          ),
        ).thenAnswer((_) async => 'main');

        when(
          () => processWrapper.run(
            'git',
            ['merge', 'origin/main'],
            runInShell: true,
            workingDirectory: d.path,
          ),
        ).thenAnswer((_) async => ProcessResult(1, 1, '', 'merge conflict'));

        await expectLater(
          () => command.get(directory: d, ggLog: messages.add),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Failed to merge origin/main: merge conflict'),
            ),
          ),
        );
      });
    });

    group('exec(directory, ggLog)', () {
      test('should print success messages', () async {
        when(
          () => processWrapper.run(
            'git',
            ['fetch', 'origin'],
            runInShell: true,
            workingDirectory: d.path,
          ),
        ).thenAnswer((_) async => ProcessResult(0, 0, '', ''));

        when(
          () => mainBranch.get(
            directory: d,
            ggLog: any(named: 'ggLog'),
          ),
        ).thenAnswer((_) async => 'main');

        when(
          () => processWrapper.run(
            'git',
            ['merge', 'origin/main'],
            runInShell: true,
            workingDirectory: d.path,
          ),
        ).thenAnswer((_) async => ProcessResult(0, 0, '', ''));

        await command.exec(directory: d, ggLog: messages.add);

        expect(messages.first, contains('⌛️ Merge main into feature branch'));
        expect(messages.last, contains('✅ Merge main into feature branch'));
      });
    });
  });
}
