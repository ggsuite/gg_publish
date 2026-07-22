# Changelog

## [Unreleased]

### Changed

- Run npm registry lookups in the package directory so the project-level .npmrc with private feeds is honored
- gg\_multi: changed references to git

## [3.7.0] - 2026-07-20

### Added

- Add rc prerelease channel to gg do publish (channel field/flag, X.Y.Z-rc.N computation, npm --tag rc, single + multi repo)
- Address review: wrap registry version-parse errors as RegistryException, clarify spent-version rc message, lock cider rc changelog format

### Changed

- gg\_multi: changed references to git

## [3.6.0] - 2026-07-01

### Changed

- npm/pnpm (TypeScript) publishes now run *interactively* by inheriting the
terminal's stdio, so the package manager can drive its own 2FA flow —
prompting for a one-time password or opening its browser login — instead
of failing with `ERR_PNPM_OTP_NON_INTERACTIVE` when gg captured the pipe.
Dart/pub.dev publishing is unchanged (still captured, gg answers the
confirmation prompt).
- feat(gg): do checkout + .gg/.ticket.json ticket marker; TS format no direct eslint & P:\programs\flutter/bin/internal/exit\_with\_errorlevel.bat
- feat(gg): interactive npm publish + npm-logged-in precheck; package.json prepublishOnly->build->test rules (bridges exempt from build->test); do review pnpm blockExoticSubdeps + stdout; can publish runs per-repo can-publish; do merge/publish write doCommit; pana skip label
- gg\_multi: changed references to git

## [3.5.1] - 2026-06-26

### Changed

- gg\_multi: changed references to git

## [3.5.0] - 2026-06-19

### Changed

- Treat dart-typescript bridge repos as TypeScript for can/do review (npm install, skip dart pub get); export isBridgeProject from gg\_one
- Publish bridges as TypeScript: pnpm-aware publish, dual-manifest version bump, non-swallowed publish errors, idempotent resume, review skips merged repos, link: for local TS deps, package.json scripts check
- gg\_multi: changed references to git

## [3.4.0] - 2026-06-08

### Changed

- feat: language-universal publishing via gg\_lang (npm + pub.dev registry-aware version checks, manifest-driven publish command, TypeScript bypasses CHANGELOG)
- feat(do add): auto-clone transitive deps into master before graph build & P:\programs\flutter/bin/internal/exit\_with\_errorlevel.bat
- gg\_multi: changed references to git
- gg\_multi: changed references to git
- Gg Multi: changed references to pub.dev

## [3.3.1] - 2026-04-20

## [3.3.0] - 2026-04-07

### Changed

- kidney: changed references to path
- Refactor MainBranch to inject process runner and improve tests
- kidney: changed references to git

### Fixed

- Remove useCarriageReturn and fix ggLog parameter in merge command

## [3.2.1] - 2026-03-30

## [3.2.0] - 2026-03-19

### Added

- Add is-main-branch command to check for main branch in Git

## [3.1.0] - 2026-03-18

### Changed

- Improve error message for non-feature branches in is\_feature\_branch
- Update dependencies: gg\_console\_colors, gg\_git, gg\_capture\_print
- Update latest dependencies, Add .gitattributes file

## [3.0.18] - 2025-08-11

### Changed

- Update to gg\_git 3.0.0

## [3.0.17] - 2025-06-09

### Changed

- Improve version mismatch error message

## [3.0.16] - 2024-04-13

### Removed

- dependency pana

## [3.0.15] - 2024-04-12

### Added

- use dart pub outdated json response

### Removed

- dependency to gg\_install\_gg, remove ./check script

## [3.0.14] - 2024-04-11

### Changed

- upgrade dependencies

## [3.0.13] - 2024-04-11

### Changed

- Fix mocks

## [3.0.12] - 2024-04-11

### Added

- PrepareNextVersion: Specify published version from outside

## [3.0.11] - 2024-04-11

### Changed

- MockIsUpgraded reuses code from MockDirCommand
- derive all mocks from MockDirCommand
- Fintue mocks

## [3.0.10] - 2024-04-11

### Added

- Extend mock for IsUpgraded

## [3.0.9] - 2024-04-09

### Removed

- 'Pipline: Disable cache'

## [3.0.8] - 2024-04-09

### Fixed

- Fixed an error on IsVersionPrepared

## [3.0.7] - 2024-04-09

### Changed

- Update dependency gg\_version to 4.0.0

## [3.0.6] - 2024-04-09

### Added

- Publish: add askBeforePublishing to supress asking for confirmation

## [3.0.5] - 2024-04-09

### Fixed

- PublishedVersion did not handle publish\_to: none

## [3.0.4] - 2024-04-09

### Fixed

- IsPublished will no also handle packages that are not published to pub.dev

## [3.0.3] - 2024-04-09

### Fixed

- IsVersionPrepared did not work with local uncommitted changes

## [3.0.2] - 2024-04-08

### Added

- Take over IsVersionPrepared, PrepareNextVersion and PublishedVersion from gg\_version
- IsVersionPrepared: Does also work for packages not published to git

## [3.0.1] - 2024-04-08

### Added

- publish-to command to get the publish target

## [3.0.0] - 2024-04-06

### Added

- Increased version

### Changed

- Rework changelog
- 'Github Actions Pipeline'
- 'Github Actions Pipeline: Add SDK file containing flutter into .github/workflows to make github installing flutter and not dart SDK'
- BREAKING CHANGE: `is-published` renamed into `is-latest state-published`
- Added a new `is-published` which returns `true` when the package is published at all

## 2.0.2 - 2024-01-01

- Update gg\_version to 2.0.0

## 2.0.1 - 2024-01-01

- Breaking change: Move `IsVersionPrepared` and `PublishedVersion` to `gg_version`

## 1.2.0 - 2024-01-01

- Add `Publish` command

## 1.1.3 - 2024-01-01

- Next Update

## 1.1.2 - 2024-01-01

- Add `IsVersionPrepared`

## 1.0.7 - 2024-01-01

- Update dependencies

## 1.0.6 - 2024-01-01

- Update GgConsoleColors

## 1.0.5 - 2024-01-01

- Add GgLog

## 1.0.4 - 2024-01-01

- Add mocktail mocks

## 1.0.3 - 2024-01-01

- Adapt directory structure

## 1.0.2 - 2024-01-01

- Make commands public

## 1.0.1 - 2024-01-01

- Add `is-upgraded` command

## 1.0.0 - 2024-01-01

- Initial version.

[Unreleased]: https://github.com/inlavigo/gg_publish/compare/3.7.0...HEAD
[3.7.0]: https://github.com/inlavigo/gg_publish/compare/3.6.0...3.7.0
[3.6.0]: https://github.com/inlavigo/gg_publish/compare/3.5.1...3.6.0
[3.5.1]: https://github.com/inlavigo/gg_publish/compare/3.5.0...3.5.1
[3.5.0]: https://github.com/inlavigo/gg_publish/compare/3.4.0...3.5.0
[3.4.0]: https://github.com/inlavigo/gg_publish/compare/3.3.1...3.4.0
[3.3.1]: https://github.com/inlavigo/gg_publish/compare/3.3.0...3.3.1
[3.3.0]: https://github.com/inlavigo/gg_publish/compare/3.2.1...3.3.0
[3.2.1]: https://github.com/inlavigo/gg_publish/compare/3.2.0...3.2.1
[3.2.0]: https://github.com/inlavigo/gg_publish/compare/3.1.0...3.2.0
[3.1.0]: https://github.com/inlavigo/gg_publish/compare/3.0.18...3.1.0
[3.0.18]: https://github.com/inlavigo/gg_publish/compare/3.0.17...3.0.18
[3.0.17]: https://github.com/inlavigo/gg_publish/compare/3.0.16...3.0.17
[3.0.16]: https://github.com/inlavigo/gg_publish/compare/3.0.15...3.0.16
[3.0.15]: https://github.com/inlavigo/gg_publish/compare/3.0.14...3.0.15
[3.0.14]: https://github.com/inlavigo/gg_publish/compare/3.0.13...3.0.14
[3.0.13]: https://github.com/inlavigo/gg_publish/compare/3.0.12...3.0.13
[3.0.12]: https://github.com/inlavigo/gg_publish/compare/3.0.11...3.0.12
[3.0.11]: https://github.com/inlavigo/gg_publish/compare/3.0.10...3.0.11
[3.0.10]: https://github.com/inlavigo/gg_publish/compare/3.0.9...3.0.10
[3.0.9]: https://github.com/inlavigo/gg_publish/compare/3.0.8...3.0.9
[3.0.8]: https://github.com/inlavigo/gg_publish/compare/3.0.7...3.0.8
[3.0.7]: https://github.com/inlavigo/gg_publish/compare/3.0.6...3.0.7
[3.0.6]: https://github.com/inlavigo/gg_publish/compare/3.0.5...3.0.6
[3.0.5]: https://github.com/inlavigo/gg_publish/compare/3.0.4...3.0.5
[3.0.4]: https://github.com/inlavigo/gg_publish/compare/3.0.3...3.0.4
[3.0.3]: https://github.com/inlavigo/gg_publish/compare/3.0.2...3.0.3
[3.0.2]: https://github.com/inlavigo/gg_publish/compare/3.0.1...3.0.2
[3.0.1]: https://github.com/inlavigo/gg_publish/compare/3.0.0...3.0.1
[3.0.0]: https://github.com/inlavigo/gg_publish/compare/2.0.2...3.0.0
