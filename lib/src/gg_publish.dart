// @license
// Copyright (c) 2019 - 2024 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:args/command_runner.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_publish/src/commands/is_published.dart';
import 'package:gg_publish/src/commands/is_upgraded.dart';
import 'package:gg_publish/src/commands/is_version_prepared.dart';
import 'package:gg_publish/src/commands/published_version.dart';

/// The command line interface for GgPublish
class GgPublish extends Command<dynamic> {
  /// Constructor
  GgPublish({required this.ggLog}) {
    addSubcommand(IsPublished(ggLog: ggLog));
    addSubcommand(PublishedVersion(ggLog: ggLog));
    addSubcommand(IsUpgraded(ggLog: ggLog));
    addSubcommand(IsVersionPrepared(ggLog: ggLog));
  }

  /// The log function
  final GgLog ggLog;

  // ...........................................................................
  @override
  final name = 'ggPublish';
  @override
  final description = 'Add your description here.';
}
