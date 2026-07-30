// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_lang/gg_lang.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

void main() {
  late Directory d;
  final messages = <String>[];
  final ggLog = messages.add;
  late MockRegistryWaiter waiter;
  late WaitUntilPublished waitUntilPublished;

  // ...........................................................................
  Future<void> initPubspec({String? publishTo}) async {
    var pubspecContent = 'name: test_pkg\nversion: 1.2.3';
    if (publishTo != null) {
      pubspecContent += '\npublish_to: $publishTo';
    }
    await File('${d.path}/pubspec.yaml').writeAsString(pubspecContent);
  }

  // ...........................................................................
  setUp(() async {
    d = await initTestDir();
    messages.clear();
    waiter = MockRegistryWaiter();
    when(
      () => waiter.waitUntilVersionAvailable(
        packageName: any(named: 'packageName'),
        version: any(named: 'version'),
      ),
    ).thenAnswer((_) async {});
    waitUntilPublished = WaitUntilPublished(ggLog: ggLog, waiter: waiter);
  });

  tearDown(() async {
    await d.delete(recursive: true);
  });

  group('WaitUntilPublished', () {
    group('get(directory, ggLog)', () {
      test('waits for the manifest version on the registry', () async {
        await initPubspec();
        await waitUntilPublished.get(directory: d, ggLog: ggLog);
        verify(
          () => waiter.waitUntilVersionAvailable(
            packageName: 'test_pkg',
            version: '1.2.3',
          ),
        ).called(1);
      });

      test('can be called from the command line', () async {
        await initPubspec();
        final runner = CommandRunner<void>('test', 'test')
          ..addCommand(waitUntilPublished);
        await runner.run(['wait-until-published', '--input', d.path]);
        verify(
          () => waiter.waitUntilVersionAvailable(
            packageName: 'test_pkg',
            version: '1.2.3',
          ),
        ).called(1);
      });

      test('skips packages that are not published to a registry', () async {
        await initPubspec(publishTo: 'none');
        await waitUntilPublished.get(directory: d, ggLog: ggLog);
        verifyNever(
          () => waiter.waitUntilVersionAvailable(
            packageName: any(named: 'packageName'),
            version: any(named: 'version'),
          ),
        );
      });

      test('forwards timeout errors from the waiter', () async {
        await initPubspec();
        when(
          () => waiter.waitUntilVersionAvailable(
            packageName: any(named: 'packageName'),
            version: any(named: 'version'),
          ),
        ).thenThrow(Exception('Timed out'));
        await expectLater(
          waitUntilPublished.get(directory: d, ggLog: ggLog),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Timed out'),
            ),
          ),
        );
      });

      test('waits on npm for a TypeScript package', () async {
        File('${d.path}/package.json').writeAsStringSync(
          '{"name": "@scope/ts_pkg", "version": "2.0.0", "private": false}',
        );
        File('${d.path}/tsconfig.json').writeAsStringSync('{}');
        await waitUntilPublished.get(directory: d, ggLog: ggLog);
        verify(
          () => waiter.waitUntilVersionAvailable(
            packageName: '@scope/ts_pkg',
            version: '2.0.0',
          ),
        ).called(1);
      });

      test('has sensible default timeouts', () {
        final command = WaitUntilPublished(ggLog: ggLog);
        expect(command.timeout, const Duration(minutes: 15));
        expect(command.pollInterval, const Duration(seconds: 10));
      });
    });
  });
}
