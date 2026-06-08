// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_lang/gg_lang.dart';
import 'package:gg_process/gg_process.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;

import '../test_helpers.dart';

class MockClient extends Mock implements http.Client {}

void main() {
  late Directory d;
  late MockClient client;
  late CommandRunner<dynamic> runner;
  late PublishedVersion publishedVersion;
  final messages = <String>[];

  // ...........................................................................
  void initCommand() {
    publishedVersion = PublishedVersion(
      ggLog: messages.add,
      httpClient: client,
    );
    runner = CommandRunner<dynamic>('test', 'test')
      ..addCommand(publishedVersion);
  }

  // ...........................................................................
  setUp(() async {
    messages.clear();
    final samplePackage = Directory('test/sample_package');
    final tmp = await initTestDir();
    d = Directory('${tmp.path}/sample_package');
    if (!d.existsSync()) {
      d.createSync(recursive: true);
    }
    await copyDirectory(samplePackage, d);

    client = MockClient();
  });

  // ...........................................................................
  tearDown(() {
    d.parent.deleteSync(recursive: true);
  });

  // ...........................................................................
  group('PublishedVersion', () {
    group('get(...)', () {
      group('should return the version ', () {
        group('of the published package', () {
          test('with a mocked response (Dart / pub.dev)', () async {
            initCommand();

            final sampleResponse = await File(
              'test/sample_package/pub_dev_sample_response.json',
            ).readAsString();
            final response = http.Response(sampleResponse, 200);

            final uri = Uri.parse('https://pub.dev/api/packages/gg_check');
            when(() => client.get(uri)).thenAnswer((_) async => response);

            final version = await publishedVersion.get(
              directory: d,
              ggLog: messages.add,
            );

            expect(version, Version(1, 0, 2));
          });

          test('with a mocked response (TypeScript / npm)', () async {
            // A TypeScript project resolves its version via `npm view`.
            final tsDir = Directory('${d.parent.path}/ts_pkg')
              ..createSync(recursive: true);
            File(
              '${tsDir.path}/package.json',
            ).writeAsStringSync('{"name": "ts_pkg", "version": "0.0.1"}');
            File('${tsDir.path}/tsconfig.json').writeAsStringSync('{}');

            final wrapper = MockGgProcessWrapper();
            when(
              () => wrapper.run(
                any(),
                any(),
                runInShell: any(named: 'runInShell'),
              ),
            ).thenAnswer((_) async => ProcessResult(0, 0, '7.8.9\n', ''));

            final pv = PublishedVersion(
              ggLog: messages.add,
              registryFactory: RegistryFactory(processWrapper: wrapper),
            );

            final version = await pv.get(directory: tsDir, ggLog: messages.add);
            expect(version, Version(7, 8, 9));
          });

          test('with a real response', () async {
            final publishedVersion = PublishedVersion(ggLog: messages.add);

            try {
              final version = await publishedVersion.get(
                directory: d,
                ggLog: messages.add,
              );

              expect(version >= Version(1, 0, 0), true);
            }
            // Throws when no internet is available
            catch (e) {
              expect(
                e.toString().contains(
                  'Exception while getting the latest version from the '
                  'registry',
                ),
                true,
              );

              print(e);
            }
          });
        });

        group('of the git tag', () {
          test('when the package is not yet published', () async {
            initCommand();
            await initGit(d);

            final uri = Uri.parse('https://pub.dev/api/packages/gg_check');
            final response = http.Response('', 404);
            when(() => client.get(uri)).thenAnswer((_) async => response);

            await addAndCommitVersions(
              d,
              pubspec: '1.2.3',
              changeLog: '1.2.3',
              gitHead: '2.0.0', // This version should be returned
            );

            final result = await publishedVersion.get(
              directory: d,
              ggLog: messages.add,
            );
            expect(result, Version(2, 0, 0));
          });

          test('when pubspec.yaml contains publish_to: none', () async {
            initCommand();
            await initGit(d);

            await addAndCommitVersions(
              d,
              pubspec: '1.2.3',
              changeLog: '1.2.3',
              gitHead: '2.0.0', // This version should be returned
              appendToPubspec: '\npublish_to: none',
            );

            final result = await publishedVersion.get(
              directory: d,
              ggLog: messages.add,
            );
            expect(result, Version(2, 0, 0));
          });
        });

        group('0.0.0', () {
          test('when the package is neither published on pub.dev '
              'nor has a git tag', () async {
            initCommand();
            await initGit(d);

            final uri = Uri.parse('https://pub.dev/api/packages/gg_check');
            final response = http.Response('', 404);
            when(() => client.get(uri)).thenAnswer((_) async => response);

            await addAndCommitVersions(
              d,
              pubspec: '1.2.3',
              changeLog: '1.2.3',
              gitHead: null, // No git tag
            );

            final result = await publishedVersion.get(
              directory: d,
              ggLog: messages.add,
            );
            expect(result, Version(0, 0, 0));
          });
        });
      });

      group('should throw', () {
        test('when directory does not contain a pubspec.yaml', () async {
          initCommand();
          await File(join(d.path, 'pubspec.yaml')).delete();
          expect(
            () async =>
                await publishedVersion.get(directory: d, ggLog: messages.add),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                'pubspec.yaml not found',
              ),
            ),
          );
        });

        test('when pubspec.yaml does not contain a name field', () {
          initCommand();

          final pubspec = File('${d.path}/pubspec.yaml');
          pubspec.writeAsStringSync('name:');

          expect(
            () => publishedVersion.get(directory: d, ggLog: messages.add),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                'name not found in pubspec.yaml',
              ),
            ),
          );
        });

        test('when the http request fails', () {
          initCommand();

          final uri = Uri.parse('https://pub.dev/api/packages/gg_check');
          when(() => client.get(uri)).thenThrow(Exception('error'));

          expect(
            () => publishedVersion.get(directory: d, ggLog: messages.add),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains(
                  'Exception while getting the latest version from the '
                  'registry',
                ),
              ),
            ),
          );
        });

        test('when the http response status code is not 200', () {
          initCommand();

          final uri = Uri.parse('https://pub.dev/api/packages/gg_check');
          final response = http.Response('', 406);
          when(() => client.get(uri)).thenAnswer((_) async => response);

          expect(
            () => publishedVersion.get(directory: d, ggLog: messages.add),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                allOf(contains('registry'), contains('406')),
              ),
            ),
          );
        });

        test('when the response body does not contain the version', () {
          initCommand();
          final uri = Uri.parse('https://pub.dev/api/packages/gg_check');
          final response = http.Response('{"xyz":{}}', 200);
          when(() => client.get(uri)).thenAnswer((_) async => response);

          expect(
            () => publishedVersion.get(directory: d, ggLog: messages.add),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains(
                  'Exception while getting the latest version from the '
                  'registry',
                ),
              ),
            ),
          );
        });
      });
    });

    group('run()', () {
      test('should log the version', () async {
        initCommand();

        final uri = Uri.parse('https://pub.dev/api/packages/gg_check');
        final response = http.Response('{"latest":{"version":"1.0.2"}}', 200);
        when(() => client.get(uri)).thenAnswer((_) async => response);

        final pubspec = File('${d.path}/pubspec.yaml');
        pubspec.writeAsStringSync('name: gg_check');

        await runner.run(['published-version', '--input', d.path]);

        expect(messages.last, '1.0.2');
      });
    });
  });
}
