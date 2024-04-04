// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

// ignore_for_file: unawaited_futures

import 'dart:io';

import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_process/gg_process.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:gg_version/gg_version.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

void main() {
  final messages = <String>[];
  final ggLog = messages.add;
  late Directory d;
  late Publish publish;
  late GgProcessWrapper processWrapper;
  late GgFakeProcess process;
  late IsVersionPrepared isVersionPrepared;
  late String? stdInValue;

  // ...........................................................................
  void mockIsVersionPrepared(bool value) {
    when(() {
      when(
        () => isVersionPrepared.get(
          ggLog: ggLog,
          directory: d,
        ),
      ).thenAnswer((_) => Future.value(value));
    });
  }

  // ...........................................................................
  void mockProcess({int result = 0}) {
    // Mock the process
    processWrapper = MockGgProcessWrapper();

    when(
      () => processWrapper.start(
        'dart',
        ['pub', 'publish'],
        workingDirectory: d.path,
      ),
    ).thenAnswer(
      (_) => Future.value(process),
    );
  }

  // ...........................................................................
  setUp(() async {
    messages.clear();
    d = await Directory.systemTemp.createTemp();
    await initGit(d);
    await addAndCommitSampleFile(d);
    process = GgFakeProcess();
    mockProcess();
    isVersionPrepared = MockIsVersionPrepared();
    publish = Publish(
      ggLog: ggLog,
      processWrapper: processWrapper,
      isVersionPrepared: isVersionPrepared,
      readLineFromStdIn: () => stdInValue,
    );
  });

  // ...........................................................................
  tearDown(() async {
    await d.delete(recursive: true);
  });

  // ...........................................................................
  group('Publish', () {
    group('exec(directory, ggLog)', () {
      group('should publish', () {
        test('and log the ongoing process live', () async {
          // Setup consistent versions
          mockIsVersionPrepared(true);

          // Start the process
          bool isDone = false;
          publish.exec(directory: d, ggLog: ggLog).then(
                (value) => isDone = true,
              );
          await Future<void>.delayed(Duration.zero);

          // Let the process output some message
          process.pushToStdout.add('Something happens.');
          await Future<void>.delayed(Duration.zero);

          // It should be logged
          expect(messages.last, contains('Something happens.'));

          // Let the process not fail
          process.exit(0);
          await Future<void>.delayed(Duration.zero);

          expect(isDone, isTrue);
        });

        test('and ask the user for confirmation', () async {
          // Setup consistent versions
          mockIsVersionPrepared(true);

          // Start the process
          bool isDone = false;
          publish.exec(directory: d, ggLog: ggLog).then(
                (value) => isDone = true,
              );
          await Future<void>.delayed(Duration.zero);

          // Answer the next question with y
          stdInValue = 'y';

          // Let the process output some message
          process.pushToStdout.add('Do you want to publish');

          await Future<void>.delayed(Duration.zero);

          // It should be logged
          expect(messages.last, contains('Do you want to publish'));

          // Let the process not fail
          process.exit(0);
          await Future<void>.delayed(Duration.zero);

          expect(isDone, isTrue);
        });
      });
      group('should throw', () {
        test('if versions are not consistent', () async {
          late String exceptionMessage;

          mockIsVersionPrepared(false);

          try {
            await publish.exec(directory: d, ggLog: ggLog);
          } on Exception catch (e) {
            exceptionMessage = e.toString();
          }

          expect(
            exceptionMessage,
            contains('Exception: Version is not prepared.'),
          );
        });

        test('if »dart pub publish« has exit code != 0', () async {
          // Setup consistent versions
          mockIsVersionPrepared(true);

          // Start the process
          late String exceptionMessage;
          publish.exec(directory: d, ggLog: ggLog).onError((error, stackTrace) {
            exceptionMessage = error.toString();
          });

          // Let the process fail
          process.exit(1);
          await Future<void>.delayed(Duration.zero);

          // Check the exception
          expect(
            exceptionMessage,
            contains('Exception: »dart pub publish« was not successful:'),
          );
        });

        test('if »dart pub publish« returns errors', () async {
          // Setup consistent versions
          mockIsVersionPrepared(true);

          // Start the process
          late String exceptionMessage;
          publish.exec(directory: d, ggLog: ggLog).onError((error, stackTrace) {
            exceptionMessage = error.toString();
          });
          await Future<void>.delayed(Duration.zero);

          // Let the process return errors
          process.pushToStderr.add('Error: Something went wrong');
          await Future<void>.delayed(Duration.zero);

          // Let the process not fail
          process.exit(0);
          await Future<void>.delayed(Duration.zero);

          // Check the exception
          expect(
            exceptionMessage,
            contains('Exception: »dart pub publish« was not successful:'),
          );

          expect(
            exceptionMessage,
            contains('Error: Something went wrong'),
          );
        });
      });
    });

    test('has a code coverage of 100%', () {
      expect(Publish(ggLog: ggLog), isNotNull);
    });
  });
}
