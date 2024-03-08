// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:args/command_runner.dart';

// #############################################################################
/// Base class for all ggGit commands
class MyCommand extends Command<dynamic> {
  /// Constructor
  MyCommand({
    required this.log,
  }) {
    _addArgs();
  }

  /// The log function
  final void Function(String message) log;

  /// Then name of the command
  @override
  final name = 'my-command';

  /// The description of the command
  @override
  final description = 'Description of my command.';

  // ...........................................................................
  @override
  Future<void> run() async {
    input = argResults!['input'] as String;
    log('Running $name with param $input');
  }

  // ...........................................................................
  void _addArgs() {
    argParser.addOption(
      'input',
      abbr: 'i',
      help: 'The subcommands input param.',
      mandatory: true,
    );
  }

  // ...........................................................................
  /// Replace by your parameter
  late String input;
}
