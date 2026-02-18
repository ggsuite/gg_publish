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

// #############################################################################
/// Checks if the current git branch is a feature branch.
class IsFeatureBranch extends DirCommand<bool> {
  /// Constructor
  IsFeatureBranch({
    required super.ggLog,
    gg_git.IsFeatureBranch? isFeatureBranch,
  }) : _isFeatureBranch =
           isFeatureBranch ?? gg_git.IsFeatureBranch(ggLog: ggLog),
       super(
         name: 'is-feature-branch',
         description: 'Checks if the current git branch is a feature branch.',
       );

  /// The wrapped implementation from the `gg_git` package.
  final gg_git.IsFeatureBranch _isFeatureBranch;

  // ...........................................................................
  /// Executes the command and logs the result using [GgStatusPrinter].
  ///
  /// Throws an [Exception] when the current branch is not a feature branch.
  @override
  Future<bool> exec({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    final messages = <String>[];

    final printer = GgStatusPrinter<bool>(
      message: 'Current branch is feature branch',
      ggLog: ggLog,
    );

    final isFeatureBranch = await printer.logTask(
      task: () => get(ggLog: messages.add, directory: directory),
      success: (success) => success,
    );

    if (!isFeatureBranch) {
      throw Exception(messages.join('\n'));
    }

    return isFeatureBranch;
  }

  // ...........................................................................
  /// Returns `true` if [directory] currently points to a git feature branch.
  @override
  Future<bool> get({required GgLog ggLog, required Directory directory}) async {
    return _isFeatureBranch.get(ggLog: ggLog, directory: directory);
  }
}
