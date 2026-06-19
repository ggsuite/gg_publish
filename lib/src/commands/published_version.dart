// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
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
         description:
             'Returns the version published to the package registry '
             '(pub.dev / npm).',
       );

  // ...........................................................................
  @override
  Future<Version> exec({
    required Directory directory,
    required GgLog ggLog,
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
    final catalog = _catalog ?? await LanguageCatalog.load();

    final ProjectType type;
    try {
      // Bridges resolve to npm (published as TypeScript), so query npm.
      type = checkProjectType(directory);
    } catch (_) {
      throw ArgumentError('pubspec.yaml not found');
    }

    final spec = catalog.spec(type);
    final manifest = Manifest(directory: directory, spec: spec.manifest);

    // Not published to a public registry? Return the version from the git tag.
    if (await manifest.isPrivate()) {
      return _versionFromGitTag(directory, ggLog);
    }

    final String name;
    try {
      name = await manifest.readName();
    } on ManifestException {
      throw ArgumentError('name not found in ${spec.manifest.file}');
    }

    final registry = _registryFactory.forProjectType(type, spec: spec);

    final Version? latest;
    try {
      latest = await registry.latestVersion(packageName: name);
    } on RegistryException catch (e) {
      throw Exception(
        'Exception while getting the latest version from the registry:\n$e',
      );
    }

    return latest ?? await _versionFromGitTag(directory, ggLog);
  }

  // ...........................................................................
  Future<Version> _versionFromGitTag(Directory directory, GgLog ggLog) async {
    return await _versionFromGit.fromHead(directory: directory, ggLog: ggLog) ??
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
