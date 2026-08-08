// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_lang/gg_lang.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_version/gg_version.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart' as mocktail;
import 'package:gg_console_colors/gg_console_colors.dart';

// .............................................................................
/// Returns the version a package has published to its registry (pub.dev for
/// Dart/Flutter, npm for TypeScript).
class PublishedVersion extends DirCommand<Version> {
  /// Constructor
  PublishedVersion({
    required super.ggLog,
    FromGit? versionFromGit,
    http.Client? httpClient,
    LanguageCatalog? catalog,
    RegistryFactory? registryFactory,
  }) : _catalog = catalog,
       _registryFactory =
           registryFactory ?? RegistryFactory(httpClient: httpClient),
       _versionFromGit = versionFromGit ?? FromGit(ggLog: ggLog),
       super(
         name: 'published-version',
         description: 'Return the version published to the registry',
       );

  // ...........................................................................
  @override
  Future<Version> exec({
    required Directory directory,
    required GgLog ggLog,
    Map<String, dynamic> options = const {},
  }) async {
    final version = await get(directory: directory, ggLog: ggLog);
    ggLog(version.toString());
    return version;
  }

  // ...........................................................................
  /// Returns the version the package in [directory] has published to its
  /// registry. If the package cannot be found there, the version from the git
  /// tags is treated as the published version.
  @override
  Future<Version> get({
    required GgLog ggLog,
    required Directory directory,
  }) async {
    final resolved = await _resolve(directory: directory);

    // Not published to a public registry? Return the version from the git tag.
    if (resolved == null) {
      return _versionFromGitTag(directory, ggLog);
    }

    final Version? latest;
    try {
      latest = await resolved.registry.latestVersion(
        packageName: resolved.name,
      );
    } on RegistryException catch (e) {
      ggLog(
        [
          cDetail('✗ Failed to read the latest version from the registry'),
          cError('$e'),
        ].join('\n'),
      );
      throw Exception(cDetail('Failed to read the registry.'));
    }

    return latest ?? await _versionFromGitTag(directory, ggLog);
  }

  // ...........................................................................
  /// Returns all versions the package has published to its registry,
  /// including prereleases. For private packages, the git version tags are
  /// returned instead. Empty when nothing has been published yet.
  Future<List<Version>> allVersions({
    required GgLog ggLog,
    required Directory directory,
  }) async {
    final versions = await registryVersions(directory: directory);

    // Not published to a public registry? Return the git version tags.
    if (versions == null) {
      return _versionFromGit.allVersions(directory: directory, ggLog: ggLog);
    }

    return versions;
  }

  // ...........................................................................
  /// Returns the versions the package in [directory] has published to its
  /// public registry (pub.dev / npm), including prereleases. Returns null
  /// for packages without a public registry (`publish_to: none`,
  /// `private: true` or no manifest at all). An empty list means the
  /// package was never published to its registry.
  Future<List<Version>?> registryVersions({
    required Directory directory,
  }) async {
    final resolved = await _resolve(directory: directory);

    if (resolved == null) {
      return null;
    }

    try {
      return await resolved.registry.allVersions(packageName: resolved.name);
    } on RegistryException catch (e) {
      throw Exception(cDetail('Failed to read the registry: $e'));
    }
  }

  // ...........................................................................
  /// Resolves the registry and package name for [directory]. Returns null
  /// for private packages that are not published to a public registry.
  Future<({Registry registry, String name})?> _resolve({
    required Directory directory,
  }) async {
    // Bridges resolve to npm (published as TypeScript), so query npm.
    final type = checkProjectType(directory);

    // Without a manifest there is no registry — versions live in git tags
    // only, exactly like for private packages.
    if (type == ProjectType.none) {
      return null;
    }

    final catalog = _catalog ?? await LanguageCatalog.load();
    final spec = catalog.spec(type);
    final manifest = Manifest(directory: directory, spec: spec.manifest);

    if (await manifest.isPrivate()) {
      return null;
    }

    final String name;
    try {
      name = await manifest.readName();
    } on ManifestException {
      throw ArgumentError('name not found in ${spec.manifest.file}');
    }

    // The package directory matters for npm lookups: npm resolves the
    // project-level .npmrc (scoped/private registries) from its CWD.
    final registry = _registryFactory.forProjectType(
      type,
      spec: spec,
      workingDirectory: directory.path,
    );
    return (registry: registry, name: name);
  }

  // ...........................................................................
  Future<Version> _versionFromGitTag(Directory directory, GgLog ggLog) async {
    // Use the highest version tag of the repository and not only the tags of
    // HEAD: on a feature branch HEAD is usually not tagged, which would make
    // the already released version look like 0.0.0.
    return await _versionFromGit.latest(directory: directory, ggLog: ggLog) ??
        Version(0, 0, 0);
  }

  // ######################
  // Private
  // ######################
  final LanguageCatalog? _catalog;
  final RegistryFactory _registryFactory;
  final FromGit _versionFromGit;
}

// .............................................................................
/// A Mock for the PublishedVersion class using Mocktail
class MockPublishedVersion extends MockDirCommand<Version>
    implements PublishedVersion {}

// .............................................................................
/// A Mock for the http.Client class using Mocktail
class MockClient extends mocktail.Mock implements http.Client {}
