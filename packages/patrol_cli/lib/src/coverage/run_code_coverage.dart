import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coverage/coverage.dart';
import 'package:glob/glob.dart';
import 'package:patrol_cli/src/base/logger.dart';
import 'package:patrol_cli/src/devices.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

late Process logsProcess;
late Map<String, HitMap> hitMap = <String, HitMap>{};
late String mainIsolateId;
late Logger logger;

Future<void> collectCoverageForTest(
    VmService client,
    String isolateId,
    String testName,
    Uri vmServiceUrl,
    Set<String>? libraryNames,
    bool functionCoverageEnabled,
    bool branchCoverageEnabled) async {
  try {
    print(("Collecting coverage for test: $testName"));

    final coverage = await collect(
      vmServiceUrl,
      true,
      false,
      false,
      libraryNames,
      functionCoverage: functionCoverageEnabled,
      branchCoverage: branchCoverageEnabled,
    );

    hitMap.merge(await HitMap.parseJson(
      coverage['coverage'] as List<Map<String, dynamic>>,
    ));

    print("Coverage collected for test: $testName");
  } catch (e) {
    print("Error collecting coverage for test: $e");
  }
}

Future<void> collectCoverageData({
  required Directory flutterPackageDirectory,
  required Logger logger,
  required Set<Glob> ignoreGlobs,
}) async {
  logsProcess.kill();

  logger.info('All coverage gathered, saving');
  final report = hitMap.formatLcov(
    await Resolver.create(
      packagePath: flutterPackageDirectory.path,
    ),
    ignoreGlobs: ignoreGlobs,
  );

  print("Marking test completed");
  print("Test completed");
  logsProcess.kill();

  await _saveCoverage(report);
}

Future<ProcessResult> _forwardAdbPort(String host, String guest) async {
  return Process.run('adb', ['forward', 'tcp:$host', 'tcp:$guest']);
}

Uri _createWebSocketUri(Uri uri) {
  final pathSegments = uri.pathSegments.where((c) => c.isNotEmpty).toList()
    ..add('ws');
  return uri.replace(scheme: 'ws', pathSegments: pathSegments);
}

Future<void> _saveCoverage(String report) async {
  final coverageDirectory = Directory('coverage');

  if (!coverageDirectory.existsSync()) {
    await coverageDirectory.create();
  }
  await File(
    coverageDirectory.uri.resolve('patrol_lcov.info').toString(),
  ).writeAsString(report);
}

Future<void> runCodeCoverage({
  required String flutterPackageName,
  required Directory flutterPackageDirectory,
  required TargetPlatform platform,
  required Set<String>? libraryNames,
  required bool functionCoverageEnabled,
  required bool branchCoverageEnabled,
  required String? coveragePathOutput,
  required Logger logger,
  required Set<Glob> ignoreGlobs,
}) async {
  final homeDirectory =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];

  logsProcess = await Process.start(
    'flutter',
    ['logs'],
    workingDirectory: homeDirectory,
  );
  final vmRegex = RegExp('listening on (http.+)');

  logsProcess.stdout.transform(utf8.decoder).listen(
    (line) async {
      final vmLink = vmRegex.firstMatch(line)?.group(1);

      if (vmLink == null) {
        return;
      }

      final port = RegExp(':([0-9]+)/').firstMatch(vmLink)!.group(1)!;
      final auth = RegExp(':$port/(.+)').firstMatch(vmLink)!.group(1);

      final String? hostPort;

      switch (platform) {
        case TargetPlatform.android:
          await _forwardAdbPort('61011', port);

          // It is necessary to grab the port from adb forward --list because
          // if debugger was attached, the port might be different from the one
          // we set
          final forwardList = await Process.run('adb', ['forward', '--list']);
          final output = forwardList.stdout as String;
          hostPort =
              RegExp('tcp:([0-9]+) tcp:$port').firstMatch(output)?.group(1);
        case TargetPlatform.iOS || TargetPlatform.macOS:
          hostPort = port;
        default:
          hostPort = null;
      }

      if (hostPort == null) {
        logger.err('Failed to obtain Dart VM uri.');
        return;
      }

      final serviceUri = Uri.parse('http://127.0.0.1:$hostPort/$auth');
      logger.info("Connecting to Dart VM at $serviceUri");
      final serviceClient = await vmServiceConnectUri(
        _createWebSocketUri(serviceUri).toString(),
      );
      await serviceClient.streamListen(EventStreams.kExtension);
      await serviceClient.streamListen(EventStreams.kIsolate);

      serviceClient.onExtensionEvent.listen((event) async {
        if (event.extensionKind == 'coverageCollectionReady') {
          logger.info('Coverage collection ready');
          final isolateId = event.extensionData!.data['isolateId'] as String;
          final testName = event.extensionData!.data['testName'] as String;
          await collectCoverageForTest(
              serviceClient,
              isolateId,
              testName,
              serviceUri,
              libraryNames,
              functionCoverageEnabled,
              branchCoverageEnabled);
        }
      });

      serviceClient.onIsolateEvent.listen((event) async {
        if (event.kind == EventKind.kIsolateExit) {
          // Realizar qualquer limpeza necessária após o término do isolate
          logger.info('Isolate ${event.isolate!.name} exited');
        }
      });

      serviceClient.onDebugEvent.listen((event) async {
        if (event.kind == EventKind.kPauseBreakpoint) {
          // O isolate foi pausado pelo debugger
          final isolateId = event.isolate!.id!;
          print("Isolate paused by debugger: $isolateId");
        }
      });
    },
  );
}
