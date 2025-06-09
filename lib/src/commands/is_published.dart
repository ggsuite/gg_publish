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
import 'package:pub_semver/pub_semver.dart';

// #############################################################################
/// Checks if a package was published to pub.dev before.
class IsPublished extends DirCommand<bool> {
  /// Constructor
  IsPublished({required super.ggLog, PublishedVersion? publishedVersion})
    : _publishedVersion = publishedVersion ?? PublishedVersion(ggLog: ggLog),
      super(
        name: 'is-published',
        description:
            'Checks if the current directory has been published to '
            'pub.dev before.',
      );

  // ...........................................................................
  @override
  Future<bool> exec({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    await check(directory: directory);
    final messages = <String>[];

    final printer = GgStatusPrinter<bool>(
      message: 'Was published to pub.dev before.',
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
  Future<bool> get({required GgLog ggLog, required Directory directory}) async {
    // Get the latest version from pub.dev
    final version = await _publishedVersion.get(
      ggLog: ggLog,
      directory: directory,
    );

    if (version == Version(0, 0, 0)) {
      return false;
    }

    return true;
  }

  // ######################
  // Private
  // ######################

  final PublishedVersion _publishedVersion;
}

// .............................................................................
/// A Mock for the IsPublished class using Mocktail
class MockIsPublished extends MockDirCommand<bool> implements IsPublished {}
