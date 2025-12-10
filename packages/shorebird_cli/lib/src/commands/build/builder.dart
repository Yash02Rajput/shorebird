import 'dart:io';

import 'package:args/args.dart';
import 'package:shorebird_cli/src/release_type.dart';
import 'package:shorebird_cli/src/shorebird_env.dart';

/// {@template builder}
/// Platform-specific functionality to build artifacts.
/// {@endtemplate}
abstract class Builder {
  /// {@macro builder}
  Builder({
    required this.argParser,
    required this.argResults,
    required this.flavor,
    required this.target,
  });

  /// The parser for the arguments passed to the command.
  final ArgParser argParser;

  /// The arguments passed to the command.
  final ArgResults argResults;

  /// The flavor of the build, if any.
  final String? flavor;

  /// The target script to run, if any.
  final String? target;

  /// The type of artifact we are building.
  ReleaseType get releaseType;

  /// The human-readable description of the artifact being built (e.g.,
  /// "Android APK", "iOS app").
  String get artifactDisplayName;

  /// The root directory of the current project.
  Directory get projectRoot => shorebirdEnv.getShorebirdProjectRoot()!;

  /// Asserts that the command can be run.
  Future<void> assertPreconditions();

  /// Asserts that the combination arguments passed to the command are valid.
  Future<void> assertArgsAreValid() async {}

  /// Builds the artifact for the given platform. Returns the built artifact.
  Future<FileSystemEntity> build();

  /// Instructions explaining what to do with the built artifact. This could
  /// include where the file is located and how to test or deploy it.
  String get postBuildInstructions;
}
