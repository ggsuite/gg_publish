# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`gg_publish` is a Dart CLI package providing tools and checks for publishing Dart packages to pub.dev (versioning, branch checks, upgrade checks, publishing, etc.). Published as an executable `gg_publish` and as a library.

## Common Commands

```bash
dart pub get                     # install dependencies
dart analyze                     # static analysis (strict-casts / strict-inference enabled)
dart format .                    # format
dart test                        # run all tests
dart test test/commands/publish_test.dart    # run a single test file
dart test --name "substring"     # run tests matching a name
dart run bin/gg_publish.dart <subcommand>    # run the CLI locally
dart install.dart                # install the CLI globally (see install.bat on Windows)
```

Tests that hit the network / pub.dev require internet (see `check.yaml: needsInternet: true`). `pana` is disabled in `check.yaml`.

## Architecture

Entry point `bin/gg_publish.dart` wires a `GgCommandRunner` (from `gg_args`) to the root `GgPublish` command. All functionality is exposed as subcommands registered in `lib/src/gg_publish.dart`:

- Query commands: `is_in_registry`, `is_published`, `is_latest_state_published`, `is_upgraded`, `is_version_prepared`, `is_feature_branch`, `is_main_branch`, `is_on_pub_dev`, `published_version`, `main_branch`
- Action commands: `publish`, `publish_to`, `prepare_next_version`, `merge_main_into_feat`

### Hybrid packages publish to two registries

A repository carrying both a `pubspec.yaml` and a `package.json` publishes to
pub.dev **and** npm, and each manifest decides for its own side. Every decision
site asks `PublishTo.targets` (a `Set<PublishTarget>` from gg_lang) rather than
the single-string `fromDirectory`, which survives only as a label for messages
(`pub.dev+npm`). `Publish` loops over the active targets — pub.dev first,
because `dart pub publish --dry-run` is the only pre-upload validation gate —
and awaits an `onPublished` callback **between** the uploads, so the publish
flow can record the successful registry before the next one can fail. A partial
failure says which registry is already done; reporting "nothing happened" made
users restart, and the restart was then rejected by the registry.

`PublishedVersion.get` returns the **highest** version across all registries and
`allVersions`/`registryVersions` their union (an rc number spent on either
registry must not be reused); `latestVersionFor`/`registryVersionsFor` answer
per registry, which is what the per-registry resume needs. `IsInRegistry` is
true only when **every** registry has the package, and `missingTargets` names
the ones that need a manual first publish.

`SyncHybridVersions` writes the higher of the two manifest versions into both
and regenerates the version files. Nothing kept them together before, so they
drifted and a publish released two different versions of one artifact.

`publish` requires at least one version of the package to be on its registry already: a package that was never published (checked via `PublishedVersion.registryVersions` / `IsInRegistry`) has to be published manually by the user — the command prints the shell commands (blue), waits for confirmation on stdin, re-checks the registry and continues; the automated upload is skipped when the user published the current version manually. Packages without a public registry (`publish_to: none`, `private: true`) are not checked.

Each command lives in its own file under `lib/src/commands/` and extends `DirCommand<T>` from `gg_args`. Commands follow a consistent shape: a constructor that accepts injectable collaborators (e.g. `GgProcessWrapper`, other command instances, `readLineFromStdIn`) for testability, an `exec` override that delegates to a `get` method holding the real logic, and a `ggLog` sink for output. When adding or modifying a command, preserve this injection pattern — tests rely on substituting `GgProcessWrapper`, stdin readers, and sibling commands with mocks/fakes (`mocktail`).

Public API is re-exported from `lib/gg_publish.dart`; add new commands there and register them in `GgPublish`'s constructor.

This package is part of the `gg_*` family and depends heavily on sibling packages: `gg_args` (command framework), `gg_git` (git operations), `gg_version` (version bumping), `gg_process` (process execution), `gg_log`, `gg_status_printer`, `gg_console_colors`.

## Tests

Tests live under `test/` mirroring `lib/src/`. `test/sample_package/` is a fixture package copied via `test_helpers.dart#copyDirectory` into a temp dir for integration-style tests. `test/bin/` and `test/vscode/` hold auxiliary fixtures.

## Lint Rules of Note

`analysis_options.yaml` enforces (beyond recommended): `lines_longer_than_80_chars`, `prefer_single_quotes`, `require_trailing_commas`, `public_member_api_docs`, `always_declare_return_types` (as error), plus strict language modes. New public members need dartdoc comments.
