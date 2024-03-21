// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_process/gg_process.dart';
import 'package:gg_publish/src/commands/is_upgraded.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

void main() {
  // ...........................................................................
  late Directory d;
  late IsUpgraded isUpgraded;
  late MockGgProcessWrapper mockProcessWrapper;
  late CommandRunner<void> runner;
  final messages = <String>[];

  // ...........................................................................
  void mockIsUpgraded(bool isUpgraded, {String system = 'dart'}) {
    when(
      () => mockProcessWrapper.run(
        system,
        ['pub', 'outdated'],
        runInShell: true,
        workingDirectory: d.path,
      ),
    ).thenAnswer(
      (_) async => ProcessResult(
        0,
        0,
        isUpgraded ? 'Found no outdated packages' : 'Found outdated packages',
        '',
      ),
    );
  }

  // ...........................................................................
  void mockDartPubOutdatedFails(String system) {
    when(
      () => mockProcessWrapper.run(
        system,
        ['pub', 'outdated'],
        runInShell: true,
        workingDirectory: d.path,
      ),
    ).thenAnswer(
      (_) async => ProcessResult(
        1,
        1,
        '',
        'Error message.',
      ),
    );
  }

  // ...........................................................................
  void initCommand({
    GgProcessWrapper? processWrapper,
  }) {
    isUpgraded = IsUpgraded(
      log: messages.add,
      processWrapper: processWrapper ?? mockProcessWrapper,
    );

    runner.addCommand(isUpgraded);
  }

  // ...........................................................................
  setUp(() {
    mockProcessWrapper = MockGgProcessWrapper();
    messages.clear();
    runner = CommandRunner<void>('test', 'test');
    d = Directory.systemTemp.createTempSync();
  });

  // ...........................................................................
  tearDown(() {
    d.deleteSync(recursive: true);
  });

  // ...........................................................................
  Future<void> initPubSpecYaml({required bool isFlutter}) async {
    final pubspec = File('${d.path}/pubspec.yaml');
    var content = '';

    if (isFlutter) {
      content += '\n  flutter: ';
      content += '\n    sdk: flutter: ';
    }
    await pubspec.writeAsString(content);
  }

  // ...........................................................................
  group('IsUpgraded', () {
    group('run()', () {
      group('should print »✅ Everything is upgraded«', () {
        test('when everything is upgraded', () async {
          initCommand();
          await initPubSpecYaml(isFlutter: false);
          mockIsUpgraded(true);
          await runner.run(['is-upgraded', '--input', d.path]);
          expect(messages.first, contains('⌛️ Everything is upgraded.'));
          expect(messages.last, contains('✅ Everything is upgraded.'));
        });
      });

      group('should print »❌ Everything is upgraded.«', () {
        test('when outdated packages are found', () async {
          initCommand();
          await initPubSpecYaml(isFlutter: false);
          mockIsUpgraded(false);
          await runner.run(['is-upgraded', '--input', d.path]);
          expect(messages.first, contains('⌛️ Everything is upgraded.'));
          expect(messages.last, contains('❌ Everything is upgraded.'));
        });
      });
    });
    group('get(directory: d)', () {
      group('should throw', () {
        test('when directory does not contain a pubspec.yaml file', () async {
          initCommand();
          await expectLater(
            isUpgraded.get(directory: d),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('Exception: pubspec.yaml not found'),
              ),
            ),
          );
        });

        group('when dart pub outdated fails', () {
          for (final system in ['dart', 'flutter']) {
            test('for $system', () async {
              bool isFlutter = system == 'flutter';
              await initPubSpecYaml(isFlutter: isFlutter);
              initCommand(processWrapper: mockProcessWrapper);
              mockDartPubOutdatedFails(system);

              await expectLater(
                isUpgraded.get(directory: d),
                throwsA(
                  isA<Exception>().having(
                    (e) => e.toString(),
                    'message',
                    contains(
                      'Exception: Error while checking for outdated packages: '
                      'Error message.',
                    ),
                  ),
                ),
              );
            });
          }
        });
      });

      group('should return true', () {
        test('when »dart pub outdated« returns »Found no outdated packages«',
            () async {
          await initPubSpecYaml(isFlutter: false);
          initCommand(processWrapper: mockProcessWrapper);
          mockIsUpgraded(true);
          expect(await isUpgraded.get(directory: d), isTrue);
        });
      });

      group('should return false', () {
        test('when »dart pub outdated« returns another message', () async {
          await initPubSpecYaml(isFlutter: false);
          initCommand(processWrapper: mockProcessWrapper);
          mockIsUpgraded(false);
          expect(await isUpgraded.get(directory: d), isFalse);
        });
      });
    });
  });
}
