// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_version/gg_version.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;

class MockClient extends Mock implements http.Client {}

void main() {
  late Directory d;
  late Directory tmp;
  late MockClient client;
  late CommandRunner<void> runner;
  late PublishedVersion publishedVersion;
  final messages = <String>[];

  // ...........................................................................
  void initCommand() {
    publishedVersion = PublishedVersion(
      ggLog: messages.add,
      httpClient: client,
    );
    runner = CommandRunner<void>('test', 'test')..addCommand(publishedVersion);
  }

  // ...........................................................................
  setUp(() {
    messages.clear();
    d = Directory('test/sample_package');
    tmp = Directory.systemTemp.createTempSync();

    client = MockClient();
  });

  // ...........................................................................
  tearDown(() {
    tmp.deleteSync(recursive: true);
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
            final sampleResponse =
                await File('test/sample_package/pub_dev_sample_response.json')
                    .readAsString();

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
            final publishedVersion = PublishedVersion(
              ggLog: messages.add,
            );

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
      });

      group('should throw', () {
        test('when directory does not contain a pubspec.yaml', () {
          initCommand();
          // Call get
          expect(
            () => publishedVersion.get(directory: tmp, ggLog: messages.add),
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
          final pubspec = File('${tmp.path}/pubspec.yaml');
          pubspec.writeAsStringSync('name:');

          // Call get
          expect(
            () => publishedVersion.get(directory: tmp, ggLog: messages.add),
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
            () => publishedVersion.get(
              directory: d,
              ggLog: messages.add,
            ),
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
            () => publishedVersion.get(
              directory: d,
              ggLog: messages.add,
            ),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                'Error 406 while getting the latest version from pub.dev',
              ),
            ),
          );
        });

        test('when the package is not yet published', () {
          initCommand();

          // Mock http client
          final uri = Uri.parse('https://pub.dev/api/packages/gg_check');
          final response = http.Response('', 404);
          when(() => client.get(uri)).thenAnswer((_) async => response);

          // Call get
          expect(
            () => publishedVersion.get(
              directory: d,
              ggLog: messages.add,
            ),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                'Exception: '
                    'Error 404: The package gg_check is not yet published.',
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
            () => publishedVersion.get(
              directory: d,
              ggLog: messages.add,
            ),
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
            () => publishedVersion.get(
              directory: d,
              ggLog: messages.add,
            ),
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
        final pubspec = File('${tmp.path}/pubspec.yaml');
        pubspec.writeAsStringSync('name: gg_check');

        // Call run
        await runner.run(['published-version', '--input', tmp.path]);

        // Was the correct version logged?
        expect(messages.last, '1.0.2');
      });
    });
  });
}
