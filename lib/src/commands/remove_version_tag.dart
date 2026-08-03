// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_git/gg_git.dart';
import 'package:gg_lang/gg_lang.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_process/gg_process.dart';
import 'package:gg_console_colors/gg_console_colors.dart';

// #############################################################################
/// Removes the git tag of the version that is about to be published — locally
/// as well as on the remote.
///
/// A publish that fails after the release was tagged leaves the tag behind,
/// pointing at a commit the retry replaces (an amended version commit, a merge
/// commit). The tag step of the next run then either refuses to tag at all
/// (`version must be greater ...`) or the release ends up tagged on an
/// abandoned commit. Removing the tag before publishing lets the publish flow
/// recreate it on the new release commit.
///
/// Only the tag of the version found in the manifest is touched. [Publish]
/// runs the removal after `is-version-prepared` confirmed that this version is
/// an increment of the published one, so the tag of an already released
/// version is never deleted.
class RemoveVersionTag extends DirCommand<bool> {
  /// Constructor
  RemoveVersionTag({
    required super.ggLog,
    GgProcessWrapper processWrapper = const GgProcessWrapper(),
    LanguageCatalog? catalog,
    HasRemote? hasRemote,
  }) : _processWrapper = processWrapper,
       _catalog = catalog,
       _hasRemote =
           hasRemote ?? HasRemote(ggLog: ggLog, processWrapper: processWrapper),
       super(
         name: 'remove-version-tag',
         description: 'Remove the version tag locally and on origin',
       );

  // ...........................................................................
  @override
  Future<bool> exec({required Directory directory, required GgLog ggLog}) =>
      get(directory: directory, ggLog: ggLog);

  // ...........................................................................
  /// Removes the tag of the version in the manifest locally and on the remote.
  /// Returns true when a tag was removed.
  @override
  Future<bool> get({required Directory directory, required GgLog ggLog}) async {
    await check(directory: directory);

    final version = await _versionToBePublished(directory);

    // Without a manifest the version lives in the git tags themselves. The
    // tag of the next version does not exist yet, so there is nothing to
    // remove.
    if (version == null) {
      ggLog('No manifest - no version tag to be removed.');
      return false;
    }

    final removedLocally = await _removeLocalTag(directory, version, ggLog);
    final removedRemotely = await _removeRemoteTag(directory, version, ggLog);

    // Nothing removed means there was no tag in the first place — a non-event
    // the user does not need to read about.
    if (!removedLocally && !removedRemotely) {
      return false;
    }

    return true;
  }

  // ######################
  // Private
  // ######################

  final GgProcessWrapper _processWrapper;
  final HasRemote _hasRemote;

  /// The language catalog used to resolve the manifest. Defaults to the
  /// bundled gg_lang catalog when null.
  final LanguageCatalog? _catalog;

  // ...........................................................................
  /// The version the manifest will publish, or null when the project has no
  /// manifest. Bridges are published as TypeScript, i.e. their version is
  /// taken from package.json.
  Future<String?> _versionToBePublished(Directory directory) async {
    if (checkProjectType(directory) == ProjectType.none) {
      return null;
    }

    final catalog = _catalog ?? await LanguageCatalog.load();
    final version = await Manifest.detect(
      directory,
      catalog,
      treatBridgeAsTypeScript: true,
    ).readVersion();

    return version.toString();
  }

  // ...........................................................................
  /// Deletes the local tag [version]. Returns false when it does not exist.
  Future<bool> _removeLocalTag(
    Directory directory,
    String version,
    GgLog ggLog,
  ) async {
    final existing = await _processWrapper.run('git', [
      'tag',
      '--list',
      version,
    ], workingDirectory: directory.path);

    if (existing.exitCode != 0) {
      ggLog(
        [
          cDetail('✗ Failed to list the tags of ${dirName(directory)}'),
          cError('${existing.stderr}'),
        ].join('\n'),
      );
      throw Exception(cDetail('Failed to list the tags.'));
    }

    final exists = (existing.stdout as String)
        .split(RegExp(r'\r?\n'))
        .map((e) => e.trim())
        .contains(version);

    if (!exists) {
      return false;
    }

    final result = await _processWrapper.run('git', [
      'tag',
      '-d',
      version,
    ], workingDirectory: directory.path);

    if (result.exitCode != 0) {
      ggLog(
        [
          cDetail('✗ Failed to remove the local tag $version'),
          cError('${result.stderr}'),
        ].join('\n'),
      );
      throw Exception(cDetail('Failed to remove the local tag.'));
    }

    ggLog('Removed the local tag $version.');
    return true;
  }

  // ...........................................................................
  /// Deletes the tag [version] on origin. Returns false when the repo has no
  /// remote or the remote does not have the tag.
  Future<bool> _removeRemoteTag(
    Directory directory,
    String version,
    GgLog ggLog,
  ) async {
    // A repo without a remote has no remote tag to remove.
    if (!await _hasRemote.get(directory: directory, ggLog: ggLog)) {
      return false;
    }

    final ref = 'refs/tags/$version';

    final remoteTags = await _processWrapper.run('git', [
      'ls-remote',
      '--tags',
      'origin',
      ref,
    ], workingDirectory: directory.path);

    if (remoteTags.exitCode != 0) {
      ggLog(
        [
          cDetail('✗ Failed to list the remote tags of ${dirName(directory)}'),
          cError('${remoteTags.stderr}'),
        ].join('\n'),
      );
      throw Exception(cDetail('Failed to list the remote tags.'));
    }

    // Each line is "<hash>\t<ref>". An annotated tag adds a second line for
    // the dereferenced commit ("<ref>^{}"), so compare the refs exactly.
    final refs = (remoteTags.stdout as String)
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => line.split(RegExp(r'\s+')).last);

    if (!refs.contains(ref)) {
      return false;
    }

    // Delete the full ref, so a branch of the same name is never touched.
    final result = await _processWrapper.run('git', [
      'push',
      'origin',
      '--delete',
      ref,
    ], workingDirectory: directory.path);

    if (result.exitCode != 0) {
      ggLog(
        [
          cDetail('✗ Failed to remove the remote tag $version'),
          cError('${result.stderr}'),
        ].join('\n'),
      );
      throw Exception(cDetail('Failed to remove the remote tag.'));
    }

    ggLog('Removed the remote tag $version.');
    return true;
  }
}

// .............................................................................
/// A Mock for the RemoveVersionTag class using Mocktail
class MockRemoveVersionTag extends MockDirCommand<bool>
    implements RemoveVersionTag {}
