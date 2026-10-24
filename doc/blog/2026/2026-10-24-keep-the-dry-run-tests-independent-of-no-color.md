<!--
@license
Copyright (c) ggsuite

Use of this source code is governed by terms that can be
found in the LICENSE file in the root of this package.
-->

# Keep the dry run tests independent of NO_COLOR

## Motivation

- Ticket gg-1 makes the gg checks pass on every developer machine,
  Windows included
- The checks of a repo must not depend on the shell they run in
- The dry run tests of `publish` compare the colors of the printed report:
  the red warning, the gray ✗ line and the blue paths within the warning
- `gg_console_colors` returns plain text when `NO_COLOR` is set or `TERM`
  is `dumb`
- In such a shell, "breaks the publishing when the dry run reports a
  warning" failed, although publishing itself worked as intended

## Strategy

- Decide the colors in the test, not in the environment
- Turn the colors on for the dry run tests, as the tests of other gg
  packages do
- Hand the decision back to the environment after each test
- Leave the production code unchanged: `publish` still honors `NO_COLOR`

## Implementation 1: Colors on in the dry run tests

- The group "with »--dry-run«" in `test/commands/publish_test.dart` sets
  `ggColorsEnabled = true` in `setUp`
- `tearDown` sets it back to `null`, so the environment decides again for
  the tests that follow
- The comparisons now see every escape sequence, whatever `NO_COLOR` or
  `TERM` say
- The other tests of the group compare text without colors and pass with
  colors on as well
- No other test of this repo compares escape sequences

## Dependency updates

- `dna_ggsuite` moves from `^0.4.0` to `^1.0.0`; the regenerated guides,
  templates and skills bring:
- Blog posts live in `doc/blog/<yyyy>`, describe this repo alone, and the
  template has a "Dependency updates" section; german posts go to
  `doc/de/blog/<yyyy>`
- A rewritten README guide and template: motivation, installation, usage,
  limits, English and German; `scripts/check-readme.js` checks a README
  against them, and the `/readme` skill runs it
- `setup-github-guide.md` moves from `guides/` to `doc/guides/`
- A `/gg-review` skill: blog posts and the README are written before the
  pull requests, no longer at publish time
- Claude Code hooks that keep the prompts of a ticket in its project
  management repo
- New rules in the AI guide: keep every repo in its scope, keep
  `index.jsonc` up to date, describe every repo in its own terms
- Type names in the code guides no longer carry a package prefix
- `helix` moves to `^1.13.0`, which joins the `CLAUDE.md` of all DNA
  layers instead of letting the last one win

## Result

- The tests of `publish` pass with and without `NO_COLOR`
- Publishing behaves as before

## Open Points

- A new test that compares escape sequences has to turn the colors on
  itself, as the dry run group does
