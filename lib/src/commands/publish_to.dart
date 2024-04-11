// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_log/gg_log.dart';

/// Returns the value of pubspec.yaml's publish_to field.
class PublishTo extends DirCommand<void> {
  /// Constructor
  PublishTo({
    required super.ggLog,
    super.name = 'publish-to',
    super.description = 'Publishes the package to the given directory.',
  });

  // ...........................................................................
  @override
  Future<void> get({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    final result = await fromDirectory(directory);
    ggLog(result);
  }

  // ...........................................................................
  /// Returns the value of pubspec.yaml's publish_to field.
  /// If the field is not set, pub.dev is returned.
  Future<String> fromDirectory(Directory directory) async {
    // Has not publish_to: none
    final pubspec = File('${directory.path}/pubspec.yaml');
    return fromFile(pubspecFile: pubspec);
  }

  // ...........................................................................
  /// Returns the value of pubspec.yaml's publish_to field.
  /// If the field is not set, pub.dev is returned.
  Future<String> fromFile({required File pubspecFile}) async {
    // Has not publish_to: none
    final pubspec = await pubspecFile.readAsString();
    return fromString(pubspec);
  }

  // ...........................................................................
  /// Returns the value of pubspec.yaml's publish_to field.
  /// If the field is not set, pub.dev is returned.
  Future<String> fromString(String pubspec) async {
    final regExp = RegExp(r'publish_to:\s*(\S+)');
    final match = regExp.firstMatch(pubspec);
    return match?.group(1) ?? 'pub.dev';
  }
}

/// Mock implementation of PublishTo
class MockPublishTo extends MockDirCommand<void> implements PublishTo {}
