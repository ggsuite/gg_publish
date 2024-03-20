// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:args/command_runner.dart';
import 'package:gg_publish/src/commands/is_published.dart';
import 'package:gg_publish/src/commands/published_version.dart';

/// The command line interface for GgPublish
class GgPublish extends Command<dynamic> {
  /// Constructor
  GgPublish({required this.log}) {
    addSubcommand(IsPublished(log: log));
    addSubcommand(PublishedVersion(log: log));
  }

  /// The log function
  final void Function(String message) log;

  // ...........................................................................
  @override
  final name = 'ggPublish';
  @override
  final description = 'Add your description here.';
}
