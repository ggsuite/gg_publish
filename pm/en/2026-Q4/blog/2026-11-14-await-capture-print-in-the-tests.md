<!--
@license
Copyright (c) ggsuite

Use of this source code is governed by terms that can be
found in the LICENSE file in the root of this package.
-->

# Await capturePrint in the tests

## Motivation

- A test should check a result only once the code under test is done.
  Otherwise it passes or fails with the timing, not with the code
- Two tests of this repo started the command runner inside `capturePrint`
  and read the captured output right away, without waiting for it
- They were green all the same, but only thanks to a detail of the command
  runner. A test should not lean on such a detail: it turns red, or
  stays green for the wrong reason, as soon as the detail changes

## Strategy

- Find the calls of `capturePrint` whose result is not awaited
- Await them, and change nothing else in the tests
- Leave the package itself alone: no file below `lib/` changes

## What was wrong

- `capturePrint` of gg_capture_print runs the given code in a zone that
  forwards every `print` to `ggLog`. It is asynchronous and completes
  when the code has completed
- The tests »when called with --help« of `IsPublished` and
  `IsLatestStatePublished` called it without `await` and then read
  `messages.last`
- Without `await` the expectations run while the captured code may still
  be under way. A test can even end before its code does; what the code
  prints or throws after that belongs to no test anymore
- The tests passed because, for `--help`, the command runner of
  `package:args` prints the usage text before its first asynchronous
  step. The text was there in time by the order of the statements, not
  because the test waited for it
- The lint `unawaited_futures` is switched on in `analysis_options.yaml`,
  but it did not report the two calls: `capturePrint` declares
  `FutureOr<List<String>>` as its return type, not `Future`

## The fix

- `test/commands/is_published_test.dart` and
  `test/commands/is_latest_state_published_test.dart` now write
  `await capturePrint(...)`
- The expectations are the same as before: the last message contains
  »Available commands:«, the name and the description of the command
- The third call, in `test/gg_publish_test.dart`, was awaited already, so
  every `capturePrint` of the repo is awaited now
- Behavior and public API of the package are unchanged; the release is a
  patch

## Open Points

- Nothing guards the rule. A new call of `capturePrint` without `await`
  passes the analyzer just like the two old ones did
- A `capturePrint` that returns `Future` would bring such calls under
  `unawaited_futures`. That is a decision for gg_capture_print, not for
  this repo
