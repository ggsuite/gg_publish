// @license
// Copyright (c) 2025 Göran Hegenberg. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:gg_args/gg_args.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:gg_status_printer/gg_status_printer.dart';

/// Checks whether the package repository is published on pub.dev.
class IsOnPubDev extends DirCommand<bool> {
  /// Creates the command instance.
  IsOnPubDev({required super.ggLog, PublishTo? publishTo})
    : _publishTo = publishTo ?? PublishTo(ggLog: ggLog),
      super(
        name: 'is-on-pub-dev',
        description: 'Checks if the current package is published on pub.dev.',
      );

  final PublishTo _publishTo;

  @override
  Future<bool> exec({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    final messages = <String>[];

    final printer = GgStatusPrinter<bool>(
      message: 'Package is on pub.dev.',
      ggLog: ggLog,
    );

    return printer.logTask(
      task: () => get(directory: directory, ggLog: messages.add),
      success: (success) => success,
    );
  }

  /// Returns `true` when the package publishes to pub.dev.
  @override
  Future<bool> get({required GgLog ggLog, required Directory directory}) async {
    final publishTarget = await _publishTo.fromDirectory(directory);
    return publishTarget == 'pub.dev';
  }
}

/// Mock implementation of [IsOnPubDev].
class MockIsOnPubDev extends MockDirCommand<bool> implements IsOnPubDev {}
