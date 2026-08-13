// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_lang/gg_lang.dart';
import 'package:gg_log/gg_log.dart';

/// Returns the registries a package publishes to.
///
/// The Dart side is described by `pubspec.yaml`'s `publish_to` field
/// (defaulting to pub.dev), the npm side by `package.json`'s `private` field. A
/// *hybrid* carries both manifests and can therefore have both targets — see
/// [targets], which is what every publishing decision uses.
class PublishTo extends DirCommand<void> {
  /// Constructor
  PublishTo({
    required super.ggLog,
    super.name = 'publish-to',
    super.description = 'Publishes the package to the given directory.',
    this._catalog,
  });

  /// The language catalog used to detect the manifest. Defaults to the bundled
  /// gg_lang catalog when null.
  final LanguageCatalog? _catalog;

  // ...........................................................................
  @override
  Future<void> get({required Directory directory, required GgLog ggLog}) async {
    final result = await fromDirectory(directory);
    ggLog(result);
  }

  // ...........................................................................
  /// Returns the registries the package in [directory] publishes to.
  ///
  /// An empty set means the package has no public registry and is released
  /// through git tags only.
  Future<Set<PublishTarget>> targets(Directory directory) async =>
      publishTargetsOf(
        directory,
        catalog: _catalog ?? await LanguageCatalog.load(),
      );

  // ...........................................................................
  /// Returns the publish target of the manifest in [directory] as a label:
  /// `none`, `pub.dev`, `npm` or `pub.dev+npm`.
  ///
  /// Kept for messages and for the CLI output. Decisions must use [targets] —
  /// no single string can answer »run pana?«, »check the npm login?« and »is
  /// there any registry?« at once for a hybrid, and pretending otherwise is
  /// what made hybrids npm-only.
  Future<String> fromDirectory(Directory directory) async =>
      (await targets(directory)).label;
}

/// Mock implementation of PublishTo
class MockPublishTo extends MockDirCommand<void> implements PublishTo {}
