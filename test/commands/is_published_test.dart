// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_capture_print/gg_capture_print.dart';
import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;

// .............................................................................
/// A Mock for the http.Client class using Mocktail
class MockClient extends Mock implements http.Client {}

void main() {
  final messages = <String>[];
  late CommandRunner<void> runner;
  late IsPublished isPublished;
  late Directory tmp;
  late Directory d;
  late http.Client httpClient;

  // ...........................................................................
  Future<void> initIsPublished() async {
    isPublished = IsPublished(
      ggLog: messages.add,
      publishedVersion: PublishedVersion(
        ggLog: messages.add,
        httpClient: httpClient,
      ),
    );
    runner.addCommand(isPublished);
  }

  // ...........................................................................
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp();
    d = Directory('${tmp.path}/test');
    await d.create();

    messages.clear();
    runner = CommandRunner<void>('test', 'test');
    httpClient = MockClient();
    await initIsPublished();
    await initGit(d);
  });

  // ...........................................................................
  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  group('IsPublisehd', () {
    group('get(...)', () {
      // .......................................................................
      group('should return false ', () {
        test('when the package cannot be found on pub.dev', () async {
          // Mock a package with name test
          final pubspecYamlFile = File('${d.path}/pubspec.yaml');
          pubspecYamlFile.writeAsStringSync('name: test');

          // Mock package test is not on pub.dev
          final responseContent =
              File('test/sample_package/pub_dev_404_response.json')
                  .readAsStringSync();
          final uri = Uri.parse('https://pub.dev/api/packages/test');
          when(() => httpClient.get(uri)).thenAnswer(
            (_) async => http.Response(responseContent, 404),
          );

          // Check if the package is published
          final result = await isPublished.get(
            directory: d,
            ggLog: messages.add,
          );

          // Package should not be published
          expect(result, isFalse);
        });
      });

      group('should return true', () {
        test('when the package canbe found on pub.dev ', () async {
          await initGit(d);

          // Mock a package with name test
          final pubspecYamlFile = File('${d.path}/pubspec.yaml');
          pubspecYamlFile.writeAsStringSync('name: test');

          // Mock a test is published on pub.dev
          final responseContent =
              File('test/sample_package/pub_dev_sample_response.json')
                  .readAsStringSync();
          final uri = Uri.parse('https://pub.dev/api/packages/test');
          when(() => httpClient.get(uri)).thenAnswer(
            (_) async => http.Response(responseContent, 200),
          );

          // Call isPublished.get()
          final result =
              await isPublished.get(directory: d, ggLog: messages.add);

          expect(result, isTrue);
        });
      });
    });
    group('run()', () {
      group('should print', () {
        group('a usage description', () {
          test('when called with --help', () async {
            capturePrint(
              ggLog: messages.add,
              code: () => runner.run(
                ['--help'],
              ),
            );

            expect(messages.last, contains('Available commands:'));
            expect(messages.last, contains(isPublished.name));
            expect(messages.last, contains(isPublished.description));
          });
        });

        group('the current version', () {
          test('when called without arguments', () async {
            await initGit(d);

            await addAndCommitVersions(
              d,
              pubspec: '1.0.2',
              changeLog: '1.0.2',
              gitHead: '1.0.2',
            );

            // Mock published version 1.0.2
            final responseContent =
                File('test/sample_package/pub_dev_sample_response.json')
                    .readAsStringSync();
            final uri = Uri.parse('https://pub.dev/api/packages/test');
            when(() => httpClient.get(uri)).thenAnswer(
              (_) async => http.Response(responseContent, 200),
            );

            // Call isPublished.run()
            await runner.run(
              ['is-published', '--input', d.path],
            );

            expect(
              messages.last,
              contains('✅ Was published to pub.dev before.'),
            );
          });
        });
      });

      group('should throw', () {
        group(' an error message', () {
          test('when called with an invalid argument', () async {
            await expectLater(
              runner.run(
                ['is-published', '--input', 'xyz'],
              ),
              throwsA(
                isA<ArgumentError>().having(
                  (e) => e.toString(),
                  'toString()',
                  contains(
                    'Invalid argument(s): Directory "xyz" does not exist.',
                  ),
                ),
              ),
            );
          });
        });
      });
    });

    test('should have a coverage of 100%', () {
      expect(IsPublished(ggLog: messages.add), isNotNull);
    });
  });
}
