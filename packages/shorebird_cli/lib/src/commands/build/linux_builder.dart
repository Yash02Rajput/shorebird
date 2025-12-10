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

/// {@template linux_builder}
/// Functions to build Linux artifacts.
/// {@endtemplate}
class LinuxBuilder extends Builder {
  /// {@macro linux_builder}
  LinuxBuilder({
    required super.argParser,
    required super.argResults,
    required super.flavor,
    required super.target,
  });

  @override
  ReleaseType get releaseType => ReleaseType.linux;

  @override
  String get artifactDisplayName => 'Linux app';

  @override
  Future<void> assertPreconditions() async {
    try {
      await shorebirdValidator.validatePreconditions(
        checkShorebirdInitialized: true,
        validators: doctor.linuxCommandValidators,
        supportedOperatingSystems: {Platform.linux},
      );
    } on PreconditionFailedException catch (e) {
      throw ProcessExit(e.exitCode.code);
    }
  }

  @override
  Future<FileSystemEntity> build() async {
    await artifactBuilder.buildLinuxApp(
      target: target,
      args: argResults.forwardedArgs,
      base64PublicKey: argResults.encodedPublicKey,
    );

    return artifactManager.linuxBundleDirectory;
  }

  @override
  String get postBuildInstructions {
    final bundleDirectory = artifactManager.linuxBundleDirectory;

    return '''
 Built Linux app successfully!

App bundle location:
${lightCyan.wrap(bundleDirectory.path)}

You can now run or distribute this Linux app.
''';
  }
}
