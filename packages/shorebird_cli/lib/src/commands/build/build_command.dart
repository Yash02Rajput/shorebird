import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:shorebird_cli/src/commands/build/build.dart';
import 'package:shorebird_cli/src/common_arguments.dart';
import 'package:shorebird_cli/src/logging/logging.dart';
import 'package:shorebird_cli/src/platform/platform.dart';
import 'package:shorebird_cli/src/release_type.dart';
import 'package:shorebird_cli/src/shorebird_command.dart';
import 'package:shorebird_cli/src/third_party/flutter_tools/lib/flutter_tools.dart';

/// Signature for a function that returns a [Builder] for a given [ReleaseType].
typedef ResolveBuilder = Builder Function(ReleaseType releaseType);

/// {@template build_command}
/// A command that builds artifacts for the provided target platform.
/// `shorebird build android`
/// {@endtemplate}
class BuildCommand extends ShorebirdCommand {
  /// {@macro build_command}
  BuildCommand({ResolveBuilder? resolveBuilder}) {
    _resolveBuilder = resolveBuilder ?? getBuilder;
    argParser
      ..addMultiOption(
        CommonArguments.dartDefineArg.name,
        help: CommonArguments.dartDefineArg.description,
      )
      ..addMultiOption(
        CommonArguments.dartDefineFromFileArg.name,
        help: CommonArguments.dartDefineFromFileArg.description,
      )
      ..addOption(
        'target',
        abbr: 't',
        help: 'The main entrypoint file of the application.',
      )
      ..addOption(
        'flavor',
        help: 'The product flavor to use when building the app.',
      )
      ..addOption(
        CommonArguments.buildNameArg.name,
        help: CommonArguments.buildNameArg.description,
      )
      ..addOption(
        CommonArguments.buildNumberArg.name,
        help: CommonArguments.buildNumberArg.description,
      )
      ..addFlag(
        'codesign',
        help: 'Codesign the application bundle (iOS and macOS only).',
        defaultsTo: true,
      )
      ..addOption(
        CommonArguments.privateKeyArg.name,
        help: CommonArguments.privateKeyArg.description,
      )
      ..addOption(
        CommonArguments.publicKeyArg.name,
        help: CommonArguments.publicKeyArg.description,
      )
      ..addOption(
        CommonArguments.splitDebugInfoArg.name,
        help: CommonArguments.splitDebugInfoArg.description,
      )
      ..addOption(
        CommonArguments.exportMethodArg.name,
        help: CommonArguments.exportMethodArg.description,
        allowed: ExportMethod.values.map((e) => e.argName),
        allowedHelp: {
          for (final method in ExportMethod.values)
            method.argName: method.description,
        },
      )
      ..addOption(
        CommonArguments.exportOptionsPlistArg.name,
        help: CommonArguments.exportOptionsPlistArg.description,
      )
      ..addMultiOption(
        'target-platform',
        help: 'The target platform architectures (Android only).',
        allowed: AndroidArch.availableAndroidArchs
            .map((arch) => arch.targetPlatformCliArg),
        defaultsTo: AndroidArch.availableAndroidArchs
            .map((arch) => arch.targetPlatformCliArg),
      )
      ..addOption(
        'artifact',
        help: 'The type of artifact to build (Android only).',
        allowed: ['apk', 'appbundle'],
        defaultsTo: 'appbundle',
      )
      ..addFlag(
        'split-per-abi',
        help: 'Whether to split the APKs per ABIs (Android only).',
      );
  }

  @override
  String get name => 'build';

  @override
  List<String> get aliases => ['compile'];

  @override
  String get description => 'Build artifacts for a specific platform.';

  @override
  String get invocation => 'shorebird build <platform> [arguments]\n\n'
      'Available platforms:\n'
      '  android   Build Android APK or AAB\n'
      '  ios       Build iOS IPA\n'
      '  macos     Build macOS app\n'
      '  linux     Build Linux app\n'
      '  windows   Build Windows app';

  late final ResolveBuilder _resolveBuilder;

  /// Returns the [Builder] for the given [releaseType].
  @visibleForTesting
  Builder getBuilder(ReleaseType releaseType) {
    return switch (releaseType) {
      ReleaseType.android => AndroidBuilder(
          argParser: argParser,
          argResults: argResults!,
          flavor: results['flavor'] as String?,
          target: results['target'] as String?,
        ),
      ReleaseType.ios => IosBuilder(
          argParser: argParser,
          argResults: argResults!,
          flavor: results['flavor'] as String?,
          target: results['target'] as String?,
        ),
      ReleaseType.macos => MacosBuilder(
          argParser: argParser,
          argResults: argResults!,
          flavor: results['flavor'] as String?,
          target: results['target'] as String?,
        ),
      ReleaseType.linux => LinuxBuilder(
          argParser: argParser,
          argResults: argResults!,
          flavor: results['flavor'] as String?,
          target: results['target'] as String?,
        ),
      ReleaseType.windows => WindowsBuilder(
          argParser: argParser,
          argResults: argResults!,
          flavor: results['flavor'] as String?,
          target: results['target'] as String?,
        ),
      ReleaseType.aar || ReleaseType.iosFramework => throw ArgumentError(
          '${releaseType.cliName} is not supported for build command',
        ),
    };
  }

  @override
  Future<int> run() async {
    try {
      // Get platform from positional arguments
      if (argResults!.rest.isEmpty) {
        logger
          ..err('Missing platform argument.')
          ..info('')
          ..info('Usage: shorebird build <platform> [arguments]')
          ..info('')
          ..info('Available platforms:')
          ..info('  android  Build for Android (APK or AAB)')
          ..info('  ios      Build for iOS')
          ..info('  macos    Build for macOS')
          ..info('  linux    Build for Linux')
          ..info('  windows  Build for Windows');
        return ExitCode.usage.code;
      }

      final platformName = argResults!.rest.first;

      // Find the matching release type
      final releaseType = ReleaseType.values.where((type) {
        return type.cliName == platformName;
      }).firstOrNull;

      if (releaseType == null ||
          releaseType == ReleaseType.aar ||
          releaseType == ReleaseType.iosFramework) {
        logger
          ..err('Invalid platform: $platformName')
          ..info('')
          ..info('Available platforms: android, ios, macos, linux, windows');
        return ExitCode.usage.code;
      }

      await _buildForPlatform(releaseType);

      return ExitCode.success.code;
    } on ProcessExit catch (error) {
      return error.exitCode;
    } catch (error) {
      logger.err('$error');
      return ExitCode.software.code;
    }
  }

  Future<void> _buildForPlatform(ReleaseType releaseType) async {
    final builder = _resolveBuilder(releaseType);

    logger.info('Building ${builder.artifactDisplayName}...');

    // Assert preconditions
    await builder.assertPreconditions();

    // Assert arguments are valid
    await builder.assertArgsAreValid();

    // Build the artifact
    final buildProgress = logger.progress('Building');
    try {
      await builder.build();
      buildProgress.complete('Build complete');
    } catch (error) {
      buildProgress.fail('Build failed');
      rethrow;
    }

    // Show post-build instructions
    logger.info(builder.postBuildInstructions);
  }
}
