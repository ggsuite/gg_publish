// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:convert';
import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_version/gg_version.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart' as mocktail;

// .............................................................................
/// Returns the version published to pub.dev of a given dart package
class PublishedVersion extends DirCommand<Version> {
  /// Constructor
  PublishedVersion({
    required super.ggLog,
    FromGit? versionFromGit,
    http.Client? httpClient,
  })  : _httpClient = httpClient ?? http.Client(), // coverage:ignore-line
        _versionFromGit = versionFromGit ?? FromGit(ggLog: ggLog),
        super(
          name: 'published-version',
          description:
              'Returns the version published to pub.dev of a given dart '
              'package.',
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
  /// Returns true if the current directory state is published to pub.dev
  /// If the package cannot be found on pub.dev, the version
  /// from the git tags is treated as published version.
  @override
  Future<Version> get({
    required GgLog ggLog,
    required Directory directory,
  }) async {
    // Read pubspec.yaml
    final pubspecFile = File('${directory.path}/pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      throw ArgumentError('pubspec.yaml not found');
    }
    final pubspec = pubspecFile.readAsStringSync();

    // Is published to none? Return verson from tag
    if (pubspec.contains(RegExp(r'publish_to:\s*none'))) {
      return await _versionFromGitTag(directory, ggLog);
    }

    // Read the name from pubspec.yaml
    final name = RegExp(r'name: (.*)').firstMatch(pubspec)?.group(1);
    if (name == null) {
      throw ArgumentError('name not found in pubspec.yaml');
    }

    // Get the package info json from pub.dev
    late http.Response response;
    try {
      final uri = Uri.parse('https://pub.dev/api/packages/$name');
      response = await _httpClient.get(uri);
      _httpClient.close();
    } catch (e) {
      throw Exception(
        'Exception while getting the latest version from pub.dev:\n' '$e',
      );
    }

    final statusCode = response.statusCode;
    if (statusCode == 404) {
      return await _versionFromGitTag(directory, ggLog);
    }

    if (statusCode != 200) {
      throw ArgumentError(
        'Error $statusCode while getting the latest version from pub.dev',
      );
    }

    final parseResponse = jsonDecode(response.body) as Map<String, dynamic>;
    if (parseResponse['latest'] == null) {
      throw ArgumentError('Response from pub.dev does not contain "latest"');
    }

    final latest = parseResponse['latest'] as Map<String, dynamic>;
    if (latest['version'] == null) {
      throw ArgumentError('Response from pub.dev does not contain "version"');
    }

    return Version.parse(latest['version'] as String);
  }

  // ...........................................................................
  Future<Version> _versionFromGitTag(Directory directory, GgLog ggLog) async {
    return await _versionFromGit.fromHead(
          directory: directory,
          ggLog: ggLog,
        ) ??
        Version(0, 0, 0);
  }

  // ######################
  // Private
  // ######################
  final http.Client _httpClient;
  final FromGit _versionFromGit;
}

// .............................................................................
/// A Mock for the PublishedVersion class using Mocktail
class MockPublishedVersion extends MockDirCommand<Version>
    implements PublishedVersion {}

// .............................................................................
/// A Mock for the http.Client class using Mocktail
class MockClient extends mocktail.Mock implements http.Client {}
