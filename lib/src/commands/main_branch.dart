// @license
// Copyright (c) 2025 Göran Hegenberg. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_log/gg_log.dart';

/// Returns the name of the repository's main branch.
class MainBranch extends DirCommand<String> {
  /// Creates the command instance.
  MainBranch({required super.ggLog, ProcessRunner? processRunner})
    : _processRunner = processRunner ?? Process.run,
      super(
        name: 'main-branch',
        description:
            'Returns the name of the current main branch '
            '(main or master).',
      );

  final ProcessRunner _processRunner;

  @override
  Future<String> exec({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    final branchName = await get(directory: directory, ggLog: ggLog);
    ggLog(branchName);
    return branchName;
  }

  /// Returns the repository main branch name for [directory].
  @override
  Future<String> get({
    required GgLog ggLog,
    required Directory directory,
  }) async {
    await check(directory: directory);

    final branches = await _readLocalBranches(directory: directory);

    if (branches.contains('main')) {
      return 'main';
    }

    if (branches.contains('master')) {
      return 'master';
    }

    throw ArgumentError(
      'Could not determine the main branch. '
      'Expected "main" or "master".',
    );
  }

  /// Reads all local branch names from the git repository.
  Future<Set<String>> _readLocalBranches({required Directory directory}) async {
    final result = await _processRunner(
      'git',
      ['branch', '--format=%(refname:short)'],
      workingDirectory: directory.path,
      runInShell: true,
    );

    if (result.exitCode != 0) {
      throw Exception('Failed to read git branches: ${result.stderr}'.trim());
    }

    final stdoutContent = result.stdout.toString();

    return stdoutContent
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toSet();
  }
}

/// Signature for running a process.
typedef ProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      bool runInShell,
    });

/// Mock implementation of [MainBranch].
class MockMainBranch extends MockDirCommand<String> implements MainBranch {}
