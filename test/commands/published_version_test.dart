// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;

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
    await Process.run('cp', ['-r', samplePackage.path, tmp.path]);
    d = Directory('${tmp.path}/sample_package');

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
          test('with a mocked response', () async {
            initCommand();

            // Create a smple package directory
            // Read published_version_sample_response.json
            final sampleResponse = await File(
              'test/sample_package/pub_dev_sample_response.json',
            ).readAsString();

            // http.Response with sampleResponse as body
            final response = http.Response(sampleResponse, 200);

            // Mock http client
            final uri = Uri.parse('https://pub.dev/api/packages/gg_check');
            when(() => client.get(uri)).thenAnswer((_) async => response);

            // Call get
            final version = await publishedVersion.get(
              directory: d,
              ggLog: messages.add,
            );

            // Was the correct version returned?
            expect(version, Version(1, 0, 2));
          });

          test('with a real response', () async {
            final publishedVersion = PublishedVersion(ggLog: messages.add);

            try {
              // Call get
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
                  'Exception while getting the latest version from pub.dev',
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

            // Mock http client: Package does not exist
            final uri = Uri.parse('https://pub.dev/api/packages/gg_check');
            final response = http.Response('', 404);
            when(() => client.get(uri)).thenAnswer((_) async => response);

            // Set a git version
            await addAndCommitVersions(
              d,
              pubspec: '1.2.3',
              changeLog: '1.2.3',
              gitHead: '2.0.0', // This version should be returned
            );

            // Request the result
            final result = await publishedVersion.get(
              directory: d,
              ggLog: messages.add,
            );
            expect(result, Version(2, 0, 0));
          });

          test('when pubspec.yaml contains publish_to: none', () async {
            initCommand();
            await initGit(d);

            // Set a git version
            await addAndCommitVersions(
              d,
              pubspec: '1.2.3',
              changeLog: '1.2.3',
              gitHead: '2.0.0', // This version should be returned
              appendToPubspec: '\npublish_to: none',
            );

            // Request the result
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

            // Mock http client: Package does not exist
            final uri = Uri.parse('https://pub.dev/api/packages/gg_check');
            final response = http.Response('', 404);
            when(() => client.get(uri)).thenAnswer((_) async => response);

            // Set a git version
            await addAndCommitVersions(
              d,
              pubspec: '1.2.3',
              changeLog: '1.2.3',
              gitHead: null, // No git tag
            );

            // Request the result
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
          // Call get
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

          // Create a smple package directory
          final pubspec = File('${d.path}/pubspec.yaml');
          pubspec.writeAsStringSync('name:');

          // Call get
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

          // Mock http client
          final uri = Uri.parse('https://pub.dev/api/packages/gg_check');
          when(() => client.get(uri)).thenThrow(Exception('error'));

          // Call get
          expect(
            () => publishedVersion.get(directory: d, ggLog: messages.add),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains(
                  'Exception while getting the latest version from pub.dev',
                ),
              ),
            ),
          );
        });

        test('when the http response status code is not 200', () {
          initCommand();

          // Mock http client
          final uri = Uri.parse('https://pub.dev/api/packages/gg_check');
          final response = http.Response('', 406);
          when(() => client.get(uri)).thenAnswer((_) async => response);

          // Call get
          expect(
            () => publishedVersion.get(directory: d, ggLog: messages.add),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                'Error 406 while getting the latest version from pub.dev',
              ),
            ),
          );
        });

        test('when the http response body does not contain "latest"', () {
          initCommand();
          // Mock http client
          final uri = Uri.parse('https://pub.dev/api/packages/gg_check');
          final response = http.Response('{"xyz":{}}', 200);
          when(() => client.get(uri)).thenAnswer((_) async => response);

          // Call get
          expect(
            () => publishedVersion.get(directory: d, ggLog: messages.add),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                'Response from pub.dev does not contain "latest"',
              ),
            ),
          );
        });

        test('when the http response body does not contain "version"', () {
          initCommand();

          // Mock http client
          final uri = Uri.parse('https://pub.dev/api/packages/gg_check');
          final response = http.Response('{"latest":{}}', 200);
          when(() => client.get(uri)).thenAnswer((_) async => response);

          // Call get
          expect(
            () => publishedVersion.get(directory: d, ggLog: messages.add),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                'Response from pub.dev does not contain "version"',
              ),
            ),
          );
        });
      });
    });

    group('run()', () {
      test('should log the version', () async {
        initCommand();

        // Mock http client
        final uri = Uri.parse('https://pub.dev/api/packages/gg_check');
        final response = http.Response('{"latest":{"version":"1.0.2"}}', 200);
        when(() => client.get(uri)).thenAnswer((_) async => response);

        // Create a smple package directory
        final pubspec = File('${d.path}/pubspec.yaml');
        pubspec.writeAsStringSync('name: gg_check');

        // Call run
        await runner.run(['published-version', '--input', d.path]);

        // Was the correct version logged?
        expect(messages.last, '1.0.2');
      });
    });
  });
}
