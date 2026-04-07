// @license
// Copyright (c) 2025 Göran Hegenberg. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_process/gg_process.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:gg_status_printer/gg_status_printer.dart';

/// Fetches origin and merges the remote main branch into the current branch.
class MergeMainIntoFeat extends DirCommand<void> {
  /// Creates the command instance.
  MergeMainIntoFeat({
    required super.ggLog,
    MainBranch? mainBranch,
    GgProcessWrapper processWrapper = const GgProcessWrapper(),
  }) : _mainBranch = mainBranch ?? MainBranch(ggLog: ggLog),
       _processWrapper = processWrapper,
       super(
         name: 'merge-main-into-feat',
         description:
             'Fetches origin and merges the remote '
             'main branch into the current branch.',
       );

  final MainBranch _mainBranch;
  final GgProcessWrapper _processWrapper;

  @override
  Future<void> exec({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    await GgStatusPrinter<void>(
      message: 'Merge main into feature branch',
      ggLog: ggLog,
    ).logTask(
      task: () => get(directory: directory, ggLog: ggLog),
      success: (_) => true,
    );
  }

  /// Fetches origin and merges the detected main branch into [directory].
  @override
  Future<void> get({required GgLog ggLog, required Directory directory}) async {
    await check(directory: directory);
    await _runGitCommand(
      directory: directory,
      arguments: const ['fetch', 'origin'],
      actionDescription: 'fetch from origin',
    );

    final mainBranchName = await _mainBranch.get(
      directory: directory,
      ggLog: <String>[].add,
    );

    await _runGitCommand(
      directory: directory,
      arguments: ['merge', 'origin/$mainBranchName'],
      actionDescription: 'merge origin/$mainBranchName',
    );
  }

  /// Runs a git command and throws when the command fails.
  Future<void> _runGitCommand({
    required Directory directory,
    required List<String> arguments,
    required String actionDescription,
  }) async {
    final result = await _processWrapper.run(
      'git',
      arguments,
      runInShell: true,
      workingDirectory: directory.path,
    );

    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      final stdout = result.stdout.toString().trim();
      final details = stderr.isNotEmpty ? stderr : stdout;
      throw Exception('Failed to $actionDescription: $details');
    }
  }
}

/// Mock implementation of [MergeMainIntoFeat].
class MockMergeMainIntoFeat extends MockDirCommand<void>
    implements MergeMainIntoFeat {}
