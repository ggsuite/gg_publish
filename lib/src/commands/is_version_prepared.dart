// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_publish/src/commands/published_version.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:gg_version/gg_version.dart';
import 'package:mocktail/mocktail.dart' as mocktail;
import 'package:pub_semver/pub_semver.dart';

// #############################################################################
/// pubspec.yaml and CHANGELOG have same new version?
class IsVersionPrepared extends DirCommand<void> {
  /// Constructor
  IsVersionPrepared({
    required super.ggLog,
    PublishedVersion? publishedVersion,
    AllVersions? allVersions,
  })  : _publishedVersion = publishedVersion ??
            PublishedVersion(
              ggLog: ggLog,
            ),
        _allVersions = allVersions ??
            AllVersions(
              ggLog: ggLog,
            ),
        super(
          name: 'is-version-prepared',
          description: 'pubspec.yaml and CHANGELOG have same new version?',
        );

  // ...........................................................................
  @override
  Future<void> exec({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    final messages = <String>[];

    final printer = GgStatusPrinter<bool>(
      message: 'Version is prepared',
      ggLog: ggLog,
    );

    final ok = await printer.logTask(
      task: () => get(ggLog: messages.add, directory: directory),
      success: (success) => success,
    );

    if (!ok) {
      throw Exception(messages.join('\n'));
    }
  }

  /// The prefix appended to many messages
  static final messagePrefix = 'Versions in ${blue('./pubspec.yaml')} and '
      '${blue('./CHANGELOG.md')} ';

  // ...........................................................................
  /// Returns true if the current directory state is published to pub.dev
  Future<bool> get({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    // Get all version
    final allVersions = await _allVersions.get(
      ggLog: ggLog,
      directory: directory,
    );

    if (allVersions.pubspec != allVersions.changeLog) {
      ggLog(
        darkGray('$messagePrefix must be the same.'),
      );
      return false;
    }

    // Get the latest version from pub.dev
    final publishedVersion = await _publishedVersion.get(
      ggLog: ggLog,
      directory: directory,
    );

    // Version in pubspec.yaml must be one step bigger than the published one
    final l = allVersions.pubspec;
    final p = publishedVersion;

    final nextPatch = Version(p.major, p.minor, p.patch + 1);
    final nextMinor = Version(p.major, p.minor + 1, 0);
    final nextMajor = Version(p.major + 1, 0, 0);

    if (l != nextPatch && l != nextMinor && l != nextMajor) {
      ggLog(
        darkGray('$messagePrefix must one of the following:'
            '\n- $nextPatch'
            '\n- $nextMinor'
            '\n- $nextMajor'),
      );
      return false;
    }

    return true;
  }

  // ######################
  // Private
  // ######################

  final PublishedVersion _publishedVersion;
  final AllVersions _allVersions;
}

// .............................................................................
/// A Mock for the HasPreparedVersions class using Mocktail
class MockHasPreparedVersions extends mocktail.Mock
    implements IsVersionPrepared {}
