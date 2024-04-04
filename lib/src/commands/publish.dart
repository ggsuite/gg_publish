// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';
import 'dart:convert';

import 'package:gg_args/gg_args.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_process/gg_process.dart';
import 'package:gg_status_printer/gg_status_printer.dart';
import 'package:gg_version/gg_version.dart';
import 'package:mocktail/mocktail.dart' as mocktail;

// #############################################################################
/// Base class for all ggGit commands
class Publish extends DirCommand<void> {
  /// Constructor
  Publish({
    required super.ggLog,
    super.description = 'Publishes the current directory to pub.dev.',
    super.name = 'publish',
    IsVersionPrepared? isVersionPrepared,
    GgProcessWrapper processWrapper = const GgProcessWrapper(),
    String? Function()? readLineFromStdIn,
  })  : _isVersionPrepared =
            isVersionPrepared ?? IsVersionPrepared(ggLog: ggLog),
        _processWrapper = processWrapper,
        _readLineFromStdIn = readLineFromStdIn ?? stdin.readLineSync;

  // ...........................................................................
  @override
  Future<void> exec({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    // final messages = <String>[];

    final printer = GgStatusPrinter<void>(
      message: 'Publishing',
      ggLog: ggLog,
      useCarriageReturn: false,
    );

    await printer.logTask(
      task: () => _exec(ggLog: ggLog, directory: directory),
      success: (success) => true,
    );
  }

  // ######################
  // Private
  // ######################

  final IsVersionPrepared _isVersionPrepared;
  final GgProcessWrapper _processWrapper;
  final String? Function() _readLineFromStdIn;

  // ...........................................................................
  Future<void> _exec({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    // Is version prepared?
    final isVersionPrepared = await _isVersionPrepared.get(
      ggLog: ggLog,
      directory: directory,
    );
    if (!isVersionPrepared) {
      throw Exception('Version is not prepared.');
    }

    // Publish
    await _publish(directory, ggLog);
  }

  // ...........................................................................
  Future<void> _publish(Directory directory, GgLog ggLog) async {
    final errors = <String>[];

    final process = await _processWrapper.start(
      'dart',
      ['pub', 'publish'],
      workingDirectory: directory.path,
    );

    // Log the output
    final s0 = process.stdout.transform(utf8.decoder).listen((s) {
      if (s.contains('Do you want to publish')) {
        ggLog(yellow(s));
        final answer = _readLineFromStdIn();
        process.stdin.writeln(answer);
      } else {
        ggLog(darkGray(s));
      }
    });

    final s1 = process.stderr.transform(utf8.decoder).listen((s) {
      errors.add(red(s));
    });

    // Wait until process is finished
    final exitCode = await process.exitCode;
    await s0.cancel();
    await s1.cancel();

    if (exitCode != 0 || errors.isNotEmpty) {
      throw Exception(
        "»dart pub publish« was not successful: ${errors.join('\n')}",
      );
    }
  }
}

// .............................................................................
/// A Mock for the Publish class using Mocktail
class MockPublish extends mocktail.Mock implements Publish {}
