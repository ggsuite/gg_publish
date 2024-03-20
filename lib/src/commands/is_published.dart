// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_args/gg_args.dart';
import 'package:gg_publish/src/commands/published_version.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:gg_version/gg_version.dart';

// #############################################################################
/// Base class for all ggGit commands
class IsPublished extends GgDirCommand {
  /// Constructor
  IsPublished({
    required super.log,
    PublishedVersion? publishedVersion,
    ConsistentVersion? consistentVersion,
    super.inputDir,
  })  : _publishedVersion = publishedVersion ??
            PublishedVersion(
              log: log,
              inputDir: inputDir,
            ),
        _consistentVersion = consistentVersion ??
            ConsistentVersion(
              log: log,
              inputDir: inputDir,
            );

  /// Then name of the command
  @override
  final name = 'is-published';

  /// The description of the command
  @override
  final description =
      'Checks if the current application state is fully published.';

  // ...........................................................................
  @override
  Future<void> run() async {
    await super.run();

    final messages = <String>[];

    final printer = GgStatusPrinter<bool>(
      message: 'Everything is published.',
      log: log,
    );

    await printer.logTask(
      task: () => get(log: messages.add),
      success: (success) => success,
    );
  }

  // ...........................................................................
  /// Returns true if the current directory state is published to pub.dev
  Future<bool> get({void Function(String)? log}) async {
    log ??= this.log; // coverage:ignore-line

    // Check if the repo has a consistent version
    _consistentVersion.inputDir = inputDir;
    final localVersion = await _consistentVersion.get(log: log);

    // Get the latest version from pub.dev
    _publishedVersion.inputDir = inputDir;
    final publishedVersion = await _publishedVersion.get(log: log);

    // Throw if latest version is bigger than the current version
    if (publishedVersion > localVersion) {
      throw Exception(
        'The local version "$localVersion" '
        'is behind published version $publishedVersion. '
        'Update and try again.',
      );
    }

    // Return true if the current version matches the published version
    return publishedVersion == localVersion;
  }

  // ######################
  // Private
  // ######################

  final PublishedVersion _publishedVersion;
  final ConsistentVersion _consistentVersion;
}
