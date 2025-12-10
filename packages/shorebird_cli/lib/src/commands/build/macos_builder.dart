import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:platform/platform.dart';
import 'package:shorebird_cli/src/artifact_builder/artifact_builder.dart';
import 'package:shorebird_cli/src/artifact_manager.dart';
import 'package:shorebird_cli/src/commands/build/builder.dart';
import 'package:shorebird_cli/src/doctor.dart';
import 'package:shorebird_cli/src/extensions/arg_results.dart';
import 'package:shorebird_cli/src/logging/logging.dart';
import 'package:shorebird_cli/src/release_type.dart';
import 'package:shorebird_cli/src/shorebird_validator.dart';
import 'package:shorebird_cli/src/third_party/flutter_tools/lib/flutter_tools.dart';

/// {@template macos_builder}
/// Functions to build macOS artifacts.
/// {@endtemplate}
class MacosBuilder extends Builder {
  /// {@macro macos_builder}
  MacosBuilder({
    required super.argParser,
    required super.argResults,
    required super.flavor,
    required super.target,
  });

  /// Whether to codesign the build.
  bool get codesign => argResults['codesign'] == true;

  @override
  ReleaseType get releaseType => ReleaseType.macos;

  @override
  String get artifactDisplayName => 'macOS app';

  @override
  Future<void> assertPreconditions() async {
    try {
      await shorebirdValidator.validatePreconditions(
        checkShorebirdInitialized: true,
        validators: doctor.macosCommandValidators,
        supportedOperatingSystems: {Platform.macOS},
      );
    } on PreconditionFailedException catch (e) {
      throw ProcessExit(e.exitCode.code);
    }
  }

  @override
  Future<void> assertArgsAreValid() async {
    if (argResults.rest.contains('--obfuscate')) {
      // Obfuscated builds break patching, so we don't support them.
      // See https://github.com/shorebirdtech/shorebird/issues/1619
      logger
        ..err('Shorebird does not currently support obfuscation on macOS.')
        ..info(
          '''
We hope to support obfuscation in the future. We are tracking this work at ${link(uri: Uri.parse('https://github.com/shorebirdtech/shorebird/issues/1619'))}.''',
        );
      throw ProcessExit(ExitCode.unavailable.code);
    }
  }

  @override
  Future<FileSystemEntity> build() async {
    if (!codesign) {
      logger.info(
        '''
Building for device with codesigning disabled. You will have to manually codesign before deploying to device.''',
      );
    }

    await artifactBuilder.buildMacos(
      codesign: codesign,
      flavor: flavor,
      target: target,
      args: argResults.forwardedArgs,
      base64PublicKey: argResults.encodedPublicKey,
    );

    final appDirectory = artifactManager.getMacOSAppDirectory(flavor: flavor);
    if (appDirectory == null) {
      logger.err('Unable to find .app directory');
      throw ProcessExit(ExitCode.software.code);
    }

    return appDirectory;
  }

  @override
  String get postBuildInstructions {
    final appDirectory = artifactManager.getMacOSAppDirectory(flavor: flavor);

    return '''
 Built macOS app successfully!

${codesign ? 'Signed ' : 'Unsigned '}app location:
${lightCyan.wrap(appDirectory?.path ?? 'Unable to locate app')}

${codesign ? '''
You can now distribute this macOS app.''' : '''
You will need to manually codesign this app before distribution.
You can sign the .app in Xcode.'''}
''';
  }
}
