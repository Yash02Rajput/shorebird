import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:shorebird_cli/src/artifact_builder/artifact_builder.dart';
import 'package:shorebird_cli/src/commands/build/builder.dart';
import 'package:shorebird_cli/src/doctor.dart';
import 'package:shorebird_cli/src/extensions/arg_results.dart';
import 'package:shorebird_cli/src/logging/logging.dart';
import 'package:shorebird_cli/src/platform/platform.dart';
import 'package:shorebird_cli/src/release_type.dart';
import 'package:shorebird_cli/src/shorebird_android_artifacts.dart';
import 'package:shorebird_cli/src/shorebird_validator.dart';
import 'package:shorebird_cli/src/third_party/flutter_tools/lib/flutter_tools.dart';

/// {@template android_builder}
/// Functions to build Android artifacts.
/// {@endtemplate}
class AndroidBuilder extends Builder {
  /// {@macro android_builder}
  AndroidBuilder({
    required super.argParser,
    required super.argResults,
    required super.flavor,
    required super.target,
  });

  @override
  ReleaseType get releaseType => ReleaseType.android;

  @override
  String get artifactDisplayName {
    final artifact = argResults['artifact'] as String;
    return artifact == 'apk' ? 'Android APK' : 'Android app bundle';
  }

  /// The architectures to build for.
  Set<Arch> get architectures => (argResults['target-platform'] as List<String>)
      .map(
        (platform) => AndroidArch.availableAndroidArchs.firstWhere(
          (arch) => arch.targetPlatformCliArg == platform,
        ),
      )
      .toSet();

  /// Whether to generate an APK instead of an AAB.
  bool get generateApk => argResults['artifact'] as String == 'apk';

  /// Whether to split the APK per ABI.
  bool get splitApk => argResults['split-per-abi'] == true;

  @override
  Future<void> assertPreconditions() async {
    try {
      await shorebirdValidator.validatePreconditions(
        checkShorebirdInitialized: true,
        validators: doctor.androidCommandValidators,
      );
    } on PreconditionFailedException catch (e) {
      throw ProcessExit(e.exitCode.code);
    }
  }

  @override
  Future<void> assertArgsAreValid() async {
    if (generateApk && splitApk) {
      logger
        ..err(
          'Shorebird does not support the split-per-abi option at this time',
        )
        ..info(
          '''
Split APKs are each given a different release version than what is specified in the pubspec.yaml.

See ${link(uri: Uri.parse('https://github.com/flutter/flutter/issues/39817'))} for more information about this issue.
Please comment and upvote ${link(uri: Uri.parse('https://github.com/shorebirdtech/shorebird/issues/1141'))} if you would like shorebird to support this.''',
        );
      throw ProcessExit(ExitCode.unavailable.code);
    }
  }

  @override
  Future<FileSystemEntity> build() async {
    final base64PublicKey = argResults.encodedPublicKey;

    if (generateApk) {
      logger.info('Building APK');
      final apk = await artifactBuilder.buildApk(
        flavor: flavor,
        target: target,
        targetPlatforms: architectures,
        args: argResults.forwardedArgs,
        base64PublicKey: base64PublicKey,
      );
      return apk;
    } else {
      logger.info('Building app bundle');
      final aab = await artifactBuilder.buildAppBundle(
        flavor: flavor,
        target: target,
        targetPlatforms: architectures,
        args: argResults.forwardedArgs,
        base64PublicKey: base64PublicKey,
      );
      return aab;
    }
  }

  @override
  String get postBuildInstructions {
    if (generateApk) {
      final apkFile = shorebirdAndroidArtifacts.findApk(
        project: projectRoot,
        flavor: flavor,
      );
      return '''
 Built APK successfully!

APK location:
${lightCyan.wrap(apkFile.path)}

You can now install this APK on a device or upload it for testing.
''';
    } else {
      final aabFile = shorebirdAndroidArtifacts.findAab(
        project: projectRoot,
        flavor: flavor,
      );
      return '''
 Built app bundle successfully!

App bundle location:
${lightCyan.wrap(aabFile.path)}

You can upload this to the Play Store or convert it to APK for testing.
For information on uploading to the Play Store, see:
${link(uri: Uri.parse('https://support.google.com/googleplay/android-developer/answer/9859152?hl=en'))}
''';
    }
  }
}
