// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:convert';
import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_process/gg_process.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:gg_is_flutter/gg_is_flutter.dart';
import 'package:pub_semver/pub_semver.dart';

// #############################################################################
/// Base class for all ggGit commands
class IsUpgraded extends DirCommand<bool> {
  /// Constructor
  IsUpgraded({
    required super.ggLog,
    this.processWrapper = const GgProcessWrapper(),
  }) : super(
         name: 'is-upgraded',
         description:
             'Checks if all dependencies have upgraded to the latest state.',
       ) {
    _addArgs();
  }

  // ...........................................................................
  @override
  Future<bool> exec({
    required Directory directory,
    required GgLog ggLog,
    bool? majorVersions,
  }) async {
    final messages = <String>[];

    final printer = GgStatusPrinter<bool>(
      message: 'Everything is upgraded.',
      ggLog: ggLog,
    );

    return await printer.logTask(
      task: () => get(
        ggLog: messages.add,
        directory: directory,
        majorVersions: majorVersions,
      ),
      success: (success) => success,
    );
  }

  // ...........................................................................
  /// Returns true if the current directory state is published to pub.dev
  @override
  Future<bool> get({
    required GgLog ggLog,
    required Directory directory,
    bool? majorVersions,
  }) async {
    majorVersions ??= argResults?['major-versions'] as bool? ?? false;

    // Check if the 'flutter' command is available, assuming Flutter projects
    // include Flutter dependencies
    bool isFlutterProject = isFlutterDir(directory);

    // Execute the appropriate command based on the project type
    String command = isFlutterProject ? 'flutter' : 'dart';
    List<String> arguments = ['pub', 'outdated', '--json'];

    var result = await processWrapper.run(
      command,
      arguments,
      runInShell: true,
      workingDirectory: directory.path,
    );

    if (result.exitCode == 0) {
      return _evalResponse(result.stdout.toString(), majorVersions);
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

  // ...........................................................................
  bool _evalResponse(String response, bool majorVersions) {
    try {
      final parsedResponse = json.decode(response) as Map<String, dynamic>;
      final packages = parsedResponse['packages'] as List;
      if (packages.isEmpty) {
        return true;
      }

      for (final p in packages) {
        final package = p as Map<String, dynamic>;

        // Skip indirect dependencies
        if (package['kind'] != 'direct') {
          continue;
        }

        // Is there a resolvable version available?
        final current = Version.parse(package['current']['version'] as String);

        final resolvable = Version.parse(
          package['resolvable']['version'] as String,
        );

        final upgradable = Version.parse(
          package['upgradable']['version'] as String,
        );

        final targetVersion = majorVersions ? resolvable : upgradable;

        if (current < targetVersion) {
          return false;
        }
      }

      return true;
    } catch (e) {
      throw Exception('Error while parsing the response: $e');
    }
  }

  // ...........................................................................
  void _addArgs() {
    argParser.addFlag(
      'major-versions',
      abbr: 'm',
      help: 'If true, also major version upgrades are considered.',
      negatable: true,
      defaultsTo: false,
    );
  }
}

// .............................................................................
/// A Mock for the IsUpgraded class using Mocktail
class MockIsUpgraded extends MockDirCommand<bool> implements IsUpgraded {}
