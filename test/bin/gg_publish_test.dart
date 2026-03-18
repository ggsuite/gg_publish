// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:test/test.dart';

import '../../bin/gg_publish.dart';

void main() {
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
