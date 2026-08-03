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

// #############################################################################
/// Checks if at least one version of the package is available on its
/// registry (pub.dev for Dart/Flutter, npm for TypeScript).
class IsInRegistry extends DirCommand<bool> {
  /// Constructor
  IsInRegistry({required super.ggLog, PublishedVersion? publishedVersion})
    : _publishedVersion = publishedVersion ?? PublishedVersion(ggLog: ggLog),
      super(
        name: 'is-in-registry',
        description: 'Check if the package is on its registry',
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
      message: 'Is available on the registry.',
      ggLog: ggLog,
    );

    return await printer.logTask(
      task: () => get(ggLog: messages.add, directory: directory),
      success: (success) => success,
    );
  }

  // ...........................................................................
  /// Returns true when at least one version of the package is available on
  /// its registry. Packages without a public registry (`publish_to: none`,
  /// `private: true` or no manifest at all) return false.
  @override
  Future<bool> get({required GgLog ggLog, required Directory directory}) async {
    final result = await inRegistry(ggLog: ggLog, directory: directory);
    return result ?? false;
  }

  // ...........................................................................
  /// Returns true when at least one version of the package is available on
  /// its registry, false when the package was never published there, and
  /// null when the package has no public registry (`publish_to: none`,
  /// `private: true` or no manifest at all).
  Future<bool?> inRegistry({
    required GgLog ggLog,
    required Directory directory,
  }) async {
    final versions = await _publishedVersion.registryVersions(
      directory: directory,
    );
    return versions?.isNotEmpty;
  }

  // ######################
  // Private
  // ######################

  final PublishedVersion _publishedVersion;
}

// .............................................................................
/// A Mock for the IsInRegistry class using Mocktail
class MockIsInRegistry extends MockDirCommand<bool> implements IsInRegistry {}
