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
import 'package:mocktail/mocktail.dart' as mocktail;
import 'package:pub_semver/pub_semver.dart';

// .............................................................................
/// Version increments
enum VersionIncrement {
  /// Patch version increment
  patch,

  /// Minor version increment
  minor,

  /// Major version increment
  major,
}

// .............................................................................
/// Creates a new version and writes it into pubspec.yaml
class PrepareNextVersion extends DirCommand<void> {
  /// Constructor
  PrepareNextVersion({
    required super.ggLog,
    PublishedVersion? publishedVersion,
  })  : _publishedVersion = publishedVersion ?? PublishedVersion(ggLog: ggLog),
        super(
          name: 'prepare-next-version',
          description:
              'Creates a new version in pubspec.yaml and CHANGELOG.md.',
        ) {
    _addArgs();
  }

  // ...........................................................................
  @override
  Future<void> exec({
    required Directory directory,
    required GgLog ggLog,
    VersionIncrement? increment,
  }) async {
    await GgStatusPrinter<void>(
      message: 'Increase version',
      ggLog: ggLog,
    ).logTask(
      task: () => apply(
        ggLog: ggLog,
        directory: directory,
        increment: increment ?? _incrementFromArgs,
      ),
      success: (success) => true,
    );
  }

  // ...........................................................................
  /// Writes the next version into pubspec.yaml and CHANGELOG.md
  Future<void> apply({
    required Directory directory,
    required GgLog ggLog,
    required VersionIncrement increment,
  }) async {
    // Checks
    await check(directory: directory);
    await _checkPubspec(directory: directory);

    // Estimate the next version
    final next = await nextVersion(
      directory: directory,
      ggLog: ggLog,
      increment: increment,
    );

    // Write the next version into pubspec.yaml
    await _writeVersionIntoPubspec(
      directory: directory,
      ggLog: ggLog,
      next: next,
    );
  }

  // ...........................................................................
  /// Returns the next version for the given dart package
  Future<Version> nextVersion({
    required Directory directory,
    required GgLog ggLog,
    required VersionIncrement increment,
  }) async {
    // Get the published version
    final publishedVersion = await _publishedVersion.get(
      directory: directory,
      ggLog: ggLog,
    );

    // Calculate the next version based on the increment
    final next = calculateNextVersion(
      publishedVersion: publishedVersion,
      increment: increment,
    );

    return next;
  }

  // ...........................................................................
  /// Returns the next version based on the published version and the increment
  Version calculateNextVersion({
    required Version publishedVersion,
    required VersionIncrement increment,
  }) {
    switch (increment) {
      case VersionIncrement.patch:
        return publishedVersion.nextPatch;
      case VersionIncrement.minor:
        return publishedVersion.nextMinor;
      case VersionIncrement.major:
        return publishedVersion.nextMajor;
    }
  }

  // ######################
  // Private
  // ######################

  // ...........................................................................
  final PublishedVersion _publishedVersion;

  // ...........................................................................
  Future<void> _checkPubspec({required Directory directory}) async {
    final pubspecFile = File('${directory.path}/pubspec.yaml');
    if (!await pubspecFile.exists()) {
      throw Exception('pubspec.yaml not found');
    }

    final content = await pubspecFile.readAsString();
    if (!content.contains(RegExp(r'\nversion: '))) {
      throw Exception('"version:" not found in pubspec.yaml');
    }
  }

  // ...........................................................................
  VersionIncrement get _incrementFromArgs {
    final incrementFromArgsStr = argResults?['version-increment'] as String;
    return VersionIncrement.values.byName(incrementFromArgsStr);
  }

  // ...........................................................................
  void _addArgs() {
    argParser.addOption(
      'version-increment',
      abbr: 'n',
      help: 'The increment the next version is compared to the current one.',
      allowed: VersionIncrement.values.map((e) => e.name),
      mandatory: true,
    );
  }

  // ...........................................................................
  Future<void> _writeVersionIntoPubspec({
    required Directory directory,
    required GgLog ggLog,
    required Version next,
  }) async {
    final pubspecFile = File('${directory.path}/pubspec.yaml');
    final lines = await pubspecFile.readAsLines();
    final newLines = <String>[];
    for (final line in lines) {
      if (line.startsWith('version: ')) {
        newLines.add('version: $next');
      } else {
        newLines.add(line);
      }
    }
    await pubspecFile.writeAsString(newLines.join('\n'));
  }
}

// .............................................................................
/// Mock class for PrepareNextVersion
class MockPrepareNextVersion extends mocktail.Mock
    implements PrepareNextVersion {}
