// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_process/gg_process.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:gg_is_flutter/gg_is_flutter.dart';

// #############################################################################
/// Base class for all ggGit commands
class IsUpgraded extends DirCommand<void> {
  /// Constructor
  IsUpgraded({
    required super.ggLog,
    this.processWrapper = const GgProcessWrapper(),
  }) : super(
          name: 'is-upgraded',
          description:
              'Checks if all dependencies have upgraded to the latest state.',
        );

  // ...........................................................................
  @override
  Future<void> exec({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    final messages = <String>[];

    final printer = GgStatusPrinter<bool>(
      message: 'Everything is upgraded.',
      ggLog: ggLog,
    );

    await printer.logTask(
      task: () => get(ggLog: messages.add, directory: directory),
      success: (success) => success,
    );
  }

  // ...........................................................................
  /// Returns true if the current directory state is published to pub.dev
  Future<bool> get({
    required GgLog ggLog,
    required Directory directory,
  }) async {
    // Check if the 'flutter' command is available, assuming Flutter projects
    // include Flutter dependencies
    bool isFlutterProject = isFlutterDir(directory);

    // Execute the appropriate command based on the project type
    String command = isFlutterProject ? 'flutter' : 'dart';
    List<String> arguments =
        isFlutterProject ? ['pub', 'outdated'] : ['pub', 'outdated'];

    var result = await processWrapper.run(
      command,
      arguments,
      runInShell: true,
      workingDirectory: directory.path,
    );

    if (result.exitCode == 0) {
      final resultString = result.stdout.toString();
      if (resultString.contains('Found no outdated packages')) {
        return true;
      } else {
        ggLog(resultString);
        return false;
      }
    } else {
      throw Exception(
        'Error while checking for outdated packages: ${result.stderr}',
      );
    }
  }

  // ######################
  // Private
  // ######################

  /// The process wrapper used to run the 'pub outdated' command
  final GgProcessWrapper processWrapper;
}

// .............................................................................
/// A Mock for the IsUpgraded class using Mocktail
class MockIsUpgraded extends MockDirCommand implements IsUpgraded {}
