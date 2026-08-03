// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:test/test.dart';

void main() {
  final messages = <String>[];
  // Strip the colors and the overwrite sequence so the expectations assert
  // the text. One closure instance — mocktail matches ggLog by identity.
  // ignore: prefer_function_declarations_over_variables
  final GgLog ggLog = (String msg) => messages.add(rmControls(msg));
  late Directory d;
  late CommandRunner<dynamic> runner;
  late MockPublishedVersion publishedVersion;
  late IsInRegistry isInRegistry;

  // ...........................................................................
  void mockRegistryVersions(List<Version>? versions) {
    when(
      () =>
          publishedVersion.registryVersions(directory: any(named: 'directory')),
    ).thenAnswer((_) async => versions);
  }

  // ...........................................................................
  setUp(() async {
    messages.clear();
    d = await Directory.systemTemp.createTemp();
    publishedVersion = MockPublishedVersion();
    registerFallbackValue(d);
    isInRegistry = IsInRegistry(
      ggLog: ggLog,
      publishedVersion: publishedVersion,
    );
    runner = CommandRunner<dynamic>('test', 'test')..addCommand(isInRegistry);
  });

  // ...........................................................................
  tearDown(() async {
    await d.delete(recursive: true);
  });

  // ...........................................................................
  group('IsInRegistry', () {
    group('get(...)', () {
      test('returns true when the registry has at least one version', () async {
        mockRegistryVersions([Version(1, 0, 0)]);

        final result = await isInRegistry.get(directory: d, ggLog: ggLog);

        expect(result, isTrue);
      });

      test('returns false when the package was never published', () async {
        mockRegistryVersions(<Version>[]);

        final result = await isInRegistry.get(directory: d, ggLog: ggLog);

        expect(result, isFalse);
      });

      test('returns false when the package has no public registry', () async {
        mockRegistryVersions(null);

        final result = await isInRegistry.get(directory: d, ggLog: ggLog);

        expect(result, isFalse);
      });
    });

    group('inRegistry(...)', () {
      test('returns null when the package has no public registry', () async {
        mockRegistryVersions(null);

        final result = await isInRegistry.inRegistry(
          directory: d,
          ggLog: ggLog,
        );

        expect(result, isNull);
      });

      test('returns false when the package was never published', () async {
        mockRegistryVersions(<Version>[]);

        final result = await isInRegistry.inRegistry(
          directory: d,
          ggLog: ggLog,
        );

        expect(result, isFalse);
      });

      test('returns true when the registry has versions', () async {
        mockRegistryVersions([Version(1, 0, 0), Version(2, 0, 0)]);

        final result = await isInRegistry.inRegistry(
          directory: d,
          ggLog: ggLog,
        );

        expect(result, isTrue);
      });
    });

    group('exec(...)', () {
      test('logs a success when the package is in the registry', () async {
        mockRegistryVersions([Version(1, 0, 0)]);

        await runner.run(['is-in-registry', '--input', d.path]);

        expect(messages.first, contains('⌛️ Is available on the registry.'));
        expect(messages.last, contains('✓ Is available on the registry.'));
      });

      test('logs a failure when the package is not in the registry', () async {
        mockRegistryVersions(<Version>[]);

        final result = await isInRegistry.exec(directory: d, ggLog: ggLog);

        expect(result, isFalse);
        expect(messages.last, contains('✗ Is available on the registry.'));
      });
    });

    test('has a code coverage of 100%', () {
      expect(IsInRegistry(ggLog: ggLog), isNotNull);
    });
  });
}
