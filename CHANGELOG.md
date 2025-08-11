# Changelog

## [Unreleased]

### Changed

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

[Unreleased]: https://github.com/inlavigo/gg_publish/compare/3.0.18...HEAD
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
