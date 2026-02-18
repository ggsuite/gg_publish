// @license
// Copyright (c) 2019 - 2025 Dr. Gabriel Gatzsche. All Rights Reserved.
//
// Use of this source code is governed by terms that can be
// found in the LICENSE file in the root of this package.

import 'dart:io';

import 'package:path/path.dart' as path;

/// Recursively copies [source] to [destination].
///
/// * Creates the destination directory if it does not exist.
/// * Copies files and sub-directories.
/// * Preserves symbolic links by recreating them at the destination.
///
/// Throws an [ArgumentError] if the source directory does not exist.
Future<void> copyDirectory(Directory source, Directory destination) async {
  if (!source.existsSync()) {
    throw ArgumentError('Source directory ${source.path} does not exist');
  }

  // Ensure the destination directory exists.
  if (!destination.existsSync()) {
    await destination.create(recursive: true);
  }

  await for (final entity in source.list(recursive: false)) {
    final newPath = path.join(destination.path, path.basename(entity.path));
    if (entity is File) {
      await entity.copy(newPath);
    } else if (entity is Directory) {
      // Recurse into sub-directories.
      await copyDirectory(entity, Directory(newPath));
    }
  }
}
