// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../bin/gg_publish.dart';

void main() {
  group('bin/gg_publish.dart', () {
    // #########################################################################

    test('should be executable', () async {
      // Execute bin/gg_publish.dart and check if it prints help
      final result = await Process.run(
        './bin/gg_publish.dart',
        ['is-latest-state-published'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      final stdout = result.stdout as String;

      expect(stdout, contains('Current state has no git version tag.'));
    });
  });

  // ###########################################################################
  group('run(args, log)', () {
    group('with args=[--input, xyz]', () {
      test(
        'should print "Invalid argument(s): Directory xyz does not exist."',
        () async {
          // Execute bin/gg_publish.dart and check if it prints "value"
          final messages = <String>[];
          await run(
            args: ['is-published', '--input', 'xyz'],
            ggLog: messages.add,
          );

          expect(
            messages.last,
            'Invalid argument(s): Directory xyz does not exist.',
          );
        },
      );
    });
  });
}
