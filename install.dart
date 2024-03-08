#!/usr/bin/env dart
// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

/// Create an exe and install it in the system.
/// This is a simple way to install the package as command line tool.
library;

import 'dart:io';

import 'package:colorize/colorize.dart';

// #############################################################################
void main() {
  const exe = 'ggPublish';
  const src = 'bin/gg_publish.dart';
  final installDir = '${Platform.environment['HOME']}/.pub-cache/bin';

  // Create install dir if it does not exist
  if (!Directory(installDir).existsSync()) {
    print('Creating $installDir');
    Directory(installDir).createSync(recursive: true);
  }

  final dest = '$installDir/$exe';
  print('Installing $exe in $dest');
  final result = Process.runSync('dart', ['compile', 'exe', src, '-o', dest]);

  if (result.stderr.toString().trim().isNotEmpty) {
    print('❌ ${Colorize(result.stderr.toString()).red()}');
  }
  print(Colorize('✅ Installed $exe in $dest').green());
}
