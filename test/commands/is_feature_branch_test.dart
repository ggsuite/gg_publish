// @license
// Copyright (c) 2025 Göran Hegenberg. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git.dart' as gg_git;
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

/// Mock for gg_git.IsFeatureBranch
class MockGgGitIsFeatureBranch extends Mock implements gg_git.IsFeatureBranch {}

void main() {
  late Directory d;
  late IsFeatureBranch isFeatureBranchCommand;
  late gg_git.IsFeatureBranch ggGitIsFeatureBranch;
  late CommandRunner<dynamic> runner;
  final messages = <String>[];

  setUp(() async {
    messages.clear();
    d = await initTestDir();
    await initGit(d);

    ggGitIsFeatureBranch = MockGgGitIsFeatureBranch();
    isFeatureBranchCommand = IsFeatureBranch(
      ggLog: messages.add,
      isFeatureBranch: ggGitIsFeatureBranch,
    );

    runner = CommandRunner<dynamic>('test', 'test')
      ..addCommand(isFeatureBranchCommand);

    registerFallbackValue(d);
  });

  tearDown(() async {
    await d.delete(recursive: true);
  });

  group('IsFeatureBranch', () {
    group('get(directory, ggLog)', () {
      test('should delegate to gg_git.IsFeatureBranch', () async {
        when(
          () => ggGitIsFeatureBranch.get(
            ggLog: any(named: 'ggLog'),
            directory: any(named: 'directory'),
          ),
        ).thenAnswer((_) async => true);

        final result = await isFeatureBranchCommand.get(
          directory: d,
          ggLog: messages.add,
        );

        expect(result, isTrue);

        verify(
          () => ggGitIsFeatureBranch.get(
            ggLog: any(named: 'ggLog'),
            directory: any(named: 'directory'),
          ),
        ).called(1);
      });
    });

    group('exec(directory, ggLog)', () {
      test('should print when branch is a feature branch', () async {
        when(
          () => ggGitIsFeatureBranch.get(
            ggLog: any(named: 'ggLog'),
            directory: any(named: 'directory'),
          ),
        ).thenAnswer((_) async => true);

        final result = await isFeatureBranchCommand.exec(
          directory: d,
          ggLog: messages.add,
        );

        expect(result, isTrue);
        expect(
          messages.first,
          contains('⌛️ Current branch is a feature branch.'),
        );
        expect(
          messages.last,
          contains('✅ Current branch is a feature branch.'),
        );
      });

      test(
        'should print ❌ and throw when branch is not a feature branch',
        () async {
          when(
            () => ggGitIsFeatureBranch.get(
              ggLog: any(named: 'ggLog'),
              directory: any(named: 'directory'),
            ),
          ).thenAnswer((_) async => false);

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
            contains('⌛️ Current branch is a feature branch.'),
          );
          expect(
            messages.last,
            contains('❌ Current branch is a feature branch.'),
          );
          expect(exceptionMessage, isNotEmpty);
        },
      );
    });

    group('run()', () {
      test('should allow to run command from CLI', () async {
        when(
          () => ggGitIsFeatureBranch.get(
            ggLog: any(named: 'ggLog'),
            directory: any(named: 'directory'),
          ),
        ).thenAnswer((_) async => true);

        await runner.run(['is-feature-branch', '--input', d.path]);

        expect(
          messages.last,
          contains('✅ Current branch is a feature branch.'),
        );
      });
    });

    test('should have a code coverage of 100%', () {
      expect(IsFeatureBranch(ggLog: messages.add), isNotNull);
    });
  });
}
