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
    PublishTo? publishTo,
    NpmRegistryResolver? npmRegistryResolver,
  }) : _isVersionPrepared =
           isVersionPrepared ?? IsVersionPrepared(ggLog: ggLog),
       _publishedVersion = publishedVersion ?? PublishedVersion(ggLog: ggLog),
       _publishTo = publishTo ?? PublishTo(ggLog: ggLog, catalog: catalog),
       _npmRegistryResolver = npmRegistryResolver ?? NpmRegistryResolver(),
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
    Set<PublishTarget>? targets,
    Future<void> Function(PublishTarget target)? onPublished,
    Map<String, dynamic> options = const {},
  }) async => get(
    directory: directory,
    ggLog: ggLog,
    askBeforePublishing: askBeforePublishing,
    targets: targets,
    onPublished: onPublished,
  );

  // ...........................................................................
  /// Uploads the package to its registries.
  ///
  /// - [targets] restricts the upload to a subset of the registries the
  ///   package publishes to. A resumed publish passes the registries that are
  ///   still open, so a registry that already accepted the version is never
  ///   uploaded twice.
  /// - [onPublished] is awaited after each registry accepted the upload. The
  ///   publish flow records its per-registry resume marker there, which is why
  ///   it has to run *between* the two uploads rather than after both: when the
  ///   second one fails, the first must already be marked as done.
  @override
  Future<void> get({
    required Directory directory,
    required GgLog ggLog,
    bool? askBeforePublishing,
    Set<PublishTarget>? targets,
    Future<void> Function(PublishTarget target)? onPublished,
  }) async {
    // The publish itself logs what it does, so only the announcement is
    // printed — dimmed, because it is not the line the user has to read. A
    // success line would repeat the announcement without adding anything;
    // only a failure is worth its own mark.
    final printer = GgStatusPrinter<void>(
      message: 'Publishing',
      ggLog: ggLog,
      useCarriageReturn: false,
      dark: true,
    );

    printer.logStatus(GgStatusPrinterStatus.running);

    try {
      await _exec(
        ggLog: ggLog,
        directory: directory,
        askBeforePublishing: askBeforePublishing ?? _askBeforePublishing,
        requested: targets,
        onPublished: onPublished,
      );
    } catch (e) {
      printer.logStatus(GgStatusPrinterStatus.error);
      rethrow;
    }
  }

  // ######################
  // Private
  // ######################

  final IsVersionPrepared _isVersionPrepared;
  final PublishedVersion _publishedVersion;
  final PublishTo _publishTo;
  final NpmRegistryResolver _npmRegistryResolver;
  final RemoveVersionTag _removeVersionTag;
  final GgProcessWrapper _processWrapper;
  final String? Function() _readLineFromStdIn;

  // ...........................................................................
  Future<void> _exec({
    required Directory directory,
    required GgLog ggLog,
    required bool askBeforePublishing,
    required Set<PublishTarget>? requested,
    required Future<void> Function(PublishTarget target)? onPublished,
  }) async {
    // Is version prepared?
    final isVersionPrepared = await _isVersionPrepared.get(
      ggLog: ggLog,
      directory: directory,
    );
    if (!isVersionPrepared) {
      throw Exception(cDetail('Version is not prepared.'));
    }

    final all = await _publishTo.targets(directory);
    // A resumed run asks for the registries that are still open; intersecting
    // keeps a caller from requesting one the package does not publish to.
    final targets = requested == null ? all : all.intersection(requested);

    if (targets.isEmpty) {
      ggLog(
        cDetail(
          'A project without a public registry publishes to git only — '
          'there is nothing to upload.',
        ),
      );
      throw Exception(cDetail('No registry to publish to.'));
    }

    // At least one version must already be on each registry: a first-time
    // publish needs authentication, access rights and the package creation
    // to be sorted out with the registry interactively — the user does that
    // manually, gg continues afterwards.
    final publishedManually = await _ensureFirstVersionIsInRegistry(
      directory: directory,
      ggLog: ggLog,
      targets: targets,
    );

    // A previous publish may have failed after tagging the release. That tag
    // points at a commit this run replaces, so remove it locally and on the
    // remote — the tag step of the publish flow recreates it on the new
    // release commit. One tag covers both registries: the two manifests of a
    // hybrid are reconciled and bumped in lock-step.
    await _removeVersionTag.get(directory: directory, ggLog: ggLog);

    final done = <PublishTarget>[];
    try {
      for (final target in targets.ordered) {
        // When the user just published the current version manually, uploading
        // it again would be rejected by the registry — but the caller still has
        // to learn that this registry is settled, or a resume would retry it.
        if (!publishedManually.contains(target)) {
          await _upload(target, directory, ggLog, askBeforePublishing);
        }
        done.add(target);
        await onPublished?.call(target);
      }
    } catch (_) {
      // Never let a partial upload read as »nothing happened«: a user who
      // restarts instead of continuing would re-upload a version the registry
      // already has, and be rejected for it.
      if (done.isNotEmpty) {
        ggLog(
          cWarn(
            'Already uploaded to ${done.map((t) => t.id).join(', ')} — '
            'that will not be repeated. Resume with '
            '"gg do publish --continue".',
          ),
        );
      }
      rethrow;
    }
  }

  // ...........................................................................
  /// Makes sure at least one version of the package is available on every
  /// registry in [targets]. When a registry has never seen the package, the
  /// user is asked to publish the first version there manually directly out of
  /// the current working folder; gg continues after the user confirmed.
  ///
  /// Returns the registries on which the user published the *current* version
  /// this way — their automated upload must be skipped, because the registry
  /// would reject it. Each registry is asked about separately: a hybrid that
  /// already lives on npm but has never been released to pub.dev needs exactly
  /// one prompt, naming the pub.dev package and the `dart pub publish` command.
  Future<Set<PublishTarget>> _ensureFirstVersionIsInRegistry({
    required Directory directory,
    required GgLog ggLog,
    required Set<PublishTarget> targets,
  }) async {
    final publishedManually = <PublishTarget>{};

    for (final target in targets.ordered) {
      final versions = await _publishedVersion.registryVersionsFor(
        target: target,
        directory: directory,
      );

      // Registries that already carry at least one version are fine.
      if (versions == null || versions.isNotEmpty) {
        continue;
      }

      if (await _promptForFirstPublish(
        directory: directory,
        ggLog: ggLog,
        target: target,
      )) {
        publishedManually.add(target);
      }
    }

    return publishedManually;
  }

  // ...........................................................................
  /// Asks the user to publish the first version to [target] manually. Returns
  /// true when the version that is about to be published showed up there, i.e.
  /// the automated upload has to be skipped.
  Future<bool> _promptForFirstPublish({
    required Directory directory,
    required GgLog ggLog,
    required PublishTarget target,
  }) async {
    final name = await _packageName(directory, target);

    ggLog(
      yellow(
        '»$name« has no version published on ${target.id} yet.\n'
        'Please publish the first version manually directly out of the '
        'current working folder:',
      ),
    );
    ggLog(blue('  cd ${directory.absolute.path}'));
    ggLog(blue('  ${await _manualPublishCommand(directory, target)}'));

    while (true) {
      ggLog(yellow('Press ⏎ once the package is published, »q« + ⏎ to abort.'));
      final answer = (_readLineFromStdIn() ?? '').trim().toLowerCase();
      if (answer == 'q') {
        ggLog(cDetail('✗ »$name« has no version on ${target.id}'));
        throw Exception(cDetail('Publishing aborted.'));
      }

      final versionsNow =
          await _publishedVersion.registryVersionsFor(
            target: target,
            directory: directory,
          ) ??
          <Version>[];

      if (versionsNow.isNotEmpty) {
        ggLog(yellow('»$name« is now available on ${target.id}. Continuing.'));

        // Only when the user published the *current* version the automated
        // upload has to be skipped. A different version (e.g. an earlier
        // one) still needs the regular upload — which works now that the
        // package exists on the registry.
        return versionsNow.contains(await _version(directory, target));
      }

      ggLog(
        yellow(
          '»$name« is not yet visible on ${target.id}. A fresh publish can '
          'take a few minutes to appear. Please try again.',
        ),
      );
    }
  }

  // ...........................................................................
  /// The name the package carries on [target] — `foo` on pub.dev, the possibly
  /// scoped `@org/foo` on npm. Naming the wrong one in a prompt is how a user
  /// ends up pasting the wrong command.
  Future<String> _packageName(
    Directory directory,
    PublishTarget target,
  ) async => (await _manifest(directory, target)).readName();

  // ...........................................................................
  /// The version [target] is about to publish, read from its own manifest.
  Future<Version> _version(Directory directory, PublishTarget target) async =>
      (await _manifest(directory, target)).readVersion();

  // ...........................................................................
  Future<Manifest> _manifest(Directory directory, PublishTarget target) async {
    final catalog = _catalog ?? await LanguageCatalog.load();
    return target.manifestIn(directory, catalog);
  }

  // ...........................................................................
  /// The shell command the user executes to publish the package to [target]
  /// manually. pub.dev uses the catalog's publish command, npm uses pnpm.
  Future<String> _manualPublishCommand(
    Directory directory,
    PublishTarget target,
  ) async {
    if (target == PublishTarget.pubDev) {
      final catalog = _catalog ?? await LanguageCatalog.load();
      return target.specIn(directory, catalog).command('publish').label;
    }

    // A scoped package is private by default on npm — the first publish is
    // rejected without »--access public«. »--no-git-checks« is needed
    // because gg publishes from a feature branch.
    final name = await _packageName(directory, target);
    final access = name.startsWith('@') ? ' --access public' : '';
    final distTag = await _npmDistTagArgs(directory);
    final tag = distTag.isEmpty ? '' : ' ${distTag.join(' ')}';

    // A private feed has to be named explicitly when the package is not
    // configured for it yet — otherwise the manual publish silently goes to
    // npmjs.com.
    final registry = await _npmRegistryResolver.registryOf(
      directory: directory,
    );
    final registryArg = registry == null || registry.contains('registry.npmjs.')
        ? ''
        : ' --registry=$registry';

    return 'pnpm publish --no-git-checks$access$tag$registryArg';
  }

  // ...........................................................................
  /// Uploads the package to one registry.
  Future<void> _upload(
    PublishTarget target,
    Directory directory,
    GgLog ggLog,
    bool askBeforePublishing,
  ) async {
    if (target == PublishTarget.pubDev) {
      final catalog = _catalog ?? await LanguageCatalog.load();
      final command = target.specIn(directory, catalog).command('publish');
      final executable = command.exec ?? command.tool!;

      // Validate first: a dry run surfaces pub's warnings without uploading
      // anything. Only when it is clean do we publish for real.
      await _dryRun(directory, ggLog, executable, <String>[
        ...command.args,
        '--dry-run',
      ], command.runInShell);

      // The real upload must NOT pass `--skip-validation`. It reads like a
      // free optimization — the dry run just validated — but it disables
      // `--force`: pub only publishes unattended »if there are no errors«,
      // and without validation it cannot establish that, so it asks for
      // confirmation and an unattended publish hangs on the prompt. Paying
      // for the second validation is what keeps the publish non-interactive.
      await _publishCaptured(directory, ggLog, executable, <String>[
        ...command.args,
        // `dart pub publish` prompts unless forced.
        if (!askBeforePublishing) '--force',
      ], command.runInShell);
      return;
    }

    // npm: publish with the project's actual package manager (pnpm/yarn/npm),
    // and run it *interactively* by inheriting the terminal's stdio. gg cannot
    // feed a rotating 2FA one-time password into a captured pipe — pnpm even
    // refuses OTP when non-interactive (ERR_PNPM_OTP_NON_INTERACTIVE) — so we
    // let the package manager drive its own OTP / browser-login flow directly
    // against the terminal.
    final publish = detectTypeScriptPackageManager(directory).publishCommand;
    await _publishInteractive(directory, publish.executable, <String>[
      ...publish.args,
      ...await _npmDistTagArgs(directory),
    ]);
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
      // The warning is the actionable part — print it once and keep the
      // exception short.
      ggLog(cDetail('✗ »$executable ${args.join(' ')}« reported a warning'));
      ggLog(cError(_highlightPaths(warning)));
      ggLog(cAction('Fix it, or exclude the files using a .pubignore.'));
      throw Exception(cDetail('Publishing was stopped by a warning.'));
    }

    if (result.exitCode != 0) {
      final detail = output.trim();
      ggLog(
        [
          cError(
            '✗ »$executable ${args.join(' ')}« failed with exit code '
            '${result.exitCode}',
          ),
          if (detail.isNotEmpty) cDetail(detail),
        ].join('\n'),
      );
      throw Exception(cDetail('Publishing failed.'));
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
      ggLog(
        [
          cError(
            '✗ »$executable ${args.join(' ')}« failed with exit code $exitCode',
          ),
          if (detail.isNotEmpty) cDetail(detail),
        ].join('\n'),
      );
      throw Exception(cDetail('Publishing failed.'));
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
      ggLog(
        cError(
          '✗ »$executable ${args.join(' ')}« failed with exit code '
          '$exitCode',
        ),
      );
      throw Exception(cDetail('Publishing failed.'));
    }
  }

  // ...........................................................................
  /// Returns `--tag <identifier>` when the `package.json` version is a
  /// prerelease (e.g. `--tag rc` for `1.2.0-rc.1`). Without it, npm would move
  /// the `latest` dist-tag onto the prerelease, so consumers would install it
  /// by default and the next stable release would be computed from it.
  Future<List<String>> _npmDistTagArgs(Directory directory) async {
    final version = await _version(directory, PublishTarget.npm);
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
