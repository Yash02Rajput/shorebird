import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:platform/platform.dart';
import 'package:shorebird_cli/src/artifact_builder/artifact_builder.dart';
import 'package:shorebird_cli/src/artifact_manager.dart';
import 'package:shorebird_cli/src/commands/build/builder.dart';
import 'package:shorebird_cli/src/doctor.dart';
import 'package:shorebird_cli/src/extensions/arg_results.dart';
import 'package:shorebird_cli/src/release_type.dart';
import 'package:shorebird_cli/src/shorebird_validator.dart';
import 'package:shorebird_cli/src/third_party/flutter_tools/lib/flutter_tools.dart';

/// {@template windows_builder}
/// Functions to build Windows artifacts.
/// {@endtemplate}
class WindowsBuilder extends Builder {
  /// {@macro windows_builder}
  WindowsBuilder({
    required super.argParser,
    required super.argResults,
    required super.flavor,
    required super.target,
  });

  @override
  ReleaseType get releaseType => ReleaseType.windows;

  @override
  String get artifactDisplayName => 'Windows app';

  @override
  Future<void> assertPreconditions() async {
    try {
      await shorebirdValidator.validatePreconditions(
        checkShorebirdInitialized: true,
        validators: doctor.windowsCommandValidators,
        supportedOperatingSystems: {Platform.windows},
      );
    } on PreconditionFailedException catch (e) {
      throw ProcessExit(e.exitCode.code);
    }
  }

  @override
  Future<FileSystemEntity> build() async {
    return artifactBuilder.buildWindowsApp(
      target: target,
      args: argResults.forwardedArgs,
      base64PublicKey: argResults.encodedPublicKey,
    );
  }

  @override
  String get postBuildInstructions {
    final releaseDir = artifactManager.getWindowsReleaseDirectory();

    return '''
 Built Windows app successfully!

App location:
${lightCyan.wrap(releaseDir.path)}

You can now run or distribute this Windows app.
''';
  }
}
