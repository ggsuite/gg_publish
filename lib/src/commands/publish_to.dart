// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_lang/gg_lang.dart';
import 'package:gg_log/gg_log.dart';

/// Returns the publish target of a package's manifest.
///
/// For Dart/Flutter this is the value of `pubspec.yaml`'s `publish_to` field
/// (defaulting to `pub.dev`). For TypeScript it is derived from
/// `package.json`'s `private` field: `none` when private, otherwise `npm`.
class PublishTo extends DirCommand<void> {
  /// Constructor
  PublishTo({
    required super.ggLog,
    super.name = 'publish-to',
    super.description = 'Publishes the package to the given directory.',
    LanguageCatalog? catalog,
  }) : _catalog = catalog;

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
  /// Returns the publish target of the manifest in [directory].
  Future<String> fromDirectory(Directory directory) async {
    final catalog = _catalog ?? await LanguageCatalog.load();
    final type = detectProjectType(directory);
    final manifest = Manifest(
      directory: directory,
      spec: catalog.spec(type).manifest,
    );

    switch (type) {
      case ProjectType.dart:
      case ProjectType.flutter:
        return await manifest.readPublishTargetMarker() ?? 'pub.dev';
      case ProjectType.typescript:
        return await manifest.isPrivate() ? 'none' : 'npm';
    }
  }
}

/// Mock implementation of PublishTo
class MockPublishTo extends MockDirCommand<void> implements PublishTo {}
