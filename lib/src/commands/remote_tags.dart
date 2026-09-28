// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_process/gg_process.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:pub_semver/pub_semver.dart';

// #############################################################################
/// Returns the names of the tags on origin, e.g. `1.2.3`.
///
/// Asks the remote itself (`git ls-remote`) instead of the local tags: a tag
/// somebody else pushed is not fetched into every clone, but it still spends
/// the version it names.
class RemoteTags extends DirCommand<Set<String>> {
  /// Constructor
  RemoteTags({
    required super.ggLog,
    GgProcessWrapper processWrapper = const GgProcessWrapper(),
    HasRemote? hasRemote,
    this._gitRetry = const GitRetry(),
  }) : _processWrapper = processWrapper,
       _hasRemote =
           hasRemote ?? HasRemote(ggLog: ggLog, processWrapper: processWrapper),
       super(name: 'remote-tags', description: 'List the tags on origin');

  // ...........................................................................
  @override
  Future<Set<String>> exec({
    required Directory directory,
    required GgLog ggLog,
    Map<String, dynamic> options = const {},
  }) async {
    final tags = await get(directory: directory, ggLog: ggLog);
    tags.forEach(ggLog);
    return tags;
  }

  // ...........................................................................
  /// Returns the tag names on origin. Empty when [directory] is no git repo
  /// or has no remote.
  @override
  Future<Set<String>> get({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    await check(directory: directory);

    final isRepo = Directory('${directory.path}/.git').existsSync();
    if (!isRepo || !await _hasRemote.get(directory: directory, ggLog: ggLog)) {
      return {};
    }

    final result = await _gitRetry.run(
      () => _processWrapper.run('git', [
        'ls-remote',
        '--tags',
        'origin',
      ], workingDirectory: directory.path),
      ggLog: ggLog,
      description: 'git ls-remote --tags origin',
    );

    if (result.exitCode != 0) {
      ggLog(
        cDetail('✗ Failed to list the remote tags of ${dirName(directory)}'),
      );
      // The reason goes into the exception: callers that silence the log
      // must still be able to tell the user why.
      throw Exception(
        '${cDetail('Failed to list the remote tags.')}\n'
        '${cError('${result.stderr}'.trim())}',
      );
    }

    // Each line is "<hash>\trefs/tags/<name>". An annotated tag adds a second
    // line for the dereferenced commit ("<name>^{}").
    return (result.stdout as String)
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.split(RegExp(r'\s+')).last)
        .where((ref) => ref.startsWith(_prefix))
        .map((ref) => ref.substring(_prefix.length))
        .where((name) => !name.endsWith('^{}'))
        .toSet();
  }

  // ...........................................................................
  /// Returns the highest version tagged on origin, or null when origin has no
  /// version tag. Tags that are no version (»v1.0.0«, »release«) are ignored.
  Future<Version?> highestVersion({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    Version? highest;
    for (final tag in await get(directory: directory, ggLog: ggLog)) {
      final Version version;
      try {
        version = Version.parse(tag);
      } on FormatException {
        continue;
      }
      if (highest == null || version > highest) {
        highest = version;
      }
    }
    return highest;
  }

  // ...........................................................................
  /// Returns the version the next version is counted up from: the higher of
  /// [publishedVersion] and the highest version tagged on origin.
  ///
  /// A tag no registry knows was set by hand or by a release that stopped
  /// before its upload — gg itself tags only after the upload. It spends its
  /// version all the same: releasing that version would have to delete the
  /// tag, which a remote may refuse (Azure DevOps requires »Force push«), and
  /// tagging any version below it fails (»must be greater«). Counting on from
  /// the tag avoids both, and the chosen increment stays an increment.
  Future<Version> baseline({
    required Directory directory,
    required GgLog ggLog,
    required Version publishedVersion,
  }) async {
    final tagged = await highestVersion(directory: directory, ggLog: ggLog);
    if (tagged == null || tagged <= publishedVersion) {
      return publishedVersion;
    }

    ggLog(
      cDetail(
        'Origin has the tag $tagged, but $publishedVersion is the latest '
        'published version. Counting on from $tagged.',
      ),
    );
    return tagged;
  }

  // ######################
  // Private
  // ######################

  static const _prefix = 'refs/tags/';

  final GgProcessWrapper _processWrapper;
  final GitRetry _gitRetry;
  final HasRemote _hasRemote;
}

// .............................................................................
/// A Mock for the RemoteTags class using Mocktail
class MockRemoteTags extends MockDirCommand<Set<String>>
    implements RemoteTags {}
