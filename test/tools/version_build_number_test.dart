// @license
// Copyright (c) ggsuite
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:gg_publish/gg_publish.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() {
  Version v(String s) => Version.parse(s);

  group('withoutBuildNumber(version)', () {
    test('removes the build number', () {
      expect(withoutBuildNumber(v('1.2.4+155')), v('1.2.4'));
    });

    test('keeps a prerelease suffix', () {
      expect(withoutBuildNumber(v('1.2.4-rc.1+155')), v('1.2.4-rc.1'));
    });

    test('returns a version without build number unchanged', () {
      expect(withoutBuildNumber(v('1.2.4')), v('1.2.4'));
    });
  });

  group('withNextBuildNumber(target, current)', () {
    test('returns the target unchanged without a current version', () {
      expect(withNextBuildNumber(target: v('1.2.5')), v('1.2.5'));
    });

    test('returns the target unchanged when current has no build number', () {
      expect(
        withNextBuildNumber(target: v('1.2.5'), current: v('1.2.4')),
        v('1.2.5'),
      );
    });

    test('carries the build number over and counts it up', () {
      expect(
        withNextBuildNumber(target: v('1.2.5'), current: v('1.2.4+155')),
        v('1.2.5+156'),
      );
      expect(
        withNextBuildNumber(target: v('2.0.0'), current: v('1.2.4+155')),
        v('2.0.0+156'),
      );
    });

    test('keeps a prerelease suffix of the target', () {
      expect(
        withNextBuildNumber(target: v('1.2.5-rc.1'), current: v('1.2.4+155')),
        v('1.2.5-rc.1+156'),
      );
    });

    test('keeps the build number when the current version already is '
        'the target release (resumed publish)', () {
      expect(
        withNextBuildNumber(target: v('1.2.5'), current: v('1.2.5+156')),
        v('1.2.5+156'),
      );
      expect(
        withNextBuildNumber(
          target: v('1.2.5-rc.1'),
          current: v('1.2.5-rc.1+156'),
        ),
        v('1.2.5-rc.1+156'),
      );
    });

    test('counts up the first component only', () {
      expect(
        withNextBuildNumber(target: v('1.2.5'), current: v('1.2.4+155.7')),
        v('1.2.5+156'),
      );
    });

    test('carries a non-numeric build number over verbatim', () {
      expect(
        withNextBuildNumber(target: v('1.2.5'), current: v('1.2.4+nightly.3')),
        v('1.2.5+nightly.3'),
      );
    });
  });
}
