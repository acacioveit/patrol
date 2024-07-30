import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:patrol_cli/src/base/logger.dart';
import 'package:process/process.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

class CoverageCollector {
  // Factory constructor to get the singleton instance
  factory CoverageCollector() {
    _instance ??= CoverageCollector._internal();
    return _instance!;
  }

  // Private constructor
  CoverageCollector._internal();

  static CoverageCollector? _instance;
  VmService? _service;
  final _logger = Logger();

  final String _coverageDir = 'coverage';
  final String _mergedLcovFile = 'coverage/lcov.info';
  final String _tempDir = 'coverage/temp';
  int _testCounter = 0;
  final ProcessManager _processManager = const LocalProcessManager();
  bool _isRunning = false;
  final _completer = Completer<void>();
  String? _currentObservatoryUrlWs;
  String? _currentObservatoryUrlHttp;

  Future<void> start(String currentObservatoryUrlHttp) async {
    _logger.info('Starting TestMonitor...');
    await _initializeCoverageDirectories();
    _currentObservatoryUrlHttp = currentObservatoryUrlHttp;
    _currentObservatoryUrlWs =
        _convertToWebSocketUrl(currentObservatoryUrlHttp);

    await _connectToVmService();
    _isRunning = true;

    _service?.onIsolateEvent.listen(_handleIsolateEvent);
    _service?.onDebugEvent.listen(_handleDebugEvent);

    await _service?.streamListen(EventStreams.kDebug);
    await _service?.streamListen(EventStreams.kIsolate);

    _logger.info('Listening for events...');

    final vm = await _service?.getVM();
    for (final isolateRef in vm?.isolates ?? []) {
      isolateRef as IsolateRef;
      await _setTestBreakpoints(isolateRef.id!);
    }

    await _completer.future;
  }

  Future<void> stop() async {
    if (!_isRunning) {
      _logger.warn('TestMonitor is not running.');
      return;
    }

    _logger.info('Stopping TestMonitor...');
    _isRunning = false;
    await _service?.dispose();
    _completer.complete();
    await _mergeFinalCoverage();
    _logger.info('TestMonitor stopped.');
  }

  Future<void> _initializeCoverageDirectories() async {
    await Directory(_coverageDir).create(recursive: true);
    await Directory(_tempDir).create(recursive: true);
  }

  Future<void> _connectToVmService() async {
    final wsUrl = _convertToWebSocketUrl(_currentObservatoryUrlWs!);
    _logger.info('Connecting to $wsUrl');

    try {
      _service = await vmServiceConnectUri(wsUrl);
      _logger.info('Connected to VM service');
    } catch (e) {
      _logger.err('Failed to connect to VM service: $e');
      _isRunning = false;
      _completer.complete();
      rethrow;
    }
  }

  Future<void> _handleIsolateEvent(Event event) async {
    if (!_isRunning) {
      return;
    }

    if (event.kind == EventKind.kIsolateRunnable) {
      _logger.info('New isolate detected. Setting breakpoints...');
      await _setTestBreakpoints(event.isolate!.id!);
    }
  }

  void _handleDebugEvent(Event event) {
    if (!_isRunning) {
      return;
    }

    if (event.kind == EventKind.kPauseBreakpoint) {
      _handleBreakpoint(event);
    }
  }

  Future<void> _setTestBreakpoints(String isolateId) async {
    if (_service == null) {
      _logger.warn('VM service is not available. Cannot set breakpoints.');
      return;
    }

    try {
      final scripts = await _service!.getScripts(isolateId);

      for (final scriptRef in scripts.scripts!) {
        if (scriptRef.uri!.contains('integration_test/') &&
            scriptRef.uri!.endsWith('_test.dart')) {
          _logger.info('Setting breakpoints in ${scriptRef.uri}');

          Script? script;
          try {
            script =
                await _service!.getObject(isolateId, scriptRef.id!) as Script?;
          } catch (e) {
            _logger.warn('Failed to get script object: $e');
            continue;
          }

          if (script == null) {
            _logger.warn('Script object is null for ${scriptRef.uri}');
            continue;
          }

          final lines = script.source!.split('\n');

          for (var i = 0; i < lines.length; i++) {
            if (lines[i].trim().startsWith('test(') ||
                lines[i].trim().startsWith('testWidgets(') ||
                lines[i].trim().startsWith('patrol(')) {
              final endLine = _findTestFunctionEnd(lines, i);
              _logger.info(
                  'Found test starting at line ${i + 1} and ending at line ${endLine + 1}');
              if (endLine != -1) {
                try {
                  final bp = await _service!.addBreakpointWithScriptUri(
                    isolateId,
                    scriptRef.uri!,
                    endLine,
                  );
                  _logger.info(
                      'Breakpoint added: ${bp.id} at line $endLine (end of test)');
                } catch (e) {
                  _logger.warn('Error adding breakpoint: $e');
                }
              } else {
                _logger.warn(
                    'Could not find end of test starting at line ${i + 1}');
              }
            }
          }
        }
      }
    } catch (e) {
      _logger.warn('Error setting breakpoints: $e');
    }
  }

  int _findTestFunctionEnd(List<String> lines, int startLine) {
    var bracketCount = 0;
    var foundOpeningBracket = false;
    for (var i = startLine; i < lines.length; i++) {
      if (!foundOpeningBracket && lines[i].contains('{')) {
        foundOpeningBracket = true;
      }
      if (foundOpeningBracket) {
        bracketCount += '{'.allMatches(lines[i]).length;
        bracketCount -= '}'.allMatches(lines[i]).length;
        if (bracketCount == 0) {
          return i; // Return the line with the closing bracket
        }
      }
    }
    return -1; // End not found
  }

  Future<void> _handleBreakpoint(Event event) async {
    if (!_isRunning || _service == null) {
      _logger
          .warn('TestMonitor is not running or VM service is not available.');
      return;
    }

    if (event.isolate?.id == null) {
      _logger.warn('Warning: Isolate ID is null');
      return;
    }
    final isolateId = event.isolate!.id!;

    _logger.info('Breakpoint hit in isolate: $isolateId');

    final breakpointId = event.breakpoint?.id ?? 'Unknown';
    _logger.info('Breakpoint ID: $breakpointId');

    try {
      if (event.topFrame?.location?.script == null) {
        _logger.warn('Warning: Script information is not available');
      } else {
        final scriptRef = event.topFrame!.location!.script!;
        final script =
            await _service!.getObject(isolateId, scriptRef.id!) as Script?;

        if (script != null) {
          final lineNumber = event.topFrame?.location?.line ?? 'Unknown';
          _logger.info('Paused at ${script.uri}:$lineNumber (end of test)');
        } else {
          _logger.warn('Warning: Unable to retrieve script information');
        }
      }

      _logger.info('Collecting coverage...');
      await _collectAndProcessCoverage(isolateId);
    } catch (e) {
      _logger.err('Error handling breakpoint: $e');
    }
  }

  Future<void> _collectAndProcessCoverage(String isolateId) async {
    _testCounter++;
    final tempJsonFile = path.join(_tempDir, 'coverage_$_testCounter.json');
    final tempLcovFile = path.join(_tempDir, 'lcov_$_testCounter.info');

    _logger.info('Collecting coverage for uri: $_currentObservatoryUrlHttp');
    try {
      // Collect coverage data
      final collectResult = await _processManager.run(
        <String>[
          'dart',
          'pub',
          'global',
          'run',
          'coverage:collect_coverage',
          '--uri=$_currentObservatoryUrlHttp',
          '-o',
          tempJsonFile,
          // '--wait-paused',
          '--resume-isolates',
          '--scope-output=infinitepay_dashboard_flutter',
          '--connect-timeout=10'
        ],
      );

      if (collectResult.exitCode != 0) {
        _logger.err('Failed to collect coverage: ${collectResult.stderr}');
        return;
      }

      _logger.info('Coverage collected successfully.');

      // Convert JSON to LCOV
      final formatResult = await _processManager.run(
        <String>[
          'dart',
          'pub',
          'global',
          'run',
          'coverage:format_coverage',
          '-i',
          tempJsonFile,
          '-o',
          tempLcovFile,
          '--lcov',
          '--report-on=lib',
        ],
      );

      _logger.info('Formatting coverage to LCOV...');

      if (formatResult.exitCode != 0) {
        _logger.err('Failed to format coverage: ${formatResult.stderr}');
        return;
      }

      _logger.info('Coverage formatted to LCOV successfully.');
    } catch (e) {
      _logger.err('Error during coverage collection and processing: $e');
    }
  }

  Future<void> _mergeLcovFiles(String newLcovFile) async {
    if (!File(_mergedLcovFile).existsSync()) {
      await File(newLcovFile).copy(_mergedLcovFile);
      _logger.info('Created initial merged LCOV file: $_mergedLcovFile');
      return;
    }

    try {
      final result = await _processManager.run(<String>[
        'lcov',
        '--add-tracefile',
        _mergedLcovFile,
        '--add-tracefile',
        newLcovFile,
        '--output-file',
        _mergedLcovFile,
      ]);

      if (result.exitCode != 0) {
        _logger.err('Failed to merge LCOV files: ${result.stderr}');
        return;
      }

      _logger.info('LCOV files merged successfully into $_mergedLcovFile');
    } catch (e) {
      _logger.err('Error merging LCOV files: $e');
    }
  }

  Future<void> _mergeFinalCoverage() async {
    final tempFiles = Directory(_tempDir)
        .listSync()
        .where((entity) => entity.path.endsWith('.info'))
        .map((entity) => entity.path)
        .toList();

    for (final file in tempFiles) {
      await _mergeLcovFiles(file);
    }

    _logger.info('Final coverage merge completed.');
  }

  String _convertToWebSocketUrl(String observatoryUri) {
    var observatoryUriWs = observatoryUri.replaceFirst('http://', 'ws://');
    if (!observatoryUriWs.endsWith('/ws')) {
      observatoryUriWs += 'ws';
    }
    return observatoryUriWs;
  }
}