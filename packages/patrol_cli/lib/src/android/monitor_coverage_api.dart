import 'dart:async';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

class TestMonitor {
  final VmService service;
  String isolateId;
  String scriptId;
  Map<int, Set<int>> previousCoverage = {};
  Timer? coverageTimer;
  bool isRunning = false;

  TestMonitor(this.service, this.isolateId, this.scriptId);

  Future<void> start() async {
    print('Starting TestMonitor for isolate $isolateId and script $scriptId');
    isRunning = true;
    await _setupStreams();
    coverageTimer = Timer.periodic(Duration(milliseconds: 100), (_) => checkCoverage());
    print('TestMonitor started');
  }

  Future<void> _setupStreams() async {
    await service.setVMTimelineFlags(['GC', 'Dart', 'Embedder']);
    await _safeStreamListen('GC');
    await _safeStreamListen('Timeline');
    await _safeStreamListen('Isolate');

    service.onIsolateEvent.listen((event) async {
      if (event.kind == EventKind.kIsolateExit && event.isolate?.id == isolateId) {
        print('Isolate exited. Attempting to reconnect...');
        await _reconnect();
      }
    });
  }

  Future<void> _safeStreamListen(String streamId) async {
    try {
      // Tenta cancelar a inscrição primeiro, ignorando erros
      await service.streamCancel(streamId).catchError((error) {
        print('Error cancelling stream $streamId: $error');
        return null; // Retorna null para satisfazer o tipo Future<Success?>
      });
      // Agora tenta se inscrever
      await service.streamListen(streamId);
    } catch (e) {
      print('Error while setting up stream $streamId: $e');
    }
  }

  Future<void> _reconnect() async {
    print('Attempting to reconnect...');
    await stop();
    
    final vm = await service.getVM();
    final isolates = vm.isolates;
    
    if (isolates == null || isolates.isEmpty) {
      print('No isolates found. Waiting to retry...');
      await Future.delayed(Duration(seconds: 1));
      return _reconnect();
    }

    final newIsolate = isolates.firstWhere(
      (iso) => iso.name == 'main',
      orElse: () => isolates.first,
    );

    isolateId = newIsolate.id!;
    final scripts = await service.getScripts(isolateId);
    final testScript = scripts.scripts!.firstWhere(
      (s) => s.uri!.contains('_test.dart'),
      orElse: () => throw Exception('No test script found'),
    );
    scriptId = testScript.id!;

    print('Reconnected to isolate $isolateId with script $scriptId');
    await start();
  }

  Future<void> checkCoverage() async {
    if (!isRunning) return;

    try {
      final coverage = await service.getSourceReport(
        isolateId,
        ['Coverage'],
        scriptId: scriptId,
      );

      print('Received coverage report with ${coverage.ranges!.length} ranges');

      for (final range in coverage.ranges!) {
        final scriptIndex = range.scriptIndex ?? 0;
        final script = coverage.scripts?[scriptIndex];
        
        if (script == null) {
          print('Warning: Null script for index $scriptIndex');
          continue;
        }

        final newCoverage = range.coverage?.hits?.toSet() ?? {};

        if (!previousCoverage.containsKey(scriptIndex)) {
          previousCoverage[scriptIndex] = {};
          print('Initialized coverage for script ${script.uri}');
        }

        final newLines = newCoverage.difference(previousCoverage[scriptIndex]!);
        if (newLines.isNotEmpty) {
          print('New lines covered in script ${script.uri}: $newLines');
          await handleNewCoverage(script, newLines);
        }

        previousCoverage[scriptIndex] = newCoverage;
      }
    } catch (e) {
      if (e.toString().contains('Collected')) {
        print('Isolate was collected. Attempting to reconnect...');
        await _reconnect();
      } else {
        print('Error checking coverage: $e');
      }
    }
  }

  Future<void> handleNewCoverage(ScriptRef script, Set<int> newLines) async {
    try {
      final fullScript = await service.getObject(isolateId, script.id!) as Script;
      final source = fullScript.source!;
      final lines = source.split('\n');

      print('Handling new coverage for script ${script.uri}');

      for (final line in newLines) {
        if (line < 1 || line > lines.length) {
          print('Warning: Line number $line is out of range');
          continue;
        }

        final lineContent = lines[line - 1].trim();
        if (lineContent.startsWith('patrol(') || lineContent.startsWith('testWidgets(')) {
          print('Test started at line $line: $lineContent');
          // Aqui você pode iniciar a coleta de cobertura para este teste específico
        } else if (lineContent.startsWith('}') && 
                   (lines[line - 2].trim().startsWith('patrol(') || lines[line - 2].trim().startsWith('testWidgets('))) {
          print('Test ended at line $line');
          // Aqui você pode parar a coleta de cobertura para este teste específico
        }
      }
    } catch (e) {
      print('Error handling new coverage: $e');
    }
  }

  Future<void> stop() async {
    isRunning = false;
    coverageTimer?.cancel();
    previousCoverage.clear();
    // Tenta cancelar todas as streams
    await Future.wait([
      service.streamCancel('GC').catchError((error) {
        print('Error cancelling GC stream: $error');
        return null; // Retorna null para satisfazer o tipo Future<Success?>
      }),
      service.streamCancel('Timeline').catchError((error) {
        print('Error cancelling Timeline stream: $error');
        return null; // Retorna null para satisfazer o tipo Future<Success?>
      }),
      service.streamCancel('Isolate').catchError((error) {
        print('Error cancelling Isolate stream: $error');
        return null; // Retorna null para satisfazer o tipo Future<Success?>
      }),
    ]);
    print('TestMonitor stopped');
  }
}


Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart script.dart <observatory-uri>');
    return;
  }

  final observatoryUriHttp = args[0];
  final observatoryUri = convertToWebSocketUrl(observatoryUriHttp);
  print('Connecting to Observatory at $observatoryUri');

  final service = await vmServiceConnectUri(observatoryUri);
  print('Connected to VM service');

  final vm = await service.getVM();
  print('Retrieved VM information');

  if (vm.isolates == null || vm.isolates!.isEmpty) {
    print('No isolates found');
    return;
  }

  final isolate = vm.isolates!.first;
  print('Using isolate: ${isolate.name} (${isolate.id})');

  final scripts = await service.getScripts(isolate.id!);
  print('Retrieved ${scripts.scripts?.length ?? 0} scripts');

  final testScript = scripts.scripts!.firstWhere(
    (s) => s.uri!.contains('_test.dart'),
    orElse: () {
      print('No test script found');
      return ScriptRef(id: 'test', uri: 'test.dart');
    },
  );

  if (testScript == null) {
    print('No test script found. Exiting.');
    return;
  }

  print('Found test script: ${testScript.uri}');

  final monitor = TestMonitor(service, isolate.id!, testScript.id!);
  await monitor.start();

  // Keep the script running
  await Future.delayed(Duration(days: 1));
}

String convertToWebSocketUrl(String observatoryUri) {
  observatoryUri = observatoryUri.replaceFirst('http://', 'ws://');
  if (!observatoryUri.endsWith('/ws')) {
    observatoryUri += 'ws';
  }
  return observatoryUri;
}
