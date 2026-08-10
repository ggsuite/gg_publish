// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_lang/gg_lang.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_version/gg_version.dart';
import 'package:pub_semver/pub_semver.dart';

// #############################################################################

/// The outcome of a reconciliation run.
typedef HybridVersionSync = ({
  /// The version both manifests carry afterwards.
  Version version,

  /// Whether the two manifests disagreed and had to be changed.
  bool changed,
});

// #############################################################################

/// Writes the higher of the two manifest versions of a hybrid into **both**
/// manifests and regenerates the generated version files.
///
/// A hybrid — a directory carrying both a `pubspec.yaml` and a `package.json`
/// — has two version numbers that describe one artifact. Nothing in git keeps
/// them together, so they drift: a repository can sit at `1.0.2` on its Dart
/// side and `1.0.1` on its npm side. Publishing such a repository would release
/// two different versions of the same code, and the git tag could only match
/// one of them.
///
/// The higher version wins. It is the one that was already claimed — by a git
/// tag, a registry release or a manual edit — so lowering it would hand out a
/// version number twice.
///
/// A no-op for anything that is not a hybrid, and for a hybrid whose versions
/// already agree.
class SyncHybridVersions extends DirCommand<bool> {
  /// Constructor.
  SyncHybridVersions({
    required super.ggLog,
    super.name = 'sync-hybrid-versions',
    super.description =
        'Writes the higher of pubspec.yaml and package.json into both.',
    LanguageCatalog? catalog,
    WriteVersionFile? writeVersionFile,
  }) : _catalog = catalog,
       _writeVersionFile =
           writeVersionFile ?? WriteVersionFile(ggLog: ggLog, catalog: catalog);

  final LanguageCatalog? _catalog;
  final WriteVersionFile _writeVersionFile;

  // ...........................................................................
  /// Reconciles the two manifests and returns whether they had to be changed.
  @override
  Future<bool> get({
    required Directory directory,
    required GgLog ggLog,
  }) async =>
      (await apply(directory: directory, ggLog: ggLog))?.changed ?? false;

  // ...........................................................................
  /// Reconciles the two manifests of the hybrid in [directory].
  ///
  /// Returns null when [directory] is not a hybrid, or when either version
  /// cannot be read — an unreadable manifest is reported by the checks that own
  /// it, not silently rewritten here.
  Future<HybridVersionSync?> apply({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    await check(directory: directory);

    final catalog = _catalog ?? await LanguageCatalog.load();
    final versions = await hybridVersions(directory, catalog: catalog);
    if (versions == null) {
      return null;
    }

    if (versions.pubspec == versions.packageJson) {
      return (version: versions.pubspec, changed: false);
    }

    final winner = versions.pubspec > versions.packageJson
        ? versions.pubspec
        : versions.packageJson;

    for (final target in PublishTarget.values) {
      await target.manifestIn(directory, catalog).writeVersion(winner);
    }

    // Keep the generated version constants in step. WriteVersionFile writes
    // one file per language for a hybrid, so both sides end up consistent.
    await _writeVersionFile.apply(
      directory: directory,
      ggLog: ggLog,
      version: winner.toString(),
    );

    ggLog(
      cWarn(
        'pubspec.yaml (${versions.pubspec}) and package.json '
        '(${versions.packageJson}) carried different versions — '
        'both set to $winner.',
      ),
    );

    return (version: winner, changed: true);
  }
}

// #############################################################################
/// A Mock for the SyncHybridVersions class using Mocktail
class MockSyncHybridVersions extends MockDirCommand<bool>
    implements SyncHybridVersions {}
