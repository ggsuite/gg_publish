// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:test/test.dart';
import 'package:gg_git/gg_git.dart' as gg_git;
import 'package:gg_console_colors/gg_console_colors.dart';

void main() {
  late Directory d;
  late IsMainBranch isMainBranchCommand;
  late CommandRunner<dynamic> runner;
  final messages = <String>[];
  // Strip the colors and the overwrite sequence so the expectations assert
  // the text. One closure instance — mocktail matches ggLog by identity.
  // ignore: prefer_function_declarations_over_variables
  final GgLog ggLog = (String msg) => messages.add(rmControls(msg));

  setUp(() async {
    messages.clear();
    d = await initTestDir();
    await initGit(d);

    isMainBranchCommand = IsMainBranch(ggLog: ggLog);

    runner = CommandRunner<dynamic>('test', 'test')
      ..addCommand(isMainBranchCommand);

    registerFallbackValue(d);
  });

  tearDown(() async {
    await d.delete(recursive: true);
  });

  group('IsMainBranch', () {
    group('constructor', () {
      test('should create wrapped gg_git command by default', () {
        expect(() => IsMainBranch(ggLog: ggLog), returnsNormally);
      });
    });

    group('get(directory, ggLog)', () {
      test('should return false for a real feature branch', () async {
        await createBranch(d, 'feature/test-branch');

        final result = await isMainBranchCommand.get(
          directory: d,
          ggLog: ggLog,
        );

        expect(result, isFalse);
      });

      test('should return true for a real non-feature branch', () async {
        final result = await isMainBranchCommand.get(
          directory: d,
          ggLog: ggLog,
        );

        expect(result, isTrue);
      });

      test('should use injected gg_git.IsFeatureBranch', () async {
        final mock = MockGgGitIsFeatureBranch();
        when(
          () => mock.get(
            ggLog: any(named: 'ggLog'),
            directory: any(named: 'directory'),
          ),
        ).thenAnswer((_) async => false);

        final command = IsMainBranch(ggLog: ggLog, isFeatureBranch: mock);

        final result = await command.get(directory: d, ggLog: ggLog);

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
      test('should print when branch is the main branch', () async {
        final result = await isMainBranchCommand.exec(
          directory: d,
          ggLog: ggLog,
        );

        expect(result, isTrue);
        expect(messages.first, contains('⌛️ Current branch is main branch'));
        expect(messages.last, contains('✓ Current branch is main branch'));
      });

      test(
        'should print ✗ and throw when branch is not the main branch',
        () async {
          await createBranch(d, 'feature/test-branch');
          late String exceptionMessage;

          try {
            await isMainBranchCommand.exec(directory: d, ggLog: ggLog);
          } catch (e) {
            exceptionMessage = rmC(e.toString());
          }

          expect(messages.first, contains('⌛️ Current branch is main branch'));
          expect(messages.last, contains('✗ Current branch is main branch'));
          expect(exceptionMessage, isNotEmpty);
          expect(
            exceptionMessage,
            contains('Current branch is not the main branch'),
          );
        },
      );
    });

    group('run()', () {
      test('should allow to run command from CLI', () async {
        await runner.run(['is-main-branch', '--input', d.path]);

        expect(messages.last, contains('✓ Current branch is main branch'));
      });

      test(
        'should call exec() when run from CLI and fail for feature branch',
        () async {
          await createBranch(d, 'feature/test-branch');

          await expectLater(
            runner.run(['is-main-branch', '--input', d.path]),
            throwsA(isA<Exception>()),
          );

          expect(messages.first, contains('⌛️ Current branch is main branch'));
          expect(messages.last, contains('✗ Current branch is main branch'));
        },
      );
    });
  });
}

class MockGgGitIsFeatureBranch extends Mock implements gg_git.IsFeatureBranch {}
