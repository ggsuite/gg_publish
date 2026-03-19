// @license
// Copyright (c) 2025 Göran Hegenberg. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_git/gg_git.dart' as gg_git;
import 'package:gg_log/gg_log.dart';
import 'package:gg_status_printer/gg_status_printer.dart';

/// Checks if the current git branch is the main branch.
class IsMainBranch extends DirCommand<bool> {
  /// Constructor.
  IsMainBranch({required super.ggLog, gg_git.IsFeatureBranch? isFeatureBranch})
    : _isFeatureBranch =
          isFeatureBranch ?? gg_git.IsFeatureBranch(ggLog: ggLog),
      super(
        name: 'is-main-branch',
        description: 'Checks if the current git branch is the main branch.',
      );

  final gg_git.IsFeatureBranch _isFeatureBranch;

  @override
  Future<bool> exec({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    final printer = GgStatusPrinter<bool>(
      message: 'Current branch is main branch',
      ggLog: ggLog,
    );

    final isMainBranch = await printer.logTask(
      task: () => get(ggLog: ggLog, directory: directory),
      success: (success) => success,
    );

    if (!isMainBranch) {
      throw Exception('Current branch is not the main branch');
    }

    return isMainBranch;
  }

  /// Returns `true` if [directory] currently points to a main branch.
  @override
  Future<bool> get({required GgLog ggLog, required Directory directory}) async {
    final isFeatureBranch = await _isFeatureBranch.get(
      ggLog: ggLog,
      directory: directory,
    );
    return !isFeatureBranch;
  }
}

/// Mock implementation of [IsMainBranch].
class MockIsMainBranch extends MockDirCommand<bool> implements IsMainBranch {}
