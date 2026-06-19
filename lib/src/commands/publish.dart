// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';
import 'dart:convert';

import 'package:gg_args/gg_args.dart';
import 'package:gg_console_colors/gg_console_colors.dart';
import 'package:gg_lang/gg_lang.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_process/gg_process.dart';
import 'package:gg_publish/gg_publish.dart';
import 'package:gg_status_printer/gg_status_printer.dart';

// #############################################################################
/// Base class for all ggGit commands
class Publish extends DirCommand<void> {
  /// Constructor
  Publish({
    required super.ggLog,
    super.description = 'Publishes the current directory to its registry.',
    super.name = 'publish',
    IsVersionPrepared? isVersionPrepared,
    GgProcessWrapper processWrapper = const GgProcessWrapper(),
    String? Function()? readLineFromStdIn,
    LanguageCatalog? catalog,
  }) : _isVersionPrepared =
           isVersionPrepared ?? IsVersionPrepared(ggLog: ggLog),
       _processWrapper = processWrapper,
       _catalog = catalog,
       _readLineFromStdIn = readLineFromStdIn ?? stdin.readLineSync {
    _addArgs();
  }

  /// The language catalog used to resolve the publish command. Defaults to the
  /// bundled gg_lang catalog when null.
  final LanguageCatalog? _catalog;

  // ...........................................................................
  @override
  Future<void> exec({
    required Directory directory,
    required GgLog ggLog,
    bool? askBeforePublishing,
  }) async => get(
    directory: directory,
    ggLog: ggLog,
    askBeforePublishing: askBeforePublishing,
  );

  // ...........................................................................
  @override
  Future<void> get({
    required Directory directory,
    required GgLog ggLog,
    bool? askBeforePublishing,
  }) async {
    // final messages = <String>[];

    final printer = GgStatusPrinter<void>(
      message: 'Publishing',
      ggLog: ggLog,
      useCarriageReturn: false,
    );

    await printer.logTask(
      task: () => _exec(
        ggLog: ggLog,
        directory: directory,
        askBeforePublishing: askBeforePublishing ?? _askBeforePublishing,
      ),
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
    required bool askBeforePublishing,
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
    await _publish(directory, ggLog, askBeforePublishing);
  }

  // ...........................................................................
  Future<void> _publish(
    Directory directory,
    GgLog ggLog,
    bool askBeforePublishing,
  ) async {
    final errors = <String>[];
    // A bounded tail of all output so a failure is never reported with an
    // empty message, even when the tool writes its error to stdout.
    final outputTail = <String>[];

    // Bridges (pubspec + package.json) are published as TypeScript.
    final type = checkProjectType(directory);
    final isDart = type.isDartFamily;

    final String executable;
    final List<String> args;
    final bool runInShell;
    if (isDart) {
      final catalog = _catalog ?? await LanguageCatalog.load();
      final command = catalog.spec(type).command('publish');
      executable = command.exec ?? command.tool!;
      args = <String>[
        ...command.args,
        // `dart pub publish` prompts unless forced.
        if (!askBeforePublishing) '--force',
      ];
      runInShell = command.runInShell;
    } else {
      // TypeScript: publish with the project's actual package manager
      // (pnpm/yarn/npm) instead of a hardcoded `npm publish`, so pnpm
      // workspaces / .npmrc and `--no-git-checks` are respected.
      final publish = detectTypeScriptPackageManager(directory).publishCommand;
      executable = publish.executable;
      args = publish.args;
      runInShell = true;
    }

    final process = runInShell
        ? await _processWrapper.start(
            executable,
            args,
            workingDirectory: directory.path,
            runInShell: true,
          )
        : await _processWrapper.start(
            executable,
            args,
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
      _rememberOutput(outputTail, s);
    });

    final s1 = process.stderr.transform(utf8.decoder).listen((s) {
      errors.add(red(s));
      _rememberOutput(outputTail, s);
    });

    // Wait until process is finished
    final exitCode = await process.exitCode;
    await s0.cancel();
    await s1.cancel();

    if (exitCode != 0 || errors.isNotEmpty) {
      // Never swallow the cause: report the command, its exit code, and the
      // captured output (stderr, or the stdout tail when stderr is empty).
      final detail = errors.isNotEmpty
          ? errors.join('\n')
          : outputTail.join().trim();
      throw Exception(
        '»$executable ${args.join(' ')}« failed with exit code $exitCode'
        '${detail.isEmpty ? '' : ':\n$detail'}',
      );
    }
  }

  // ...........................................................................
  /// Appends [chunk] to [tail], keeping only the most recent output so the
  /// failure message stays bounded.
  static void _rememberOutput(List<String> tail, String chunk) {
    tail.add(chunk);
    const maxChunks = 40;
    if (tail.length > maxChunks) {
      tail.removeRange(0, tail.length - maxChunks);
    }
  }

  // ...........................................................................
  bool get _askBeforePublishing =>
      argResults?['ask-before-publishing'] as bool? ?? true;

  // ...........................................................................
  void _addArgs() {
    argParser.addFlag(
      'ask-before-publishing',
      abbr: 'a',
      help: 'Ask for confirmation before publishing to pub.dev.',
      defaultsTo: true,
      negatable: true,
    );
  }
}

// .............................................................................
/// A Mock for the Publish class using Mocktail
class MockPublish extends MockDirCommand<void> implements Publish {}
