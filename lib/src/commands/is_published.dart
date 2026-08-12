// @license
// Copyright (c) ggsuite
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
/// Checks if a package was published to its registries before.
class IsPublished extends DirCommand<bool> {
  /// Constructor
  IsPublished({
    required super.ggLog,
    PublishedVersion? publishedVersion,
    PublishTo? publishTo,
  }) : _publishedVersion = publishedVersion ?? PublishedVersion(ggLog: ggLog),
       _publishTo = publishTo ?? PublishTo(ggLog: ggLog),
       super(
         name: 'is-published',
         description: 'Check if the package was published before',
       );

  // ...........................................................................
  @override
  Future<bool> exec({
    required Directory directory,
    required GgLog ggLog,
    Map<String, dynamic> options = const {},
  }) async {
    await check(directory: directory);
    final messages = <String>[];

    final printer = GgStatusPrinter<bool>(
      message: 'Was published before.',
      ggLog: ggLog,
      dark: true,
    );

    return await printer.logTask(
      task: () => get(ggLog: messages.add, directory: directory),
      success: (success) => success,
    );
  }

  // ...........................................................................
  /// Returns true if the package was published to one of its registries.
  ///
  /// The registries are asked one by one: [PublishedVersion.latestVersionFor]
  /// answers null exactly when the package is unknown there, which is the only
  /// reliable "never published" signal. Deriving it from the highest published
  /// version instead reported a package sitting at `0.0.0` — a legitimate
  /// version an npm-only hybrid starts its life with — as never published.
  @override
  Future<bool> get({required GgLog ggLog, required Directory directory}) async {
    final targets = await _publishTo.targets(directory);

    if (targets.isNotEmpty) {
      for (final target in targets) {
        final version = await _publishedVersion.latestVersionFor(
          target: target,
          ggLog: ggLog,
          directory: directory,
        );
        if (version != null) {
          return true;
        }
      }
      return false;
    }

    // No public registry: the git version tags are the only record of a
    // release, and PublishedVersion falls back to them.
    final version = await _publishedVersion.get(
      ggLog: ggLog,
      directory: directory,
    );

    return version != Version(0, 0, 0);
  }

  // ######################
  // Private
  // ######################

  final PublishedVersion _publishedVersion;
  final PublishTo _publishTo;
}

// .............................................................................
/// A Mock for the IsPublished class using Mocktail
class MockIsPublished extends MockDirCommand<bool> implements IsPublished {}
