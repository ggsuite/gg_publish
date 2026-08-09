// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_lang/gg_lang.dart';
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
  /// Makes every registry report [versions].
  void mockRegistryVersions(List<Version>? versions) {
    when(
      () =>
          publishedVersion.registryVersions(directory: any(named: 'directory')),
    ).thenAnswer((_) async => versions);
    when(
      () => publishedVersion.registryVersionsFor(
        target: any(named: 'target'),
        directory: any(named: 'directory'),
      ),
    ).thenAnswer((_) async => versions);
  }

  // ...........................................................................
  /// Makes only [target] report [versions]; the other registry reports none.
  void mockRegistryVersionsFor(PublishTarget target, List<Version> versions) {
    when(
      () => publishedVersion.registryVersionsFor(
        target: any(named: 'target'),
        directory: any(named: 'directory'),
      ),
    ).thenAnswer((invocation) async {
      final asked = invocation.namedArguments[#target] as PublishTarget;
      return asked == target ? versions : <Version>[];
    });
  }

  // ...........................................................................
  /// Writes the manifests that decide which registries the package has.
  void writeManifests({String? publishTo, bool packageJson = false}) {
    File('${d.path}/pubspec.yaml').writeAsStringSync(
      'name: foo\n'
      'version: 1.0.0\n'
      '${publishTo == null ? '' : 'publish_to: $publishTo\n'}',
    );
    if (packageJson) {
      File(
        '${d.path}/package.json',
      ).writeAsStringSync('{"name": "@org/foo", "version": "1.0.0"}');
    }
  }

  // ...........................................................................
  setUp(() async {
    messages.clear();
    d = await Directory.systemTemp.createTemp();
    publishedVersion = MockPublishedVersion();
    registerFallbackValue(d);
    registerFallbackValue(PublishTarget.pubDev);
    // By default the package publishes to pub.dev only.
    writeManifests();
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
        writeManifests(publishTo: 'none');
        mockRegistryVersions(null);

        final result = await isInRegistry.get(directory: d, ggLog: ggLog);

        expect(result, isFalse);
      });
    });

    group('inRegistry(...)', () {
      test('returns null when the package has no public registry', () async {
        writeManifests(publishTo: 'none');
        mockRegistryVersions(null);

        final result = await isInRegistry.inRegistry(
          directory: d,
          ggLog: ggLog,
        );

        expect(result, isNull);
      });

      test('returns false when only one registry of a hybrid has it', () async {
        // A hybrid that is on npm but was never released to pub.dev must not
        // sail past the first-publish gate and then die inside
        // »dart pub publish«.
        writeManifests(packageJson: true);
        mockRegistryVersionsFor(PublishTarget.npm, [Version(1, 0, 0)]);

        final result = await isInRegistry.inRegistry(
          directory: d,
          ggLog: ggLog,
        );

        expect(result, isFalse);
      });

      test('returns true when both registries of a hybrid have it', () async {
        writeManifests(packageJson: true);
        mockRegistryVersions([Version(1, 0, 0)]);

        final result = await isInRegistry.inRegistry(
          directory: d,
          ggLog: ggLog,
        );

        expect(result, isTrue);
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

    group('missingTargets(...)', () {
      test('returns null when the package has no public registry', () async {
        writeManifests(publishTo: 'none');
        mockRegistryVersions(null);

        expect(await isInRegistry.missingTargets(directory: d), isNull);
      });

      test('names the registry that has never seen the package', () async {
        writeManifests(packageJson: true);
        mockRegistryVersionsFor(PublishTarget.npm, [Version(1, 0, 0)]);

        expect(await isInRegistry.missingTargets(directory: d), <PublishTarget>{
          PublishTarget.pubDev,
        });
      });

      test('is empty when every registry has the package', () async {
        writeManifests(packageJson: true);
        mockRegistryVersions([Version(1, 0, 0)]);

        expect(await isInRegistry.missingTargets(directory: d), isEmpty);
      });
    });

    test('has a code coverage of 100%', () {
      expect(IsInRegistry(ggLog: ggLog), isNotNull);
    });
  });
}
