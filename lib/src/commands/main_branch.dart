// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_git/gg_git.dart' as gg_git;
import 'package:gg_log/gg_log.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_process/gg_process.dart';

/// Returns the name of the repository's main branch.
class MainBranch extends DirCommand<String> {
  /// Creates the command instance.
  MainBranch({
    required super.ggLog,
    ProcessRunner? processRunner,
    gg_git.DefaultBranch? defaultBranch,
  }) : _processRunner = processRunner ?? ggRunProcess,
       _defaultBranch = defaultBranch ?? gg_git.DefaultBranch(ggLog: ggLog),
       super(
         name: 'main-branch',
         description: 'Return the name of the main branch',
       );

  final ProcessRunner _processRunner;

  /// Resolves the default branch the remote declares (`origin/HEAD`).
  final gg_git.DefaultBranch _defaultBranch;

  @override
  Future<String> exec({
    required Directory directory,
    required GgLog ggLog,
    Map<String, dynamic> options = const {},
  }) async {
    final branchName = await get(directory: directory, ggLog: ggLog);
    ggLog(branchName);
    return branchName;
  }

  /// Returns the repository main branch name for [directory].
  ///
  /// The branch the remote declares as its default (`origin/HEAD`) wins —
  /// a repository whose default branch is `develop` merges into and releases
  /// from `develop`. Only a repository that declares nothing is guessed:
  /// `main` when it exists locally, else `master`.
  @override
  Future<String> get({
    required GgLog ggLog,
    required Directory directory,
  }) async {
    await check(directory: directory);

    final declared = await _defaultBranch.declaredDefaultBranch(
      directory: directory,
    );
    if (declared != null) {
      return declared;
    }

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
      throw Exception(
        cDetail('Failed to read the git branches: ${result.stderr}'.trim()),
      );
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
typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  bool runInShell,
});

/// Mock implementation of [MainBranch].
class MockMainBranch extends MockDirCommand<String> implements MainBranch {}
