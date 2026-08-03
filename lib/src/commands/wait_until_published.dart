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
/// its registry (pub.dev for Dart/Flutter, npm for TypeScript).
///
/// Registries need a while to process a fresh upload. This command makes the
/// wait explicit: it announces what it is waiting for, shows the web page
/// where the status can be checked manually, reports progress while polling
/// and fails with a clear timeout error instead of hanging forever. Packages
/// that are not published to a public registry (`publish_to: none` /
/// `private: true`) are skipped.
class WaitUntilPublished extends DirCommand<void> {
  /// Constructor
  WaitUntilPublished({
    required super.ggLog,
    super.name = 'wait-until-published',
    super.description = 'Wait until the version is on the registry',
    PublishTo? publishTo,
    LanguageCatalog? catalog,
    RegistryWaiter? waiter,
    // pub.dev can take up to ~10 minutes to make a fresh upload visible —
    // the default leaves headroom beyond that.
    this.timeout = const Duration(minutes: 15),
    this.pollInterval = const Duration(seconds: 10),
  }) : _publishTo = publishTo ?? PublishTo(ggLog: ggLog),
       _catalog = catalog,
       _waiter = waiter;

  final PublishTo _publishTo;
  final LanguageCatalog? _catalog;
  final RegistryWaiter? _waiter;

  /// Maximum time to wait for the version to appear on the registry.
  final Duration timeout;

  /// Delay between registry polls.
  final Duration pollInterval;

  // ...........................................................................
  @override
  Future<void> get({required Directory directory, required GgLog ggLog}) async {
    await check(directory: directory);

    final target = await _publishTo.fromDirectory(directory);
    if (target != 'pub.dev' && target != 'npm') {
      return; // Not published to a public registry — nothing to wait for.
    }

    final catalog = _catalog ?? await LanguageCatalog.load();
    // Bridges (pubspec + package.json) are published as TypeScript → npm.
    final type = checkProjectType(directory);
    final spec = catalog.spec(type);
    final manifest = Manifest.detect(
      directory,
      catalog,
      treatBridgeAsTypeScript: true,
    );

    final packageName = await manifest.readName();
    final version = await manifest.readVersion();

    final waiter =
        _waiter ??
        // coverage:ignore-start
        RegistryWaiter(
          registry: const RegistryFactory().forProjectType(
            type,
            spec: spec,
            workingDirectory: directory.path,
          ),
          registryName: target,
          statusUrl: spec.registry?.statusUrl,
          log: ggLog,
          timeout: timeout,
          pollInterval: pollInterval,
        );
    // coverage:ignore-end

    await waiter.waitUntilVersionAvailable(
      packageName: packageName,
      version: version.toString(),
    );
  }
}

/// Mock implementation of WaitUntilPublished
class MockWaitUntilPublished extends MockDirCommand<void>
    implements WaitUntilPublished {}
