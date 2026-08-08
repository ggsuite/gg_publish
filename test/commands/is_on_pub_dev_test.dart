// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_git/gg_git_test_helpers.dart';
import 'package:gg_lang/gg_lang.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:test/test.dart';

/// Mock for [PublishTo].
class MockPublishTo extends Mock implements PublishTo {}

void main() {
  late Directory d;
  late IsOnPubDev isOnPubDev;
  late void Function(Set<PublishTarget>) mockTargets;
  late PublishTo publishTo;
  final messages = <String>[];
  // Strip the colors and the overwrite sequence so the expectations assert
  // the text. One closure instance — mocktail matches ggLog by identity.
  // ignore: prefer_function_declarations_over_variables
  final GgLog ggLog = (String msg) => messages.add(rmControls(msg));

  setUp(() async {
    messages.clear();
    d = await initTestDir();
    await initGit(d);
    publishTo = MockPublishTo();
    mockTargets = (Set<PublishTarget> targets) =>
        when(() => publishTo.targets(d)).thenAnswer((_) async => targets);
    isOnPubDev = IsOnPubDev(ggLog: ggLog, publishTo: publishTo);
    registerFallbackValue(d);
  });

  tearDown(() async {
    await d.delete(recursive: true);
  });

  group('IsOnPubDev', () {
    group('constructor', () {
      test('should create publishTo command by default', () {
        expect(() => IsOnPubDev(ggLog: ggLog), returnsNormally);
      });
    });

    group('get(directory, ggLog)', () {
      test('should return true when publish target is pub.dev', () async {
        mockTargets({PublishTarget.pubDev});

        final result = await isOnPubDev.get(directory: d, ggLog: ggLog);

        expect(result, isTrue);
        verify(() => publishTo.targets(d)).called(1);
      });

      test('should return false when publish target is none', () async {
        mockTargets(<PublishTarget>{});

        final result = await isOnPubDev.get(directory: d, ggLog: ggLog);

        expect(result, isFalse);
        verify(() => publishTo.targets(d)).called(1);
      });

      test('should return false for an npm-only package', () async {
        mockTargets({PublishTarget.npm});

        final result = await isOnPubDev.get(directory: d, ggLog: ggLog);

        expect(result, isFalse);
        verify(() => publishTo.targets(d)).called(1);
      });

      test('should return true for a hybrid publishing to both', () async {
        // A package.json next to the pubspec does not take the package off
        // pub.dev - only »publish_to: none« does.
        mockTargets({PublishTarget.pubDev, PublishTarget.npm});

        final result = await isOnPubDev.get(directory: d, ggLog: ggLog);

        expect(result, isTrue);
      });
    });

    group('exec(directory, ggLog)', () {
      test('should print success when package is on pub.dev', () async {
        mockTargets({PublishTarget.pubDev});

        final result = await isOnPubDev.exec(directory: d, ggLog: ggLog);

        expect(result, isTrue);
        expect(messages.first, contains('⌛️ Package is on pub.dev.'));
        expect(messages.last, contains('✓ Package is on pub.dev.'));
      });

      test('should print failure when package is not on pub.dev', () async {
        mockTargets(<PublishTarget>{});

        final result = await isOnPubDev.exec(directory: d, ggLog: ggLog);

        expect(result, isFalse);
        expect(messages.first, contains('⌛️ Package is on pub.dev.'));
        expect(messages.last, contains('✗ Package is on pub.dev.'));
      });
    });
  });
}
