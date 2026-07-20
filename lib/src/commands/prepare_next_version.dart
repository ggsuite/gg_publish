// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_lang/gg_lang.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
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
/// Release channels for the next version
enum ReleaseChannel {
  /// Regular stable release
  stable,

  /// Release candidate prerelease (X.Y.Z-rc.N)
  rc,
}

// .............................................................................
/// Creates a new version and writes it into pubspec.yaml
class PrepareNextVersion extends DirCommand<void> {
  /// Constructor
  PrepareNextVersion({
    required super.ggLog,
    PublishedVersion? publishedVersion,
    LanguageCatalog? catalog,
  }) : _publishedVersion = publishedVersion ?? PublishedVersion(ggLog: ggLog),
       _catalog = catalog,
       super(
         name: 'prepare-next-version',
         description: 'Creates a new version in the package manifest.',
       ) {
    _addArgs();
  }

  /// The language catalog used to detect the manifest. Defaults to the bundled
  /// gg_lang catalog when null.
  final LanguageCatalog? _catalog;

  // ...........................................................................
  // ...........................................................................
  @override
  Future<void> exec({
    required Directory directory,
    required GgLog ggLog,
    VersionIncrement? increment,
    ReleaseChannel? channel,
    Version? publishedVersion,
  }) => get(
    directory: directory,
    ggLog: ggLog,
    increment: increment,
    channel: channel,
    publishedVersion: publishedVersion,
  );

  // ...........................................................................
  @override
  Future<void> get({
    required Directory directory,
    required GgLog ggLog,
    VersionIncrement? increment,
    ReleaseChannel? channel,
    Version? publishedVersion,
  }) async {
    await GgStatusPrinter<void>(
      message: 'Increase version',
      ggLog: ggLog,
    ).logTask(
      task: () => apply(
        ggLog: ggLog,
        directory: directory,
        increment: increment ?? _incrementFromArgs,
        channel: channel ?? _channelFromArgs,
        publishedVersion: publishedVersion,
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
    ReleaseChannel channel = ReleaseChannel.stable,
    Version? publishedVersion,
  }) async {
    // Checks
    await check(directory: directory);
    final manifest = await _checkedManifest(directory: directory);

    // Estimate the next version
    final next = await nextVersion(
      directory: directory,
      ggLog: ggLog,
      increment: increment,
      channel: channel,
      publishedVersion: publishedVersion,
    );

    // Write the next version into the manifest (format-preserving).
    await manifest.writeVersion(next);

    // A bridge (pubspec.yaml + package.json + tsconfig.json) is published as
    // TypeScript, but its Dart side must advance in lock-step: Dart consumers
    // resolve the bridge via its git tag and read the version from the bridge's
    // pubspec.yaml. Leaving it stale would break their version constraints.
    if (isBridgeProject(directory)) {
      final catalog = _catalog ?? await LanguageCatalog.load();
      final dartManifest = Manifest(
        directory: directory,
        spec: catalog.spec(detectProjectType(directory)).manifest,
      );
      await dartManifest.writeVersion(next);
    }
  }

  // ...........................................................................
  /// Returns the next version for the given dart package
  Future<Version> nextVersion({
    required Directory directory,
    required GgLog ggLog,
    required VersionIncrement increment,
    ReleaseChannel channel = ReleaseChannel.stable,
    Version? publishedVersion,
    List<Version>? allPublishedVersions,
  }) async {
    // Package is not published? Treat the git version tag as published version.

    // Get the published version
    publishedVersion ??= await _publishedVersion.get(
      directory: directory,
      ggLog: ggLog,
    );

    // Calculate the next version based on the increment
    final next = calculateNextVersion(
      publishedVersion: publishedVersion,
      increment: increment,
    );

    if (channel == ReleaseChannel.stable) {
      return next;
    }

    // rc channel: append the next free rc number for the target version.
    allPublishedVersions ??= await _publishedVersion.allVersions(
      directory: directory,
      ggLog: ggLog,
    );

    return nextRcVersion(target: next, publishedVersions: allPublishedVersions);
  }

  // ...........................................................................
  /// Returns the next rc prerelease for [target] (e.g. `1.2.0-rc.1`), based
  /// on the rc versions already found in [publishedVersions]. Throws when
  /// [target] itself is already published as a stable version.
  Version nextRcVersion({
    required Version target,
    required List<Version> publishedVersions,
  }) {
    final sameRelease = publishedVersions.where(
      (v) =>
          v.major == target.major &&
          v.minor == target.minor &&
          v.patch == target.patch,
    );

    var maxRc = 0;
    for (final version in sameRelease) {
      if (version.preRelease.isEmpty) {
        throw Exception(
          'Cannot prepare an rc for $target: $target is already published as '
          'a stable version. That version number is spent (this also applies '
          'to a retracted release) — choose a higher increment.',
        );
      }

      final pre = version.preRelease;
      if (pre.length == 2 && pre.first == 'rc' && pre.last is int) {
        final number = pre.last as int;
        if (number > maxRc) maxRc = number;
      }
    }

    return Version(
      target.major,
      target.minor,
      target.patch,
      pre: 'rc.${maxRc + 1}',
    );
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
  /// Detects the manifest, ensures it exists and carries a version, and
  /// returns a [Manifest] accessor for it.
  Future<Manifest> _checkedManifest({required Directory directory}) async {
    final catalog = _catalog ?? await LanguageCatalog.load();

    final ProjectType type;
    try {
      // Bridges bump their package.json version (published as TypeScript).
      type = checkProjectType(directory);
    } catch (_) {
      throw Exception('pubspec.yaml not found');
    }

    final spec = catalog.spec(type).manifest;
    final manifest = Manifest(directory: directory, spec: spec);

    String? version;
    try {
      version = await manifest.readVersionString();
    } on ManifestException {
      version = null;
    }
    if (version == null) {
      throw Exception('"version:" not found in ${spec.file}');
    }

    return manifest;
  }

  // ...........................................................................
  VersionIncrement get _incrementFromArgs {
    final incrementFromArgsStr = argResults?['version-increment'] as String;
    return VersionIncrement.values.byName(incrementFromArgsStr);
  }

  // ...........................................................................
  ReleaseChannel get _channelFromArgs {
    final channelFromArgsStr =
        argResults?['channel'] as String? ?? ReleaseChannel.stable.name;
    return ReleaseChannel.values.byName(channelFromArgsStr);
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

    argParser.addOption(
      'channel',
      help: 'The release channel of the next version.',
      allowed: ReleaseChannel.values.map((e) => e.name),
      defaultsTo: ReleaseChannel.stable.name,
    );
  }
}

// .............................................................................
/// Mock class for PrepareNextVersion
class MockPrepareNextVersion extends MockDirCommand<void>
    implements PrepareNextVersion {}
