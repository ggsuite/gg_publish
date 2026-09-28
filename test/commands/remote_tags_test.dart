// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_process/gg_process.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../test_helpers.dart';

import 'package:gg_console_colors/gg_console_colors.dart';

void main() {
  final messages = <String>[];
  final ggLog = messages.add;
  late Directory local;
  late Directory remote;
  late RemoteTags remoteTags;

  // ...........................................................................
  Future<void> run(Directory d, List<String> args) async {
    final result = await Process.run('git', args, workingDirectory: d.path);
    expect(result.exitCode, 0, reason: '${result.stderr}');
  }

  // ...........................................................................
  setUp(() async {
    messages.clear();
    (local, remote) = await initLocalAndRemoteGit();
    remoteTags = RemoteTags(ggLog: ggLog);
    registerFallbackValue(local);
  });

  // ...........................................................................
  tearDown(() async {
    await local.delete(recursive: true);
    await remote.delete(recursive: true);
  });

  // ...........................................................................
  group('RemoteTags', () {
    group('get(directory, ggLog)', () {
      test('should return the tags on origin', () async {
        await addTag(local, '1.0.0');
        await run(local, ['tag', '-a', '1.1.0', '-m', 'Version 1.1.0']);
        await pushTags(local);

        // A local-only tag is not on origin.
        await addTag(local, '2.0.0');

        // An annotated tag is listed once, not with its »^{}« line.
        expect(await remoteTags.get(directory: local, ggLog: ggLog), {
          '1.0.0',
          '1.1.0',
        });
      });

      test('should return nothing without tags on origin', () async {
        expect(await remoteTags.get(directory: local, ggLog: ggLog), isEmpty);
      });

      test('should return nothing when the repo has no remote', () async {
        final d = await initTestDir();
        await initGit(d);
        await addAndCommitSampleFile(d);
        await addTag(d, '1.0.0');

        expect(await remoteTags.get(directory: d, ggLog: ggLog), isEmpty);

        await d.delete(recursive: true);
      });

      test('should return nothing outside of a git repo', () async {
        final d = await initTestDir();
        expect(await remoteTags.get(directory: d, ggLog: ggLog), isEmpty);
        await d.delete(recursive: true);
      });

      test('should throw when the remote tags cannot be listed', () async {
        final processWrapper = MockGgProcessWrapper();
        final hasRemote = MockHasRemote();
        hasRemote.mockGet(result: true, ggLog: ggLog);
        when(
          () => processWrapper.run('git', [
            'ls-remote',
            '--tags',
            'origin',
          ], workingDirectory: local.path),
        ).thenAnswer((_) async => ProcessResult(0, 128, '', 'Ooops'));

        final command = RemoteTags(
          ggLog: ggLog,
          processWrapper: processWrapper,
          hasRemote: hasRemote,
        );

        await expectLater(
          () => command.get(directory: local, ggLog: ggLog),
          throwsA(
            isA<Exception>().having(
              (e) => rmC(e.toString()),
              'message',
              allOf(
                contains('Failed to list the remote tags.'),
                // The reason survives a caller that silences the log.
                contains('Ooops'),
              ),
            ),
          ),
        );
      });
    });

    group('highestVersion(directory, ggLog)', () {
      test('should return the highest version tag on origin', () async {
        await addTags(local, ['0.9.0', '1.10.0', '1.9.0', 'v9.9.9', 'x']);
        await pushTags(local);

        expect(
          await remoteTags.highestVersion(directory: local, ggLog: ggLog),
          Version(1, 10, 0),
        );
      });

      test('should return null without version tags', () async {
        await addTag(local, 'release');
        await pushTags(local);

        expect(
          await remoteTags.highestVersion(directory: local, ggLog: ggLog),
          isNull,
        );
      });
    });

    group('baseline(directory, ggLog, publishedVersion)', () {
      Future<Version> baseline(String published) => remoteTags.baseline(
        directory: local,
        ggLog: ggLog,
        publishedVersion: Version.parse(published),
      );

      test('should return a higher tag than the published version', () async {
        await addTag(local, '0.0.146');
        await pushTags(local);

        expect(await baseline('0.0.145'), Version(0, 0, 146));
        expect(
          messages.map(rmC),
          contains(
            'Origin has the tag 0.0.146, but 0.0.145 is the latest published '
            'version. Counting on from 0.0.146.',
          ),
        );
      });

      test('should keep the published version otherwise', () async {
        await addTag(local, '0.0.145');
        await pushTags(local);

        expect(await baseline('0.0.145'), Version(0, 0, 145));
        expect(await baseline('1.0.0'), Version(1, 0, 0));
        expect(messages, isEmpty);
      });
    });

    group('exec(directory, ggLog)', () {
      test('should print the tags on origin', () async {
        await addTag(local, '1.0.0');
        await pushTags(local);

        final runner = CommandRunner<void>('test', 'test')
          ..addCommand(RemoteTags(ggLog: ggLog));
        await runner.run(['remote-tags', '-i', local.path]);

        expect(messages, ['1.0.0']);
      });
    });
  });
}
