// @license
// Copyright (c) 2025 Göran Hegenberg. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'package:args/command_runner.dart';
import 'package:gg_log/gg_log.dart';
import 'package:gg_publish/gg_publish.dart';

/// The command line interface for GgPublish.
class GgPublish extends Command<dynamic> {
  /// Constructor.
  GgPublish({required this.ggLog}) {
    addSubcommand(IsPublished(ggLog: ggLog) as Command<dynamic>);
    addSubcommand(IsLatestStatePublished(ggLog: ggLog));
    addSubcommand(IsUpgraded(ggLog: ggLog));
    addSubcommand(Publish(ggLog: ggLog));
    addSubcommand(PublishTo(ggLog: ggLog));
    addSubcommand(IsVersionPrepared(ggLog: ggLog));
    addSubcommand(PublishedVersion(ggLog: ggLog));
    addSubcommand(PrepareNextVersion(ggLog: ggLog));
    addSubcommand(IsFeatureBranch(ggLog: ggLog));
    addSubcommand(IsMainBranch(ggLog: ggLog));
    addSubcommand(IsOnPubDev(ggLog: ggLog));
    addSubcommand(MainBranch(ggLog: ggLog));
    addSubcommand(MergeMainIntoFeat(ggLog: ggLog));
  }

  /// The log function.
  final GgLog ggLog;

  @override
  final name = 'ggPublish';

  @override
  final description = 'Add your description here.';
}
