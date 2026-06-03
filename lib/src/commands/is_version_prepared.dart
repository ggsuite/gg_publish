// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_lang/gg_lang.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:gg_version/gg_version.dart';
import 'package:pub_semver/pub_semver.dart';

// #############################################################################
/// Is the version in pubspec.yaml an increment of the version at pub.dev?
class IsVersionPrepared extends DirCommand<bool> {
  /// Constructor
  IsVersionPrepared({
    required super.ggLog,
    PublishedVersion? publishedVersion,
    AllVersions? allVersions,
    bool? treatUnpublishedAsOk,
    LanguageCatalog? catalog,
  }) : _treatUnpublishedAsOk = treatUnpublishedAsOk,
       _publishedVersion = publishedVersion ?? PublishedVersion(ggLog: ggLog),
       _allVersions = allVersions ?? AllVersions(ggLog: ggLog),
       _catalog = catalog,
       super(
         name: 'is-version-prepared',
         description: 'pubspec.yaml and CHANGELOG have same new version?',
       );

  // ...........................................................................
  @override
  Future<bool> exec({
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

    return ok;
  }

  /// The prefix appended to many messages
  static final messagePrefix = 'Version in ${blue('./pubspec.yaml')}';

  // ...........................................................................
  /// Returns true if the current directory state is published to pub.dev
  @override
  Future<bool> get({
    required Directory directory,
    required GgLog ggLog,
    bool? treatUnpublishedAsOk,
  }) async {
    treatUnpublishedAsOk ??= _treatUnpublishedAsOk ?? false;

    final supportsChangeLog = detectProjectType(directory).isDartFamily;

    // The version that is about to be published (pubspec.yaml / package.json).
    final Version localVersion;

    if (supportsChangeLog) {
      // Dart/Flutter: the CHANGELOG.md drives versioning and must either be
      // "Unreleased" or match the version in pubspec.yaml.
      final allVersions = await _allVersions.get(
        ggLog: ggLog,
        directory: directory,
        ignoreUncommitted: true,
      );
      localVersion = allVersions.pubspec;

      final isUnreleased = await _isUnreleased(directory);
      final changeLogIsOk = treatUnpublishedAsOk && isUnreleased;

      if (!changeLogIsOk && allVersions.pubspec != allVersions.changeLog) {
        ggLog(
          darkGray(
            [
              'Version in ${blue('./CHANGELOG.md')} must either',
              'be ${green("[Unreleased]")}',
              'or it must match the version in ${blue('./pubspec.yaml')}.',
            ].join(' '),
          ),
        );
        return false;
      }
    } else {
      // TypeScript & co.: the registry and package.json are the source of
      // truth; there is no CHANGELOG.md to compare against.
      final catalog = _catalog ?? await LanguageCatalog.load();
      localVersion = await Manifest.detect(directory, catalog).readVersion();
    }

    // Where is the package published to?
    final publishTo = await PublishTo(
      ggLog: ggLog,
      catalog: _catalog,
    ).fromDirectory(directory);
    final publishToRegistry = publishTo == 'pub.dev' || publishTo == 'npm';
    final publishToGit = publishTo == 'none';
    if (!publishToRegistry && !publishToGit) {
      throw UnimplementedError('Publishing to $publishTo is not supported.');
    }

    // Publish to a public registry (pub.dev / npm)?
    // Get the published version from there.
    late Version publishedVersion;

    if (publishToRegistry) {
      try {
        publishedVersion = await _publishedVersion.get(
          ggLog: ggLog,
          directory: directory,
        );
      } catch (e) {
        // Package is not yet published?
        // Take 0.0.0 as published version
        bool isNotYetPublished = e.toString().contains('404');
        if (isNotYetPublished) {
          publishedVersion = Version(0, 0, 0);
        }
        // Rethrow all other errors
        else {
          rethrow;
        }
      }
    }

    // Publish to git?
    // Get publishedVersion from the latest git tag (works without a CHANGELOG).
    if ((publishToGit)) {
      final latest = await FromGit(
        ggLog: ggLog,
      ).latest(directory: directory, ggLog: ggLog);
      publishedVersion = latest ?? Version(0, 0, 0);
    }

    // Version in the manifest must be one step bigger than the published one
    final l = localVersion;
    final p = publishedVersion;

    final nextPatch = Version(p.major, p.minor, p.patch + 1);
    final nextMinor = Version(p.major, p.minor + 1, 0);
    final nextMajor = Version(p.major + 1, 0, 0);

    if (l != nextPatch && l != nextMinor && l != nextMajor) {
      ggLog(
        darkGray(
          '$messagePrefix must be one of the following:'
          '\n- $nextPatch'
          '\n- $nextMinor'
          '\n- $nextMajor',
        ),
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
  final bool? _treatUnpublishedAsOk;

  /// The language catalog used to resolve the manifest for non-Dart project
  /// types. Defaults to the bundled gg_lang catalog when null.
  final LanguageCatalog? _catalog;

  // ...........................................................................
  Future<bool> _isUnreleased(Directory directory) async {
    final changeLog = File('${directory.path}/CHANGELOG.md');
    final lines = await changeLog.readAsLines();
    for (final line in lines) {
      if (line.startsWith('## ')) {
        return line.contains('Unreleased');
      }
    }

    return false;
  }
}

// .............................................................................
/// A Mock for the HasPreparedVersions class using Mocktail
class MockIsVersionPrepared extends MockDirCommand<bool>
    implements IsVersionPrepared {}
