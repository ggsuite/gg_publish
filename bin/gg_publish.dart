#!/usr/bin/env dart
// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_args/gg_args.dart';
import 'package:gg_publish/gg_publish.dart';

// .............................................................................
Future<void> run({
  required List<String> args,
  required void Function(String msg) log,
}) =>
    GgCommandRunner(
      log: log,
      command: GgPublish(log: log),
    ).run(args: args);

// .............................................................................
Future<void> main(List<String> args) async {
  await run(
    args: args,
    log: (msg) => print(msg),
  );
}
