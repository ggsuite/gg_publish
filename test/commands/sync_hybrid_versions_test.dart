// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:gg_version/gg_version.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

void main() {
  final messages = <String>[];
  final ggLog = messages.add;
  late Directory d;
  late MockWriteVersionFile writeVersionFile;
  late SyncHybridVersions sync;

  // ...........................................................................
  void writePubspec(String version) {
    File(
      '${d.path}/pubspec.yaml',
    ).writeAsStringSync('name: foo\nversion: $version\n');
  }

  void writePackageJson(String version) {
    File('${d.path}/package.json').writeAsStringSync(
      '{\n  "name": "@org/foo",\n  "version": "$version"\n}\n',
    );
  }

  String pubspecVersion() => File('${d.path}/pubspec.yaml')
      .readAsStringSync()
      .split('\n')
      .firstWhere((l) => l.startsWith('version:'))
      .replaceFirst('version:', '')
      .trim();

  String packageJsonVersion() => RegExp(
    r'"version":\s*"([^"]+)"',
  ).firstMatch(File('${d.path}/package.json').readAsStringSync())!.group(1)!;

  // ...........................................................................
  setUp(() async {
    messages.clear();
    d = await Directory.systemTemp.createTemp('gg_sync_hybrid_versions_');
    writeVersionFile = MockWriteVersionFile();
    registerFallbackValue(d);
    when(
      () => writeVersionFile.apply(
        directory: any(named: 'directory'),
        ggLog: any(named: 'ggLog'),
        version: any(named: 'version'),
      ),
    ).thenAnswer((_) async => <File>[]);
    sync = SyncHybridVersions(ggLog: ggLog, writeVersionFile: writeVersionFile);
  });

  // ...........................................................................
  tearDown(() {
    if (d.existsSync()) d.deleteSync(recursive: true);
  });

  // ###########################################################################
  group('SyncHybridVersions', () {
    group('apply(directory, ggLog)', () {
      test('returns null for a package without a package.json', () async {
        writePubspec('1.0.0');
        expect(await sync.apply(directory: d, ggLog: ggLog), isNull);
      });

      test('returns null for a package without a pubspec.yaml', () async {
        writePackageJson('1.0.0');
        expect(await sync.apply(directory: d, ggLog: ggLog), isNull);
      });

      test('returns null when a version cannot be parsed', () async {
        writePubspec('not-a-version');
        writePackageJson('1.0.0');
        expect(await sync.apply(directory: d, ggLog: ggLog), isNull);
      });

      test('changes nothing when both versions agree', () async {
        writePubspec('1.0.1');
        writePackageJson('1.0.1');

        final result = await sync.apply(directory: d, ggLog: ggLog);

        expect(result?.changed, isFalse);
        expect(result?.version.toString(), '1.0.1');
        verifyNever(
          () => writeVersionFile.apply(
            directory: any(named: 'directory'),
            ggLog: any(named: 'ggLog'),
            version: any(named: 'version'),
          ),
        );
      });

      test('writes the higher pubspec version into both manifests', () async {
        // The ds_dna case.
        writePubspec('1.0.2');
        writePackageJson('1.0.1');

        final result = await sync.apply(directory: d, ggLog: ggLog);

        expect(result?.changed, isTrue);
        expect(result?.version.toString(), '1.0.2');
        expect(pubspecVersion(), '1.0.2');
        expect(packageJsonVersion(), '1.0.2');
      });

      test('writes the higher package.json version into both', () async {
        writePubspec('1.0.1');
        writePackageJson('2.0.0');

        final result = await sync.apply(directory: d, ggLog: ggLog);

        expect(result?.changed, isTrue);
        expect(result?.version.toString(), '2.0.0');
        expect(pubspecVersion(), '2.0.0');
        expect(packageJsonVersion(), '2.0.0');
      });

      test('regenerates the version files with the winning version', () async {
        writePubspec('1.0.2');
        writePackageJson('1.0.1');

        await sync.apply(directory: d, ggLog: ggLog);

        verify(
          () => writeVersionFile.apply(
            directory: any(named: 'directory'),
            ggLog: any(named: 'ggLog'),
            version: '1.0.2',
          ),
        ).called(1);
      });

      test('reports what it changed', () async {
        writePubspec('1.0.2');
        writePackageJson('1.0.1');

        await sync.apply(directory: d, ggLog: ggLog);

        expect(
          messages.last,
          contains(
            'pubspec.yaml (1.0.2) and package.json (1.0.1) carried different '
            'versions — both set to 1.0.2.',
          ),
        );
      });
    });

    // .........................................................................
    group('get(directory, ggLog)', () {
      test('returns true when the manifests had to be changed', () async {
        writePubspec('1.0.2');
        writePackageJson('1.0.1');
        expect(await sync.get(directory: d, ggLog: ggLog), isTrue);
      });

      test('returns false when they already agree', () async {
        writePubspec('1.0.1');
        writePackageJson('1.0.1');
        expect(await sync.get(directory: d, ggLog: ggLog), isFalse);
      });

      test('returns false for a non-hybrid', () async {
        writePubspec('1.0.1');
        expect(await sync.get(directory: d, ggLog: ggLog), isFalse);
      });
    });

    // .........................................................................
    group('as a cli command', () {
      test('runs on the given directory', () async {
        writePubspec('1.0.2');
        writePackageJson('1.0.1');

        final runner = CommandRunner<dynamic>('test', 'test')
          ..addCommand(sync as Command<dynamic>);
        await runner.run(['sync-hybrid-versions', '--input', d.path]);

        expect(pubspecVersion(), '1.0.2');
        expect(packageJsonVersion(), '1.0.2');
      });
    });

    // .........................................................................
    test('creates its own WriteVersionFile by default', () {
      expect(SyncHybridVersions(ggLog: ggLog), isNotNull);
    });

    test('MockSyncHybridVersions can be created', () {
      expect(MockSyncHybridVersions(), isA<SyncHybridVersions>());
    });
  });
}
