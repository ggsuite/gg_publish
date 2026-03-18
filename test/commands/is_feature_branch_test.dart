// @license
// Copyright (c) 2025 Göran Hegenberg. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:gg_git/gg_git.dart' as gg_git;

void main() {
  late Directory d;
  late IsFeatureBranch isFeatureBranchCommand;
  late CommandRunner<dynamic> runner;
  final messages = <String>[];

  setUp(() async {
    messages.clear();
    d = await initTestDir();
    await initGit(d);

    isFeatureBranchCommand = IsFeatureBranch(ggLog: messages.add);

    runner = CommandRunner<dynamic>('test', 'test')
      ..addCommand(isFeatureBranchCommand);

    registerFallbackValue(d);
  });

  tearDown(() async {
    await d.delete(recursive: true);
  });

  group('IsFeatureBranch', () {
    group('constructor', () {
      test('should create wrapped gg_git command by default', () {
        expect(() => IsFeatureBranch(ggLog: messages.add), returnsNormally);
      });
    });

    group('get(directory, ggLog)', () {
      test('should return true for a real feature branch', () async {
        await createBranch(d, 'feature/test-branch');

        final result = await isFeatureBranchCommand.get(
          directory: d,
          ggLog: messages.add,
        );

        expect(result, isTrue);
      });

      test('should return false for a real non-feature branch', () async {
        final result = await isFeatureBranchCommand.get(
          directory: d,
          ggLog: messages.add,
        );

        expect(result, isFalse);
      });

      test('should use injected gg_git.IsFeatureBranch', () async {
        final mock = MockGgGitIsFeatureBranch();
        when(
          () => mock.get(
            ggLog: any(named: 'ggLog'),
            directory: any(named: 'directory'),
          ),
        ).thenAnswer((_) async => true);

        final command = IsFeatureBranch(
          ggLog: messages.add,
          isFeatureBranch: mock,
        );

        final result = await command.get(directory: d, ggLog: messages.add);

        expect(result, isTrue);
        verify(
          () => mock.get(
            ggLog: any(named: 'ggLog'),
            directory: d,
          ),
        ).called(1);
      });
    });

    group('exec(directory, ggLog)', () {
      test('should print when branch is a feature branch', () async {
        await createBranch(d, 'feature/test-branch');

        final result = await isFeatureBranchCommand.exec(
          directory: d,
          ggLog: messages.add,
        );

        expect(result, isTrue);
        expect(messages.first, contains('⌛️ Current branch is feature branch'));
        expect(messages.last, contains('✅ Current branch is feature branch'));
      });

      test(
        'should print ❌ and throw when branch is not a feature branch',
        () async {
          late String exceptionMessage;

          try {
            await isFeatureBranchCommand.exec(
              directory: d,
              ggLog: messages.add,
            );
          } catch (e) {
            exceptionMessage = e.toString();
          }

          expect(
            messages.first,
            contains('⌛️ Current branch is feature branch'),
          );
          expect(messages.last, contains('❌ Current branch is feature branch'));
          print(exceptionMessage);
          expect(exceptionMessage, isNotEmpty);
          expect(
            exceptionMessage,
            contains('Current branch is not a feature branch'),
          );
        },
      );
    });

    group('run()', () {
      test('should allow to run command from CLI', () async {
        await createBranch(d, 'feature/test-branch');

        await runner.run(['is-feature-branch', '--input', d.path]);

        expect(messages.last, contains('✅ Current branch is feature branch'));
      });

      test(
        'should call exec() when run from CLI and fail for non-feature branch',
        () async {
          await expectLater(
            runner.run(['is-feature-branch', '--input', d.path]),
            throwsA(isA<Exception>()),
          );

          expect(
            messages.first,
            contains('⌛️ Current branch is feature branch'),
          );
          expect(messages.last, contains('❌ Current branch is feature branch'));
        },
      );
    });
  });
}

class MockGgGitIsFeatureBranch extends Mock implements gg_git.IsFeatureBranch {}
