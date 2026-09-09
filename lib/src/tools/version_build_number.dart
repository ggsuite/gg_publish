// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:pub_semver/pub_semver.dart';

// .............................................................................
/// Returns [version] without its build number, e.g. `1.2.4+155` → `1.2.4`.
///
/// Prerelease suffixes are kept: `1.2.4-rc.1+155` → `1.2.4-rc.1`.
Version withoutBuildNumber(Version version) => Version(
  version.major,
  version.minor,
  version.patch,
  pre: version.preRelease.isEmpty ? null : version.preRelease.join('.'),
);

// .............................................................................
/// Carries the build number of [current] over to [target].
///
/// A manifest version like `1.2.4+155` keeps its build number when the next
/// version is prepared, and the number is counted up: with [target] `1.2.5`
/// the result is `1.2.5+156`. Flutter apps rely on this — the build number
/// is what the app stores identify an upload by.
///
/// Without a build number in [current] (or without a [current] at all) the
/// [target] is returned unchanged.
///
/// When [current] already is the [target] release — a resumed publish that
/// bumped the manifest before — its build number is kept as it is, so a
/// re-run does not count up a second time.
///
/// A build number that does not start with a number (e.g. `+nightly`) is
/// carried over verbatim; there is nothing to count up.
Version withNextBuildNumber({required Version target, Version? current}) {
  final build = current?.build;
  if (build == null || build.isEmpty) {
    return target;
  }

  final first = build.first;
  final String nextBuild;
  if (first is int) {
    final isAlreadyPrepared =
        withoutBuildNumber(current!) == withoutBuildNumber(target);
    nextBuild = (isAlreadyPrepared ? first : first + 1).toString();
  } else {
    nextBuild = build.join('.');
  }

  return Version(
    target.major,
    target.minor,
    target.patch,
    pre: target.preRelease.isEmpty ? null : target.preRelease.join('.'),
    build: nextBuild,
  );
}
