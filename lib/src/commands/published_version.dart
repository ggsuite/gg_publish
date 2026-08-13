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
/// One registry a package publishes to, together with the manifest describing
/// it. A hybrid resolves to two of these.
typedef _ResolvedRegistry = ({
  PublishTarget target,
  Registry registry,
  Manifest manifest,
  String manifestFile,
});

// .............................................................................
/// Returns the version a package has published to its registries (pub.dev for
/// the `pubspec.yaml` side, npm for the `package.json` side — a hybrid has
/// both).
class PublishedVersion extends DirCommand<Version> {
  /// Constructor
  PublishedVersion({
    required super.ggLog,
    FromGit? versionFromGit,
    http.Client? httpClient,
    this._catalog,
    RegistryFactory? registryFactory,
  }) : _registryFactory =
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
  /// registries — the **highest** across all of them for a hybrid that
  /// publishes to both. If the package cannot be found anywhere, the version
  /// from the git tags is treated as the published version.
  ///
  /// The maximum is what makes the version bump correct for a hybrid: the next
  /// version has to clear every registry the package is on, not just one.
  @override
  Future<Version> get({
    required GgLog ggLog,
    required Directory directory,
  }) async {
    final resolved = await _resolveAll(directory: directory);

    // Not published to any public registry? Use the version from the git tag.
    if (resolved.isEmpty) {
      return _versionFromGitTag(directory, ggLog);
    }

    Version? highest;
    for (final entry in resolved) {
      final latest = await _latestOf(entry, ggLog);
      if (latest != null && (highest == null || latest > highest)) {
        highest = latest;
      }
    }

    return highest ?? await _versionFromGitTag(directory, ggLog);
  }

  // ...........................................................................
  /// Returns the version the package in [directory] has published to
  /// [target], or null when it was never published there.
  ///
  /// Unlike [get] this never falls back to a git tag and never mixes the two
  /// registries of a hybrid — the publish flow uses it to decide, per registry,
  /// whether an upload is still outstanding.
  Future<Version?> latestVersionFor({
    required PublishTarget target,
    required GgLog ggLog,
    required Directory directory,
  }) async {
    final resolved = await _resolveFor(target: target, directory: directory);
    if (resolved == null) return null;
    return _latestOf(resolved, ggLog);
  }

  // ...........................................................................
  /// Returns all versions the package has published to its registries,
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
  /// public registries (pub.dev / npm), including prereleases — the **union**
  /// across every registry it publishes to. Returns null for packages without
  /// any public registry (`publish_to: none` and `private: true`, or no
  /// manifest at all). An empty list means the package was never published.
  ///
  /// The union is what the rc numbering needs: a prerelease number spent on
  /// either registry must not be handed out again.
  Future<List<Version>?> registryVersions({
    required Directory directory,
  }) async {
    final resolved = await _resolveAll(directory: directory);

    if (resolved.isEmpty) {
      return null;
    }

    final versions = <Version>{};
    for (final entry in resolved) {
      versions.addAll(await _allOf(entry));
    }
    return versions.toList();
  }

  // ...........................................................................
  /// Returns the versions the package in [directory] has published to
  /// [target], or null when it does not publish there at all.
  Future<List<Version>?> registryVersionsFor({
    required PublishTarget target,
    required Directory directory,
  }) async {
    final resolved = await _resolveFor(target: target, directory: directory);
    if (resolved == null) return null;
    return _allOf(resolved);
  }

  // ...........................................................................
  /// Resolves the registry and package name for every target [directory]
  /// publishes to. Empty for packages without any public registry.
  Future<List<_ResolvedRegistry>> _resolveAll({
    required Directory directory,
  }) async {
    final catalog = _catalog ?? await LanguageCatalog.load();
    final targets = await publishTargetsOf(directory, catalog: catalog);

    return <_ResolvedRegistry>[
      for (final target in targets.ordered)
        _resolveTarget(target: target, directory: directory, catalog: catalog),
    ];
  }

  // ...........................................................................
  /// Resolves one target, or null when [directory] does not publish there.
  Future<_ResolvedRegistry?> _resolveFor({
    required PublishTarget target,
    required Directory directory,
  }) async {
    final catalog = _catalog ?? await LanguageCatalog.load();
    final targets = await publishTargetsOf(directory, catalog: catalog);
    if (!targets.contains(target)) {
      return null;
    }
    return _resolveTarget(
      target: target,
      directory: directory,
      catalog: catalog,
    );
  }

  // ...........................................................................
  _ResolvedRegistry _resolveTarget({
    required PublishTarget target,
    required Directory directory,
    required LanguageCatalog catalog,
  }) {
    final type = target.projectTypeIn(directory);
    final spec = target.specIn(directory, catalog);

    // The package directory matters for npm lookups: npm resolves the
    // project-level .npmrc (scoped/private registries) from its CWD.
    return (
      target: target,
      registry: _registryFactory.forProjectType(
        type,
        spec: spec,
        workingDirectory: directory.path,
      ),
      manifest: target.manifestIn(directory, catalog),
      manifestFile: spec.manifest.file,
    );
  }

  // ...........................................................................
  Future<String> _nameOf(_ResolvedRegistry resolved) async {
    try {
      return await resolved.manifest.readName();
    } on ManifestException {
      throw ArgumentError('name not found in ${resolved.manifestFile}');
    }
  }

  // ...........................................................................
  Future<Version?> _latestOf(_ResolvedRegistry resolved, GgLog ggLog) async {
    try {
      return await resolved.registry.latestVersion(
        packageName: await _nameOf(resolved),
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
  }

  // ...........................................................................
  Future<List<Version>> _allOf(_ResolvedRegistry resolved) async {
    try {
      return await resolved.registry.allVersions(
        packageName: await _nameOf(resolved),
      );
    } on RegistryException catch (e) {
      throw Exception(cDetail('Failed to read the registry: $e'));
    }
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
