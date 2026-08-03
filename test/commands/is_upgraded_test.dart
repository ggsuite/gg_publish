// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_process/gg_process.dart';
import 'package:gg_publish/src/commands/is_upgraded.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:test/test.dart';
import 'package:gg_console_colors/gg_console_colors.dart';

void main() {
  // ...........................................................................
  late Directory d;
  late IsUpgraded isUpgraded;
  late MockGgProcessWrapper mockProcessWrapper;
  late CommandRunner<dynamic> runner;
  final messages = <String>[];
  // Strip the colors and the overwrite sequence so the expectations assert
  // the text. One closure instance — mocktail matches ggLog by identity.
  // ignore: prefer_function_declarations_over_variables
  final GgLog ggLog = (String msg) => messages.add(rmControls(msg));
  const sampleDir = 'test/sample_package/';

  String read(String file) => File('$sampleDir/$file').readAsStringSync();

  final responseNotUpgradedAndNotResolved = read(
    'upgrade_not_upgraded_and_not_resolved.json',
  );
  final responseUpgradedAndResolved = read(
    'upgrade_upgraded_and_resolved.json',
  );
  final responseUpgradedButNotResolved = read(
    'upgrade_upgraded_but_not_resolved.json',
  );
  final responseUptodate = read('upgrade_uptodate.json');

  // ...........................................................................
  void mockDartPubOutdated(String response, {String system = 'dart'}) {
    when(
      () => mockProcessWrapper.run(
        system,
        ['pub', 'outdated', '--json'],
        runInShell: true,
        workingDirectory: d.path,
      ),
    ).thenAnswer((_) async => ProcessResult(0, 0, response, ''));
  }

  // ...........................................................................
  void mockDartPubOutdatedFails(String system) {
    when(
      () => mockProcessWrapper.run(
        system,
        ['pub', 'outdated', '--json'],
        runInShell: true,
        workingDirectory: d.path,
      ),
    ).thenAnswer((_) async => ProcessResult(1, 1, '', 'Error message.'));
  }

  // ...........................................................................
  void initCommand({GgProcessWrapper? processWrapper}) {
    isUpgraded = IsUpgraded(
      ggLog: ggLog,
      processWrapper: processWrapper ?? mockProcessWrapper,
    );

    runner.addCommand(isUpgraded);
  }

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
  setUp(() async {
    mockProcessWrapper = MockGgProcessWrapper();
    messages.clear();
    runner = CommandRunner<dynamic>('test', 'test');
    d = Directory.systemTemp.createTempSync();
    registerFallbackValue(d);
    initCommand();
    await initPubSpecYaml(isFlutter: false);
  });

  // ...........................................................................
  tearDown(() {
    d.deleteSync(recursive: true);
  });

  // ...........................................................................
  void expectSuccess() {
    expect(messages.first, contains('⌛️ Everything is upgraded.'));
    expect(messages.last, contains('✓ Everything is upgraded.'));
  }

  // ...........................................................................
  void expectFail() {
    expect(messages.first, contains('⌛️ Everything is upgraded.'));
    expect(messages.last, contains('✗ Everything is upgraded.'));
  }

  // ...........................................................................
  Future<void> viaCli({bool majorVersions = false}) async {
    await runner.run([
      'is-upgraded',
      '--input',
      d.path,
      if (majorVersions) '--major-versions',
    ]);
  }

  // ...........................................................................
  Future<void> viaExec({bool? majorVersions}) async {
    await isUpgraded.exec(
      directory: d,
      ggLog: ggLog,
      majorVersions: majorVersions,
    );
  }

  // ...........................................................................
  group('IsUpgraded', () {
    group('- without a pubspec.yaml', () {
      test('should skip the check and print ✓', () async {
        File('${d.path}/pubspec.yaml').deleteSync();
        await viaCli();
        expectSuccess();
      });
    });

    group('- standard case', () {
      group('- up to date? ', () {
        setUp(() async {
          mockDartPubOutdated(responseUptodate);
        });

        group('with --major-versions', () {
          group('should print ✓', () {
            test('- with CLI', () async {
              await viaCli(majorVersions: true);
              expectSuccess();
            });
            test('- programmatically', () async {
              await viaExec(majorVersions: true);
            });
          });
        });

        group('without --major-versions', () {
          group('should print ✓', () {
            test('- with CLI', () async {
              await viaCli();
              expectSuccess();
            });
            test('- programmatically', () async {
              await viaExec();
            });
          });
        });

        group('- upgraded but not resolved? ', () {
          setUp(() async {
            mockDartPubOutdated(responseUpgradedButNotResolved);
          });

          group('with --major-versions', () {
            group('should print ✗', () {
              test('- with CLI', () async {
                await viaCli(majorVersions: true);
                expectFail();
              });
              test('- programmatically', () async {
                await viaExec(majorVersions: true);
                expectFail();
              });
            });
          });
          group('without --major-versions', () {
            group('should print ✓', () {
              test('- with CLI', () async {
                await viaCli(majorVersions: false);
                expectSuccess();
              });
              test('- programmatically', () async {
                await viaExec(majorVersions: false);
                expectSuccess();
              });
            });
          });
        });

        group('- not upgraded and not resolved? ', () {
          setUp(() async {
            mockDartPubOutdated(responseNotUpgradedAndNotResolved);
          });

          group('with --major-versions', () {
            group('should print ✗', () {
              test('- with CLI', () async {
                await viaCli(majorVersions: true);
                expectFail();
              });
              test('- programmatically', () async {
                await viaExec(majorVersions: true);
                expectFail();
              });
            });
          });
          group('without --major-versions', () {
            group('should print ✗', () {
              test('- with CLI', () async {
                await viaCli(majorVersions: false);
                expectFail();
              });
              test('- programmatically', () async {
                await viaExec(majorVersions: false);
                expectFail();
              });
            });
          });
        });

        group('- upgraded and resolved? ', () {
          setUp(() async {
            mockDartPubOutdated(responseUpgradedAndResolved);
          });

          group('with --major-versions', () {
            group('should print ✓', () {
              test('- with CLI', () async {
                await viaCli(majorVersions: true);
                expectSuccess();
              });
              test('- programmatically', () async {
                await viaExec(majorVersions: true);
                expectSuccess();
              });
            });
          });
          group('without --major-versions', () {
            group('should print ✓', () {
              test('- with CLI', () async {
                await viaCli(majorVersions: false);
                expectSuccess();
              });
              test('- programmatically', () async {
                await viaExec(majorVersions: false);
                expectSuccess();
              });
            });
          });
        });
      });
    });

    group('- special cases', () {
      group('should throw', () {
        test('if the json cannot be parsed', () async {
          mockDartPubOutdated('djfkd089034 afädf');
          late String exception;
          try {
            await viaExec(majorVersions: false);
          } catch (e) {
            exception = rmC(e.toString());
          }
          expect(exception, contains('Could not parse the response'));
        });

        test('if the process fails', () async {
          mockDartPubOutdatedFails('dart');
          late String exception;
          try {
            await viaExec(majorVersions: false);
          } catch (e) {
            exception = rmC(e.toString());
          }
          expect(exception, contains('Failed to check for outdated packages.'));
        });
      });
    });
  });
}
