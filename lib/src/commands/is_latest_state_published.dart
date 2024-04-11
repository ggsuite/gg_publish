// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:gg_version/gg_version.dart';

// #############################################################################
/// Checks if the latest state is published
class IsLatestStatePublished extends DirCommand<bool> {
  /// Constructor
  IsLatestStatePublished({
    required super.ggLog,
    PublishedVersion? publishedVersion,
    ConsistentVersion? consistentVersion,
  })  : _publishedVersion = publishedVersion ??
            PublishedVersion(
              ggLog: ggLog,
            ),
        _consistentVersion = consistentVersion ??
            ConsistentVersion(
              ggLog: ggLog,
            ),
        super(
          name: 'is-latest-state-published',
          description: 'Checks if the latest state is published.',
        );

  // ...........................................................................
  @override
  Future<bool> exec({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    final messages = <String>[];

    final printer = GgStatusPrinter<bool>(
      message: 'Latest state is on pub.dev.',
      ggLog: ggLog,
    );

    return await printer.logTask(
      task: () => get(ggLog: messages.add, directory: directory),
      success: (success) => success,
    );
  }

  // ...........................................................................
  /// Returns true if the current directory state is published to pub.dev
  @override
  Future<bool> get({
    required GgLog ggLog,
    required Directory directory,
  }) async {
    // Check if the repo has a consistent version
    final localVersion = await _consistentVersion.get(
      ggLog: ggLog,
      directory: directory,
    );

    // Get the latest version from pub.dev
    final publishedVersion = await _publishedVersion.get(
      ggLog: ggLog,
      directory: directory,
    );

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

// .............................................................................
/// A Mock for the IsLatestStatePublished class using Mocktail
class MockIsLatestStatePublished extends MockDirCommand<bool>
    implements IsLatestStatePublished {}
