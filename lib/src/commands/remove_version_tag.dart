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

import 'remote_tags.dart';

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
    this._catalog,
    HasRemote? hasRemote,
    RemoteTags? remoteTags,
    GitRetry gitRetry = const GitRetry(),
  }) : _processWrapper = processWrapper,
       _gitRetry = gitRetry,
       _remoteTags =
           remoteTags ??
           RemoteTags(
             ggLog: ggLog,
             processWrapper: processWrapper,
             hasRemote: hasRemote,
             gitRetry: gitRetry,
           ),
       super(
         name: 'remove-version-tag',
         description: 'Remove the version tag locally and on origin',
       );

  // ...........................................................................
  @override
  Future<bool> exec({
    required Directory directory,
    required GgLog ggLog,
    Map<String, dynamic> options = const {},
  }) => get(directory: directory, ggLog: ggLog);

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

  // ...........................................................................
  /// Returns the version to be published when origin already has a tag of
  /// it, otherwise null. Deletes nothing: the publish flow asks this before
  /// the merge, where a tag must not be removed on a guess — it may be
  /// somebody else's.
  Future<String?> tagOnOrigin({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    await check(directory: directory);

    final version = await _versionToBePublished(directory);
    if (version == null) {
      return null;
    }

    final remoteTags = await _remoteTags.get(
      directory: directory,
      ggLog: ggLog,
    );
    return remoteTags.contains(version) ? version : null;
  }

  // ######################
  // Private
  // ######################

  final GgProcessWrapper _processWrapper;
  final GitRetry _gitRetry;
  final RemoteTags _remoteTags;

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
    final remoteTags = await _remoteTags.get(
      directory: directory,
      ggLog: ggLog,
    );
    if (!remoteTags.contains(version)) {
      return false;
    }

    final ref = 'refs/tags/$version';

    // Delete the full ref, so a branch of the same name is never touched.
    final result = await _gitRetry.run(
      () => _processWrapper.run('git', [
        'push',
        'origin',
        '--delete',
        ref,
      ], workingDirectory: directory.path),
      ggLog: ggLog,
      description: 'git push origin --delete $ref',
    );

    if (result.exitCode != 0) {
      ggLog(
        [
          cDetail('✗ Failed to remove the remote tag $version'),
          cError('${result.stderr}'),
          cDetail(
            'The tag has to go before $version can be released. Ask someone '
            'who may delete tags on origin to remove it (Azure DevOps: Git '
            'permission »Force push«), then resume the publish.',
          ),
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
