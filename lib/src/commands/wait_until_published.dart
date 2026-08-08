// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_lang/gg_lang.dart';
import 'package:gg_log/gg_log.dart';

import 'publish_to.dart';

/// Waits until the manifest version of the current directory is visible on
/// every registry it publishes to — pub.dev for the `pubspec.yaml` side, npm
/// for the `package.json` side. A hybrid is waited for on both.
///
/// Registries need a while to process a fresh upload. This command makes the
/// wait explicit: it announces what it is waiting for, shows the web page
/// where the status can be checked manually, reports progress while polling
/// and fails with a clear timeout error instead of hanging forever. Packages
/// that are not published to a public registry (`publish_to: none` /
/// `private: true`) are skipped.
///
/// The wait is idempotent per registry — a version that is already visible
/// returns immediately — so a resumed publish can simply run it again.
class WaitUntilPublished extends DirCommand<void> {
  /// Constructor
  WaitUntilPublished({
    required super.ggLog,
    super.name = 'wait-until-published',
    super.description = 'Wait until the version is on the registry',
    PublishTo? publishTo,
    LanguageCatalog? catalog,
    RegistryWaiter? waiter,
    Map<PublishTarget, RegistryWaiter>? waiters,
    NpmRegistryResolver? npmRegistryResolver,
    // pub.dev can take up to ~10 minutes to make a fresh upload visible —
    // the default leaves headroom beyond that.
    this.timeout = const Duration(minutes: 15),
    this.pollInterval = const Duration(seconds: 10),
  }) : _publishTo = publishTo ?? PublishTo(ggLog: ggLog),
       _catalog = catalog,
       _waiter = waiter,
       _waiters = waiters,
       _npmRegistryResolver = npmRegistryResolver ?? NpmRegistryResolver();

  final PublishTo _publishTo;
  final LanguageCatalog? _catalog;
  final RegistryWaiter? _waiter;
  final Map<PublishTarget, RegistryWaiter>? _waiters;
  final NpmRegistryResolver _npmRegistryResolver;

  /// Maximum time to wait for the version to appear on the registry.
  final Duration timeout;

  /// Delay between registry polls.
  final Duration pollInterval;

  // ...........................................................................
  /// Waits until the manifest version is visible on [targets], defaulting to
  /// every registry the package publishes to.
  @override
  Future<void> get({
    required Directory directory,
    required GgLog ggLog,
    Set<PublishTarget>? targets,
  }) async {
    await check(directory: directory);

    final resolved = targets ?? await _publishTo.targets(directory);
    if (resolved.isEmpty) {
      return; // Not published to a public registry — nothing to wait for.
    }

    final catalog = _catalog ?? await LanguageCatalog.load();

    for (final target in resolved.ordered) {
      final spec = target.specIn(directory, catalog);
      final manifest = target.manifestIn(directory, catalog);

      // The status url is resolved before the waiter is built, so the poll
      // loop never pays for it. On npm it comes from the merged .npmrc: a
      // scoped package on a private feed is not on npmjs.com, and printing
      // that link sends the user to a 404.
      final statusUrl = target == PublishTarget.npm
          ? await _npmRegistryResolver.statusUrlTemplateOf(
              directory: directory,
              fallback: spec.registry?.statusUrl,
            )
          : spec.registry?.statusUrl;

      final waiter =
          _waiters?[target] ??
          _waiter ??
          // coverage:ignore-start
          RegistryWaiter(
            registry: const RegistryFactory().forProjectType(
              target.projectTypeIn(directory),
              spec: spec,
              workingDirectory: directory.path,
            ),
            registryName: target.id,
            statusUrl: statusUrl,
            log: ggLog,
            timeout: timeout,
            pollInterval: pollInterval,
          );
      // coverage:ignore-end

      await waiter.waitUntilVersionAvailable(
        packageName: await manifest.readName(),
        version: (await manifest.readVersion()).toString(),
      );
    }
  }
}

/// Mock implementation of WaitUntilPublished
class MockWaitUntilPublished extends MockDirCommand<void>
    implements WaitUntilPublished {}
