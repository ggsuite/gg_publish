// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_lang/gg_lang.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:gg_status_printer/gg_status_printer.dart';

// #############################################################################
/// Checks if at least one version of the package is available on every
/// registry it publishes to (pub.dev for the `pubspec.yaml` side, npm for the
/// `package.json` side — a hybrid has both).
class IsInRegistry extends DirCommand<bool> {
  /// Constructor
  IsInRegistry({
    required super.ggLog,
    PublishedVersion? publishedVersion,
    PublishTo? publishTo,
  }) : _publishedVersion = publishedVersion ?? PublishedVersion(ggLog: ggLog),
       _publishTo = publishTo ?? PublishTo(ggLog: ggLog),
       super(
         name: 'is-in-registry',
         description: 'Check if the package is on its registry',
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
      message: 'Is available on the registry.',
      ggLog: ggLog,
      dark: true,
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
  /// **every** registry it publishes to, false when at least one of them has
  /// never seen it, and null when the package has no public registry
  /// (`publish_to: none`, `private: true` or no manifest at all).
  ///
  /// "Every" matters for a hybrid: one that is on npm but has never been
  /// released to pub.dev must not sail past the first-publish gate and then
  /// fail inside `dart pub publish`.
  Future<bool?> inRegistry({
    required GgLog ggLog,
    required Directory directory,
  }) async {
    final missing = await missingTargets(directory: directory);
    if (missing == null) return null;
    return missing.isEmpty;
  }

  // ...........................................................................
  /// Returns the registries the package publishes to but has never been
  /// released on, or null when it has no public registry at all.
  ///
  /// The publish flow asks the user to perform exactly these first publishes
  /// manually — authentication, access rights and the package creation are
  /// settled with the registry interactively.
  Future<Set<PublishTarget>?> missingTargets({
    required Directory directory,
  }) async {
    final targets = await _publishTo.targets(directory);
    if (targets.isEmpty) return null;

    final missing = <PublishTarget>{};
    for (final target in targets.ordered) {
      final versions = await _publishedVersion.registryVersionsFor(
        target: target,
        directory: directory,
      );
      if (versions == null || versions.isEmpty) {
        missing.add(target);
      }
    }
    return missing;
  }

  // ######################
  // Private
  // ######################

  final PublishedVersion _publishedVersion;
  final PublishTo _publishTo;
}

// .............................................................................
/// A Mock for the IsInRegistry class using Mocktail
class MockIsInRegistry extends MockDirCommand<bool> implements IsInRegistry {}
