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

/// {@template ios_builder}
/// Functions to build iOS artifacts.
/// {@endtemplate}
class IosBuilder extends Builder {
  /// {@macro ios_builder}
  IosBuilder({
    required super.argParser,
    required super.argResults,
    required super.flavor,
    required super.target,
  });

  /// Whether to codesign the build.
  bool get codesign => argResults['codesign'] == true;

  @override
  ReleaseType get releaseType => ReleaseType.ios;

  @override
  String get artifactDisplayName => 'iOS app';

  @override
  Future<void> assertPreconditions() async {
    try {
      await shorebirdValidator.validatePreconditions(
        checkShorebirdInitialized: true,
        validators: doctor.iosCommandValidators,
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
        ..err('Shorebird does not currently support obfuscation on iOS.')
        ..info(
          '''We hope to support obfuscation in the future. We are tracking this work at ${link(uri: Uri.parse('https://github.com/shorebirdtech/shorebird/issues/1619'))}.''',
        );
      throw ProcessExit(ExitCode.unavailable.code);
    }
  }

  @override
  Future<FileSystemEntity> build() async {
    if (!codesign) {
      logger.info(
        '''Building for device with codesigning disabled. You will have to manually codesign before deploying to device.''',
      );
    }

    // Delete the Shorebird supplement directory if it exists.
    // This is to ensure that we don't accidentally use stale artifacts.
    final shorebirdSupplementDir =
        artifactManager.getIosReleaseSupplementDirectory();
    if (shorebirdSupplementDir?.existsSync() ?? false) {
      shorebirdSupplementDir!.deleteSync(recursive: true);
    }

    await artifactBuilder.buildIpa(
      codesign: codesign,
      flavor: flavor,
      target: target,
      args: argResults.forwardedArgs,
      base64PublicKey: argResults.encodedPublicKey,
    );

    final xcarchiveDirectory = artifactManager.getXcarchiveDirectory();
    if (xcarchiveDirectory == null) {
      logger.err('Unable to find .xcarchive directory');
      throw ProcessExit(ExitCode.software.code);
    }

    return xcarchiveDirectory;
  }

  @override
  String get postBuildInstructions {
    final ipaPath = artifactManager.getIpa();

    return '''
✓ Built iOS app successfully!

${codesign ? 'Signed ' : 'Unsigned '}IPA location:
${lightCyan.wrap(ipaPath?.path ?? 'Unable to locate IPA')}

${codesign ? '''
You can now upload this IPA to TestFlight or the App Store.
For more information on uploading to the App Store, see:
${link(uri: Uri.parse('https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds'))}''' : '''
You will need to manually codesign this IPA before deploying to a device.
You can sign the .xcarchive in Xcode.'''}
''';
  }
}
