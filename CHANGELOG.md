# Changelog

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

[3.0.3]: https://github.com/inlavigo/gg_publish/compare/3.0.2...3.0.3
[3.0.2]: https://github.com/inlavigo/gg_publish/compare/3.0.1...3.0.2
[3.0.1]: https://github.com/inlavigo/gg_publish/compare/3.0.0...3.0.1
[3.0.0]: https://github.com/inlavigo/gg_publish/compare/2.0.2...3.0.0
