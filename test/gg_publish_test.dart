// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:gg_capture_print/gg_capture_print.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:test/test.dart';
import 'package:gg_args/gg_args.dart';

void main() {
  final messages = <String>[];

  setUp(() {
    messages.clear();
  });

  group('GgPublish()', () {
    // #########################################################################
    group('GgPublish', () {
      final ggPublish = GgPublish(ggLog: (msg) => messages.add(msg));

      final CommandRunner<void> runner = CommandRunner<void>(
        'ggPublish',
        'Description goes here.',
      )..addCommand(ggPublish);

      test('should allow to run the code from command line', () async {
        await capturePrint(
          ggLog: messages.add,
          code: () async =>
              await runner.run(['ggPublish', 'is-published', '--help']),
        );
        expect(
          messages.last,
          contains(
            'Checks if the current application state is fully published.',
          ),
        );
      });

      // .......................................................................
      test('should show all sub commands', () async {
        final (subCommands, errorMessage) = await missingSubCommands(
          directory: Directory('lib/src/commands'),
          command: ggPublish,
        );

        expect(subCommands, isEmpty, reason: errorMessage);
      });
    });
  });
}
