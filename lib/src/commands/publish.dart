// @license
// Copyright (c) ggsuite
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
import 'package:pub_semver/pub_semver.dart';

// #############################################################################
/// Base class for all ggGit commands
class Publish extends DirCommand<void> {
  /// Constructor
  Publish({
    required super.ggLog,
    super.description = 'Publishes the current directory to its registry.',
    super.name = 'publish',
    IsVersionPrepared? isVersionPrepared,
    RemoveVersionTag? removeVersionTag,
    GgProcessWrapper processWrapper = const GgProcessWrapper(),
    String? Function()? readLineFromStdIn,
    LanguageCatalog? catalog,
    PublishedVersion? publishedVersion,
  }) : _isVersionPrepared =
           isVersionPrepared ?? IsVersionPrepared(ggLog: ggLog),
       _publishedVersion = publishedVersion ?? PublishedVersion(ggLog: ggLog),
       _removeVersionTag =
           removeVersionTag ??
           RemoveVersionTag(
             ggLog: ggLog,
             processWrapper: processWrapper,
             catalog: catalog,
           ),
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
  final PublishedVersion _publishedVersion;
  final RemoveVersionTag _removeVersionTag;
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

    // At least one version must already be on the registry: a first-time
    // publish needs authentication, access rights and the package creation
    // to be sorted out with the registry interactively — the user does that
    // manually, gg continues afterwards.
    final publishedManually = await _ensureFirstVersionIsInRegistry(
      directory: directory,
      ggLog: ggLog,
    );

    // A previous publish may have failed after tagging the release. That tag
    // points at a commit this run replaces, so remove it locally and on the
    // remote — the tag step of the publish flow recreates it on the new
    // release commit.
    await _removeVersionTag.get(directory: directory, ggLog: ggLog);

    // Publish. When the user just published the current version manually,
    // uploading it again would be rejected by the registry.
    if (!publishedManually) {
      await _publish(directory, ggLog, askBeforePublishing);
    }
  }

  // ...........................................................................
  /// Makes sure at least one version of the package is available on its
  /// registry. When the package was never published, the user is asked to
  /// publish the first version manually directly out of the current working
  /// folder; gg continues after the user confirmed. Returns true when the
  /// user published the current version manually this way — the automated
  /// upload must be skipped then. Packages without a public registry are
  /// not checked.
  Future<bool> _ensureFirstVersionIsInRegistry({
    required Directory directory,
    required GgLog ggLog,
  }) async {
    final versions = await _publishedVersion.registryVersions(
      directory: directory,
    );

    // Packages without a public registry (null) have nothing to check;
    // packages with at least one published version are fine as well.
    if (versions == null || versions.isNotEmpty) {
      return false;
    }

    final type = checkProjectType(directory);
    final registry = type.isDartFamily ? 'pub.dev' : 'npm';
    final name = await _packageName(directory);

    ggLog(
      yellow(
        '»$name« has no version published on $registry yet.\n'
        'Please publish the first version manually directly out of the '
        'current working folder:',
      ),
    );
    ggLog(blue('  cd ${directory.absolute.path}'));
    ggLog(blue('  ${await _manualPublishCommand(directory, type)}'));

    while (true) {
      ggLog(yellow('Press ⏎ once the package is published, »q« + ⏎ to abort.'));
      final answer = (_readLineFromStdIn() ?? '').trim().toLowerCase();
      if (answer == 'q') {
        throw Exception(
          'Publishing aborted: »$name« has no version on $registry.',
        );
      }

      final versionsNow =
          await _publishedVersion.registryVersions(directory: directory) ??
          <Version>[];

      if (versionsNow.isNotEmpty) {
        ggLog(yellow('»$name« is now available on $registry. Continuing.'));

        // Only when the user published the *current* version the automated
        // upload has to be skipped. A different version (e.g. an earlier
        // one) still needs the regular upload — which works now that the
        // package exists on the registry.
        final catalog = _catalog ?? await LanguageCatalog.load();
        final currentVersion = await Manifest.detect(
          directory,
          catalog,
          treatBridgeAsTypeScript: true,
        ).readVersion();
        return versionsNow.contains(currentVersion);
      }

      ggLog(
        yellow(
          '»$name« is not yet visible on $registry. A fresh publish can '
          'take a few minutes to appear. Please try again.',
        ),
      );
    }
  }

  // ...........................................................................
  /// The name of the package in [directory], read from its manifest.
  Future<String> _packageName(Directory directory) async {
    final catalog = _catalog ?? await LanguageCatalog.load();
    return await Manifest.detect(
      directory,
      catalog,
      treatBridgeAsTypeScript: true,
    ).readName();
  }

  // ...........................................................................
  /// The shell command the user executes to publish the package manually.
  /// Dart/Flutter packages publish with the catalog's publish command, npm
  /// packages with pnpm.
  Future<String> _manualPublishCommand(
    Directory directory,
    ProjectType type,
  ) async {
    if (type.isDartFamily) {
      final catalog = _catalog ?? await LanguageCatalog.load();
      return catalog.spec(type).command('publish').label;
    }

    // A scoped package is private by default on npm — the first publish is
    // rejected without »--access public«. »--no-git-checks« is needed
    // because gg publishes from a feature branch.
    final name = await _packageName(directory);
    final access = name.startsWith('@') ? ' --access public' : '';
    final distTag = await _npmDistTagArgs(directory);
    final tag = distTag.isEmpty ? '' : ' ${distTag.join(' ')}';
    return 'pnpm publish --no-git-checks$access$tag';
  }

  // ...........................................................................
  Future<void> _publish(
    Directory directory,
    GgLog ggLog,
    bool askBeforePublishing,
  ) async {
    // Bridges (pubspec + package.json) are published as TypeScript.
    final type = checkProjectType(directory);

    if (type == ProjectType.none) {
      throw Exception(
        'A project without a manifest publishes to git only — '
        'there is no registry to publish to.',
      );
    }

    if (type.isDartFamily) {
      final catalog = _catalog ?? await LanguageCatalog.load();
      final command = catalog.spec(type).command('publish');
      final executable = command.exec ?? command.tool!;

      // Validate first: a dry run surfaces pub's warnings without uploading
      // anything. Only when it is clean do we publish for real - and then with
      // `--skip-validation`, because the validation already happened here and
      // rerunning it would just repeat the same checks.
      await _dryRun(directory, ggLog, executable, <String>[
        ...command.args,
        '--dry-run',
      ], command.runInShell);

      await _publishCaptured(directory, ggLog, executable, <String>[
        ...command.args,
        '--skip-validation',
        // `dart pub publish` prompts unless forced.
        if (!askBeforePublishing) '--force',
      ], command.runInShell);
    } else {
      // TypeScript: publish with the project's actual package manager
      // (pnpm/yarn/npm), and run it *interactively* by inheriting the
      // terminal's stdio. gg cannot feed a rotating 2FA one-time password into
      // a captured pipe — pnpm even refuses OTP when non-interactive
      // (ERR_PNPM_OTP_NON_INTERACTIVE) — so we let the package manager drive
      // its own OTP / browser-login flow directly against the terminal.
      final publish = detectTypeScriptPackageManager(directory).publishCommand;
      await _publishInteractive(directory, publish.executable, <String>[
        ...publish.args,
        ...await _npmDistTagArgs(directory),
      ]);
    }
  }

  // ...........................................................................
  /// Runs the publish command with `--dry-run` and breaks the publish flow
  /// when the validation reports a warning. The warning is printed in red,
  /// with the paths it mentions highlighted in blue.
  Future<void> _dryRun(
    Directory directory,
    GgLog ggLog,
    String executable,
    List<String> args,
    bool runInShell,
  ) async {
    final result = await _processWrapper.run(
      executable,
      args,
      workingDirectory: directory.path,
      runInShell: runInShell,
    );

    // pub writes the validation report to stderr, but not every tool does -
    // inspect both streams.
    final output = '${result.stdout}\n${result.stderr}';
    final warning = _extractWarning(output);

    if (warning != null) {
      ggLog(red(_highlightPaths(warning)));
      throw Exception(
        'Publishing was stopped because »$executable ${args.join(' ')}« '
        'reported a warning. Fix it, or exclude the files using a '
        '.pubignore.',
      );
    }

    if (result.exitCode != 0) {
      final detail = output.trim();
      throw Exception(
        '»$executable ${args.join(' ')}« failed with exit code '
        '${result.exitCode}${detail.isEmpty ? '' : ':\n$detail'}',
      );
    }
  }

  // ...........................................................................
  /// Returns the warning block of a `--dry-run` [output], or null when the
  /// dry run reported no warnings.
  static String? _extractWarning(String output) {
    final lines = output.split('\n');
    final start = lines.indexWhere(
      (l) => l.contains('Package validation found the following'),
    );
    if (start == -1) {
      // A summary without a report still means the package is not clean.
      // »Package has 0 warnings.« is the clean case and must not break.
      for (final line in lines) {
        final match = RegExp(r'Package has (\d+) warning').firstMatch(line);
        if (match != null && match[1] != '0') {
          return line.trim();
        }
      }
      return null;
    }

    // The report ends where pub starts summarizing again.
    final end = lines.indexWhere(
      (l) => l.contains('The server may enforce additional checks'),
      start,
    );

    final block = lines.sublist(start, end == -1 ? lines.length : end);
    return block.join('\n').trim();
  }

  // ...........................................................................
  /// Colors every path-like token of [text] blue, so the offending files stand
  /// out within the red warning.
  static String _highlightPaths(String text) => text.replaceAllMapped(
    RegExp(r'[^\s`]+'),
    (match) {
      final token = match[0]!;
      final isPath =
          token.contains('/') || RegExp(r'^\.?[\w-]+\.[\w-]+$').hasMatch(token);
      return isPath ? blue(token) : token;
    },
  );

  // ...........................................................................
  /// Publishes by capturing the tool's output live. Used for Dart/Flutter,
  /// where gg answers the »Do you want to publish« confirmation from stdin and
  /// surfaces the captured output (stderr, or the stdout tail) on failure.
  Future<void> _publishCaptured(
    Directory directory,
    GgLog ggLog,
    String executable,
    List<String> args,
    bool runInShell,
  ) async {
    final errors = <String>[];
    // A bounded tail of all output so a failure is never reported with an
    // empty message, even when the tool writes its error to stdout.
    final outputTail = <String>[];

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

    // Only the exit code decides success. `dart pub` writes progress and
    // informational notices to stderr - e.g. »Running with `skip-validation`«
    // - so a non-empty stderr on its own must not turn a successful publish
    // into a failure.
    if (exitCode != 0) {
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
  /// Publishes interactively by inheriting the terminal's stdio, so the
  /// package manager can prompt for a 2FA one-time password or open its
  /// browser login itself. gg does not capture the output in this mode — the
  /// tool writes straight to the terminal — so only the exit code is inspected.
  Future<void> _publishInteractive(
    Directory directory,
    String executable,
    List<String> args,
  ) async {
    final process = await _processWrapper.start(
      executable,
      args,
      workingDirectory: directory.path,
      runInShell: true,
      mode: ProcessStartMode.inheritStdio,
    );

    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw Exception(
        '»$executable ${args.join(' ')}« failed with exit code $exitCode',
      );
    }
  }

  // ...........................................................................
  /// Returns `--tag <identifier>` when the manifest version is a prerelease
  /// (e.g. `--tag rc` for `1.2.0-rc.1`). Without it, npm would move the
  /// `latest` dist-tag onto the prerelease, so consumers would install it by
  /// default and the next stable release would be computed from it.
  Future<List<String>> _npmDistTagArgs(Directory directory) async {
    final catalog = _catalog ?? await LanguageCatalog.load();
    final version = await Manifest.detect(
      directory,
      catalog,
      treatBridgeAsTypeScript: true,
    ).readVersion();

    if (version.preRelease.isEmpty) return [];
    return ['--tag', version.preRelease.first.toString()];
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
